#!/usr/bin/env bash
# Emit a single MEM line: <total>  ·  <DIMM summary>  ·  <usage>
# Uses ANSI escapes directly so fastfetch keeps the bold-red / dim-italic split.
set -euo pipefail

RED=$'\033[1;38;2;220;40;60m'
DIM=$'\033[0;3;38;2;130;130;130m'
RST=$'\033[0m'

read -r total used pct < <(
  free -h | awk 'NR==2 {gsub("i$","",$2); gsub("i$","",$3); printf "%s %s %d\n", $2, $3, ($3+0)*100/($2+0)}'
)

specs=$(dmidecode -t 17 2>/dev/null | awk '
  /^[[:space:]]+Size:/ && !/Unknown|No Module/  { size=$2$3; count++ }
  /^[[:space:]]+Type: DDR/                       { type=$2 }
  /Configured Memory Speed:/                     { speed=$4" "$5 }
  END {
    if (!type) exit
    if (count > 1) printf "%d× %s %s @ %s", count, size, type, speed
    else           printf "%s %s @ %s", size, type, speed
  }
' 2>/dev/null || true)

if [[ -n "$specs" ]]; then
  printf "%s%s%s  ·  %s  ·  %s used (%d%%)%s\n" "$RED" "$total" "$DIM" "$specs" "$used" "$pct" "$RST"
else
  printf "%s%s%s  ·  %s used (%d%%)%s\n" "$RED" "$total" "$DIM" "$used" "$pct" "$RST"
fi
