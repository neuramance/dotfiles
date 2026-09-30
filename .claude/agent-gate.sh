#!/usr/bin/env bash
set -uo pipefail
input=$(cat)
command -v jq >/dev/null 2>&1 || { echo "agent-gate: jq is required to read hook events" >&2; exit 2; }
event=$(jq -r '.hook_event_name // empty' <<<"$input")
dir=$(jq -r '.cwd // empty' <<<"$input")
file=
if [[ $event == PostToolUse ]]; then
  file=$(jq -r '.tool_input.file_path // empty' <<<"$input")
  [[ -n $file ]] || exit 0
  dir=$(dirname "$file")
fi
root=$(git -C "${dir:-.}" rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0
[[ -x $root/scripts/agent-gate.sh ]] && grep -qF 'scripts/agent-gate.sh' "$root/.claude/settings.json" 2>/dev/null && exit 0
verify=$root/scripts/agent-verify
[[ -x $verify ]] || exit 0
bounded() {
  awk 'NR <= 90 { print; next } { last[NR % 10] = $0 }
    END {
      if (NR <= 90) exit
      if (NR > 100) print "agent-gate: " NR - 100 " lines omitted"
      for (i = (NR > 100 ? NR - 9 : 91); i <= NR; i++) print last[i % 10]
    }'
}
within() {
  perl -e '
    my $seconds = shift;
    my $pid = fork // die "agent-gate: fork failed: $!\n";
    if ($pid == 0) { setpgrp; exec @ARGV or die "agent-gate: cannot run $ARGV[0]: $!\n" }
    $SIG{ALRM} = sub {
      kill "TERM", -$pid;
      sleep 2;
      kill "KILL", -$pid;
      waitpid $pid, 0;
      print "FAIL [deadline] $ARGV[0] did not finish within $seconds s\n";
      exit 124;
    };
    alarm $seconds;
    waitpid $pid, 0;
    exit($? & 127 ? 128 + ($? & 127) : $? >> 8);
  ' "$@"
}
if [[ -n $file ]]; then
  if [[ $file == *.rs && -f $root/rustfmt.toml ]]; then
    formatted=$(mktemp)
    perl -e 'alarm 10; exec @ARGV' rustfmt --quiet --emit stdout <"$file" >"$formatted" 2>/dev/null && ! cmp -s "$formatted" "$file" && cat "$formatted" >"$file"
    rm -f "$formatted"
  fi
  if [[ ($file == *.py || $file == *.pyi) && -f $root/ruff.toml && -x $root/.venv/bin/ruff ]]; then
    ruff=$root/.venv/bin/ruff
    formatted=$(mktemp)
    perl -e 'alarm 10; exec @ARGV' "$ruff" check --config "$root/ruff.toml" --select I --fix-only --exit-zero --stdin-filename "$file" - <"$file" 2>/dev/null |
      perl -e 'alarm 10; exec @ARGV' "$ruff" format --config "$root/ruff.toml" --stdin-filename "$file" - >"$formatted" 2>/dev/null &&
      ! cmp -s "$formatted" "$file" && cat "$formatted" >"$file"
    rm -f "$formatted"
  fi
  out=$("$verify" "$file" 2>&1) && exit 0
  bounded <<<"$out" >&2
  exit 2
fi
if stat -c %s . >/dev/null 2>&1; then
  stat_format=(-c '%n %s %.9Y %.9Z %f %i')
else
  stat_format=(-f '%N %z %Fm %Fc %p %i')
fi
prune=(-path ./.git)
for cache in .cache .tmp .vite .vitest-cache; do prune+=(-o -path "./node_modules/$cache"); done
[[ -f Cargo.toml ]] && prune+=(-o -path ./target)
[[ -f pyproject.toml ]] && prune+=(-o -path ./.venv -o -path ./mutants -o -path ./.pytest_cache -o -path ./.ruff_cache -o -name __pycache__)
volatile='^(_|PWD|OLDPWD|SHLVL|COLUMNS|LINES|CLAUDE_EFFORT|CLAUDE_CODE_SESSION_ID|CLAUDE_PID|TRACEPARENT|TRACESTATE)='
fingerprint() {
  local path_dirs
  IFS=: read -r -a path_dirs <<<"$PATH"
  {
    date -u +%F
    git rev-parse HEAD --symbolic-full-name HEAD 2>&1
    git ls-files --stage -z | git hash-object --stdin
    git --no-optional-locks status --porcelain --ignored -z 2>&1 | git hash-object --stdin
    git for-each-ref
    git config --list
    env | LC_ALL=C sort | grep -vE "$volatile"
    git --version
    git hash-object --no-filters "${BASH_SOURCE[0]}"
    [[ ! -f package.json ]] || { node --version; bun --version; } 2>&1
    [[ ! -f Cargo.toml ]] || { rustc -vV; cargo -V; } 2>&1
    [[ ! -f pyproject.toml ]] || {
      uv --version
      .venv/bin/python --version
      find .venv -name '*.dist-info' -print 2>/dev/null | LC_ALL=C sort
      find .venv -name '*.pth' -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 -r cat
    } 2>&1
    find "${path_dirs[@]}" -maxdepth 1 \( -type f -o -type l \) -print0 2>/dev/null |
      xargs -0 -r stat "${stat_format[@]}" 2>/dev/null | LC_ALL=C sort
    find -L . \( "${prune[@]}" \) -prune -o -type d -print 2>/dev/null | LC_ALL=C sort
    find -L . \( "${prune[@]}" \) -prune -o -type l -print0 2>/dev/null |
      xargs -0 -r stat "${stat_format[@]}" 2>/dev/null | LC_ALL=C sort
    find -L . \( "${prune[@]}" \) -prune -o ! -type d ! -type l -print0 2>/dev/null |
      xargs -0 -r stat -L "${stat_format[@]}" | LC_ALL=C sort
  } | git hash-object --stdin
}
record=
[[ $(git config --type=bool --get agent-gate.skipUnchanged) == true ]] && record=$(git rev-parse --git-path agent-gate-green)
before=
[[ -z $record ]] || before=$(fingerprint) || before=
if [[ -n $before && -f $record && $(<"$record") == "$before" ]]; then
  jq -n '{systemMessage: "agent-gate: skipped the Stop gate; nothing changed since its last green run"}'
  exit 0
fi
deadline=$(git config --type=int --get agent-gate.stopDeadline) || deadline=280
if out=$(within "$deadline" "$verify" 2>&1); then
  [[ -n $before && $(fingerprint) == "$before" ]] && printf '%s\n' "$before" >"$record.$$" && mv -f "$record.$$" "$record"
  exit 0
fi
if [[ $(jq -r '.stop_hook_active // false' <<<"$input") == true ]]; then
  jq -n --arg detail "$(bounded <<<"$out")" '{
    continue: false,
    stopReason: "agent-verify still fails after a retry; the task is incomplete",
    systemMessage: ("agent-verify still fails after a retry; the task is incomplete\n" + $detail)
  }'
  exit 0
fi
bounded <<<"$out" >&2
exit 2
