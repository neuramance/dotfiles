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
fi
launch=${dir:-$PWD}
settings=.codex/hooks.json
if [[ -z $(jq -r '.turn_id // empty' <<<"$input") ]]; then
  launch=${CLAUDE_PROJECT_DIR:-$launch}
  settings=.claude/settings.json
fi
delegated() {
  [[ -x $1/scripts/agent-gate.sh ]] && grep -qF 'scripts/agent-gate.sh' "$1/$settings" 2>/dev/null &&
    [[ $1 == "$(git -C "$launch" rev-parse --show-toplevel 2>/dev/null)" ]]
}
session=$(jq -r '.session_id // empty' <<<"$input")
session_record=
[[ $session =~ ^[A-Za-z0-9_-]+$ ]] && session_record=${TMPDIR:-/tmp}/agent-gate/$session
log=
trap 'rm -f "$log"' EXIT
new_log() {
  rm -f "$log"
  log=$(mktemp "${TMPDIR:-/tmp}/agent-gate.XXXXXX")
}
bounded() {
  awk 'NR <= 90 { print; next } { last[NR % 10] = $0 }
    END {
      if (NR <= 90) exit
      if (NR > 100) print "agent-gate: " NR - 100 " lines omitted"
      for (i = (NR > 100 ? NR - 9 : 91); i <= NR; i++) print last[i % 10]
    }'
}
diagnostics() {
  local out
  out=$(<"$log")
  [[ $out == *[![:space:]]* ]] || out='FAIL [agent-verify] exited non-zero without output'
  bounded <<<"$out"
}
within() {
  perl -e '
    my $seconds = shift;
    my $pid = fork // die "agent-gate: fork failed: $!\n";
    if ($pid == 0) { setpgrp; exec { $ARGV[0] } @ARGV or die "agent-gate: cannot run $ARGV[0]: $!\n" }
    $SIG{ALRM} = sub {
      kill "TERM", -$pid;
      sleep 2;
      kill "KILL", -$pid;
      waitpid $pid, 0;
      print "FAIL [deadline] $ARGV[0] did not finish within $seconds s\n";
      exit 124;
    };
    $SIG{$_} = sub { kill "KILL", -$pid; exit 143 } for qw(TERM INT HUP);
    alarm $seconds;
    waitpid $pid, 0;
    exit($? & 127 ? 128 + ($? & 127) : $? >> 8);
  ' "$@"
}
if [[ -n $file ]]; then
  root=$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null) || exit 0
  cd "$root" || exit 0
  delegated "$root" && exit 0
  verify=$root/scripts/agent-verify
  [[ -x $verify ]] || exit 0
  if [[ -n $session_record ]]; then
    git_dirs=$(git rev-parse --git-dir --git-common-dir 2>/dev/null)
    record_dir=${session_record%/*}
    if [[ $root == *$'\n'* ]] ||
      { [[ ${git_dirs%$'\n'*} == "${git_dirs#*$'\n'}" ]] &&
        ! { { mkdir -m 700 "$record_dir" 2>/dev/null || [[ -d $record_dir ]]; } &&
          [[ -O $record_dir && ! -L $record_dir ]] &&
          printf '%s\n' "$root" >>"$session_record"; }; }; then
      echo "agent-gate: cannot record $root in $session_record, so the Stop gate would not verify it" >&2
      exit 2
    fi
  fi
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
  new_log || { echo "agent-gate: cannot create a log file" >&2; exit 2; }
  within $((SECONDS < 24 ? 25 - SECONDS : 1)) "$verify" "$file" >"$log" 2>&1 && exit 0
  diagnostics >&2
  exit 2
fi
if stat -c %s / >/dev/null 2>&1; then
  stat_format=(-c '%n %s %.9Y %.9Z %f %i')
else
  stat_format=(-f '%N %z %Fm %Fc %p %i')
fi
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
cwd_root=$(git -C "${dir:-.}" rev-parse --show-toplevel 2>/dev/null)
budget=280
failures=
if [[ $cwd_root == *$'\n'* ]]; then
  [[ -x $cwd_root/scripts/agent-verify ]] && failures+="agent-gate: cannot gate a repository whose path contains a newline: $cwd_root"$'\n'
  cwd_root=
fi
[[ -z $cwd_root ]] || budget=$(git -C "$cwd_root" config --type=int --get agent-gate.stopDeadline 2>/dev/null) || budget=280
stop_end=$((SECONDS + budget + 1))
roots=$cwd_root
if [[ -n $session_record && -e $session_record ]]; then
  if [[ -O ${session_record%/*} && ! -L ${session_record%/*} ]] && recorded=$(<"$session_record"); then
    roots+=$'\n'$recorded
  else
    failures+="agent-gate: cannot read $session_record, so the Stop gate cannot verify the repositories this session edited"$'\n'
  fi
fi
seen=$'\n'
gated=0
skipped=
while IFS= read -r root <&3; do
  [[ -n $root && $seen != *$'\n'"$root"$'\n'* ]] || continue
  seen+=$root$'\n'
  verify=$root/scripts/agent-verify
  if [[ ! -x $verify || $(git -C "$root" rev-parse --show-toplevel 2>/dev/null) != "$root" ]] || delegated "$root" || ! cd "$root"; then
    continue
  fi
  gated=$((gated + 1))
  prune=(-path ./.git)
  for cache in .cache .tmp .vite .vitest-cache; do prune+=(-o -path "./node_modules/$cache"); done
  [[ -f Cargo.toml ]] && prune+=(-o -path ./target)
  [[ -f pyproject.toml ]] && prune+=(-o -path ./.venv -o -path ./mutants -o -path ./.pytest_cache -o -path ./.ruff_cache -o -name __pycache__)
  record=
  [[ $(git config --type=bool --get agent-gate.skipUnchanged) == true ]] && record=$(git rev-parse --git-path agent-gate-green)
  before=
  [[ -z $record ]] || ((stop_end <= SECONDS)) || before=$(fingerprint) || before=
  if [[ -n $before && -f $record && $(<"$record") == "$before" ]]; then
    skipped+=$'\n'"agent-gate: $root"
    continue
  fi
  if ! new_log; then
    failures+="agent-gate: $root"$'\n'"agent-gate: cannot create a log file"$'\n'
    continue
  fi
  deadline=$(git config --type=int --get agent-gate.stopDeadline) || deadline=280
  ((deadline <= stop_end - SECONDS)) || deadline=$((stop_end - SECONDS))
  if ((deadline <= 0)); then
    echo "FAIL [deadline] agent-gate: no time left to verify $root" >"$log"
  elif within "$deadline" "$verify" >"$log" 2>&1; then
    [[ -n $before && $(fingerprint) == "$before" ]] && printf '%s\n' "$before" >"$record.$$" && mv -f "$record.$$" "$record"
    continue
  fi
  failures+="agent-gate: $root"$'\n'$(diagnostics)$'\n'
done 3<<<"$roots"
failures=${failures%$'\n'}
if [[ -n $failures && $(jq -r '.stop_hook_active // false' <<<"$input") == true ]]; then
  jq -n --arg detail "$failures" '{
    continue: false,
    stopReason: "agent-verify still fails after a retry; the task is incomplete",
    systemMessage: ("agent-verify still fails after a retry; the task is incomplete\n" + $detail)
  }'
  exit 0
fi
if [[ -n $failures ]]; then
  printf '%s\n' "$failures" >&2
  exit 2
fi
[[ -n $skipped ]] || exit 0
message="agent-gate: skipped the Stop gate; nothing changed since its last green run"
((gated == 1)) || message+=$skipped
jq -n --arg message "$message" '{systemMessage: $message}'
