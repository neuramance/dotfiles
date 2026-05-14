#!/usr/bin/env bash
# Emit a single MEM line: <total>  ·  <DIMM/type summary>  ·  <usage>
# Uses ANSI escapes directly so fastfetch keeps the bold-red / dim-italic split.
set -euo pipefail

RED=$'\033[1;38;2;220;40;60m'
DIM=$'\033[0;3;38;2;130;130;130m'
RST=$'\033[0m'

if [[ "$(uname)" == "Darwin" ]]; then
  total_b=$(sysctl -n hw.memsize)
  page_size=$(sysctl -n hw.pagesize)
  used_pages=$(vm_stat | awk '
    /Pages active/                 {gsub("\\.","",$3); a=$3}
    /Pages wired down/             {gsub("\\.","",$4); w=$4}
    /Pages occupied by compressor/ {gsub("\\.","",$5); c=$5}
    END {print a+w+c}
  ')
  used_b=$(( used_pages * page_size ))
  pct=$(( used_b * 100 / total_b ))
  total=$(awk -v b="$total_b" 'BEGIN {printf "%.0fGi", b/1024/1024/1024}')
  used=$(awk  -v b="$used_b"  'BEGIN {
    if (b >= 1073741824) printf "%.1fGi", b/1024/1024/1024
    else                 printf "%.0fMi", b/1024/1024
  }')
  type=$(system_profiler SPMemoryDataType 2>/dev/null | awk -F': +' '/^ +Type:/ {print $2; exit}')
  specs="${type:-Unified} (on-package)"
else
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
fi

if [[ -n "$specs" ]]; then
  printf "%s%s%s  ·  %s  ·  %s used (%d%%)%s\n" "$RED" "$total" "$DIM" "$specs" "$used" "$pct" "$RST"
else
  printf "%s%s%s  ·  %s used (%d%%)%s\n" "$RED" "$total" "$DIM" "$used" "$pct" "$RST"
fi
