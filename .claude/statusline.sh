#!/usr/bin/env bash
input=$(cat)

# Extract fields from JSON input via grep (no jq dependency)
cwd=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | head -1 | sed 's/"current_dir":"//;s/"$//')
model=$(echo "$input" | grep -o '"display_name":"[^"]*"' | head -1 | sed 's/"display_name":"//;s/"$//')
used_pct=$(echo "$input" | grep -o '"used_percentage":[0-9.]*' | head -1 | sed 's/"used_percentage"://')
transcript=$(echo "$input" | grep -o '"transcript_path":"[^"]*"' | head -1 | sed 's/"transcript_path":"//;s/"$//')

# Total context tokens from latest assistant usage block in transcript
total_tokens=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  last_usage=$(grep -o '"usage":{[^}]*}' "$transcript" | tail -1)
  if [ -n "$last_usage" ]; then
    in_t=$(echo "$last_usage" | grep -o '"input_tokens":[0-9]*' | sed 's/.*://')
    cc_t=$(echo "$last_usage" | grep -o '"cache_creation_input_tokens":[0-9]*' | sed 's/.*://')
    cr_t=$(echo "$last_usage" | grep -o '"cache_read_input_tokens":[0-9]*' | sed 's/.*://')
    total_tokens=$(( ${in_t:-0} + ${cc_t:-0} + ${cr_t:-0} ))
  fi
fi

# Format token count as human-readable (e.g. 125k, 1.2M)
fmt_tokens=""
if [ -n "$total_tokens" ] && [ "$total_tokens" -gt 0 ]; then
  if [ "$total_tokens" -ge 1000000 ]; then
    fmt_tokens=$(awk -v n="$total_tokens" 'BEGIN{printf "%.1fM", n/1000000}')
  elif [ "$total_tokens" -ge 1000 ]; then
    fmt_tokens=$(awk -v n="$total_tokens" 'BEGIN{printf "%dk", n/1000}')
  else
    fmt_tokens="$total_tokens"
  fi
fi

# Shorten cwd
home=$(echo ~)
short_cwd=$(echo "$cwd" | sed "s|^$home|~|")

# Git stats (today's commits)
cd "$cwd" 2>/dev/null
today_start="$(date +%Y-%m-%d) 00:00:00"
today_end="$(date +%Y-%m-%d) 23:59:59"
added=$(git log --since="$today_start" --until="$today_end" --pretty=format: --numstat 2>/dev/null | awk '{added+=$1} END {printf "%d", added+0}')
removed=$(git log --since="$today_start" --until="$today_end" --pretty=format: --numstat 2>/dev/null | awk '{removed+=$2} END {printf "%d", removed+0}')
commits=$(git log --since="$today_start" --until="$today_end" --oneline 2>/dev/null | wc -l | tr -d ' ')

# Git branch
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# Context window % color: green <70, yellow 70-89, red 90+
ctx_color=""
if [ -n "$used_pct" ]; then
  pct_int=${used_pct%.*}
  if [ "$pct_int" -ge 90 ] 2>/dev/null; then
    ctx_color="\033[31m"  # red
  elif [ "$pct_int" -ge 70 ] 2>/dev/null; then
    ctx_color="\033[33m"  # yellow
  else
    ctx_color="\033[32m"  # green
  fi
fi

# Build output
out=""
out+="\033[34m$(whoami)\033[0m"
out+="@\033[35m$(hostname -s)\033[0m"
out+=":\033[32m${short_cwd}\033[0m"

if [ -n "$branch" ]; then
  out+=" \033[36m(${branch})\033[0m"
fi

out+=" \033[34m+${added}\033[0m/\033[33m-${removed}\033[0m"
out+=" \033[32m${commits}c\033[0m"

out+=" \033[2m${model}\033[0m"

if [ -n "$fmt_tokens" ]; then
  out+=" \033[38;5;141m${fmt_tokens}\033[0m"
fi

if [ -n "$used_pct" ]; then
  out+=" ${ctx_color}${pct_int}%\033[0m"
fi

printf '%b' "$out"
