#!/usr/bin/env bash
set -euo pipefail

[[ -z $(jq -r '.agent_id // empty') ]] || exit 0
[[ $PWD == */.claude/worktrees/* ]] || exit 0

main=${PWD%%/.claude/worktrees/*}
rest=${PWD#"$main"/.claude/worktrees/}
name=${rest%%/*}
root=$main/.claude/worktrees/$name
unit=dev-server-${main##*/}-$name

jq -e '.scripts.dev and ((.packageManager // "") | startswith("pnpm"))' "$root/package.json" >/dev/null 2>&1 || exit 0

if systemctl --user is-active --quiet "$unit"; then
  url=$(systemctl --user show --property=Description --value "$unit")
else
  owner=$PPID
  while ((owner > 1)) && [[ $(</proc/"$owner"/comm) != claude ]]; do
    owner=$(($(ps -o ppid= -p "$owner")))
  done
  if ((owner <= 1)); then
    echo "Dev server not started: this hook has no claude ancestor process to bind its lifetime to."
    exit 0
  fi

  listening=$(ss -Htln | awk '{sub(/.*:/, "", $4); print $4}')
  offset=$(($(cksum <<<"$unit" | cut -d' ' -f1) % 100))
  port=
  for step in {0..99}; do
    candidate=$((3000 + (offset + step) % 100))
    if ! grep -qx "$candidate" <<<"$listening"; then
      port=$candidate
      break
    fi
  done
  if [[ -z $port ]]; then
    echo "Dev server not started: every port from 3000 to 3099 is in use."
    exit 0
  fi

  url=http://$name.localhost:$port
  systemctl --user stop "$unit" 2>/dev/null || true
  systemd-run --user --quiet --collect --unit="$unit" --description="$url" \
    --working-directory="$root" --setenv=PATH="$PATH" \
    bash -c '{ pnpm install --frozen-lockfile && pnpm dev -p "$1" -H 127.0.0.1; } & tail --pid="$2" -f /dev/null & wait -n' \
    "$unit" "$port" "$owner"
fi

echo "This worktree's dev server is $url, shown in the status line: systemd user unit $unit, which runs \`pnpm install --frozen-lockfile\` and then \`pnpm dev\` on loopback and stops when this Claude process exits. Never run either yourself or start another server. It may still be installing or compiling: before using it, wait until \`curl -sf -m 5 -o /dev/null $url\` succeeds. Its log is \`journalctl --user -u $unit\`."
