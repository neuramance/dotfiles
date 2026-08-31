#!/usr/bin/env bash
set -uo pipefail
input=$(cat)
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ -x $root/scripts/agent-gate.sh ]] && exit 0
verify=$root/scripts/agent-verify
[[ -x $verify ]] || exit 0
event=$(jq -r '.hook_event_name // empty' <<<"$input")
if [[ $event == PostToolUse ]]; then
  file=$(jq -r '.tool_input.file_path // empty' <<<"$input")
  [[ -n $file ]] || exit 0
  out=$("$verify" "$file" 2>&1) && exit 0
  printf '%s\n' "$out" | tail -n 20 >&2
  exit 2
fi
[[ $(jq -r '.stop_hook_active // false' <<<"$input") == true ]] && exit 0
[[ -n $(git -C "$root" status --porcelain) ]] || exit 0
out=$("$verify" 2>&1) && exit 0
printf '%s\n' "$out" | tail -n 30 >&2
exit 2
