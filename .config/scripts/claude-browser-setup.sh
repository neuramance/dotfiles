#!/bin/bash
set -euo pipefail

if ! command -v claude &>/dev/null; then
  echo "Claude Code is not installed: run $0 again after installing it." >&2
  exit 0
fi

within_a_minute=(perl -e 'alarm 60; exec @ARGV')
"${within_a_minute[@]}" claude mcp remove --scope user chrome-devtools &>/dev/null || true
"${within_a_minute[@]}" claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@1.13.0 --headless --isolated --viewport 1280x800 --redact-network-headers --no-usage-statistics --no-performance-crux
