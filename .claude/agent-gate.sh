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
if [[ -n $file ]]; then
  if [[ $file == *.rs && -f $root/rustfmt.toml ]]; then
    formatted=$(mktemp)
    perl -e 'alarm 10; exec @ARGV' rustfmt --quiet --emit stdout <"$file" >"$formatted" 2>/dev/null && ! cmp -s "$formatted" "$file" && cat "$formatted" >"$file"
    rm -f "$formatted"
  fi
  out=$("$verify" "$file" 2>&1) && exit 0
  bounded <<<"$out" >&2
  exit 2
fi
out=$("$verify" 2>&1) && exit 0
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
