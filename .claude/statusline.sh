#!/usr/bin/env bash
input=$(cat)

# Extract fields from JSON input via grep (no jq dependency)
cwd=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | head -1 | sed 's/"current_dir":"//;s/"$//')
[ -z "$cwd" ] && cwd=$(echo "$input" | grep -o '"workspace":"[^"]*"' | head -1 | sed 's/"workspace":"//;s/"$//')
cwd="${cwd:-$PWD}"
model=$(echo "$input" | grep -o '"display_name":"[^"]*"' | head -1 | sed 's/"display_name":"//;s/"$//')
[ -z "$model" ] && model=$(echo "$input" | grep -o '"model":"[^"]*"' | head -1 | sed 's/"model":"//;s/"$//')
used_pct=$(echo "$input" | grep -o '"used_percentage":[0-9.]*' | head -1 | sed 's/"used_percentage"://')

# Shorten cwd
home=$(echo ~)
short_cwd=$(echo "$cwd" | sed "s|^$home|~|")

# Git branch
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

# Context window % color: green <70, yellow 70-89, red 90+
ctx_color=""
if [ -n "$used_pct" ]; then
  pct_int=${used_pct%.*}
  if [ "$pct_int" -ge 90 ] 2>/dev/null; then
    ctx_color="\033[38;2;244;63;94m"
  elif [ "$pct_int" -ge 70 ] 2>/dev/null; then
    ctx_color="\033[38;2;245;158;11m"
  else
    ctx_color="\033[38;2;0;196;92m"
  fi
fi

# Build output
out=""
user=$(whoami)
host=$(hostname -s)
user_color="\033[38;2;37;99;235m"; [ "$user" = "root" ] && user_color="\033[38;2;244;63;94m"
host_color="\033[38;2;217;70;239m"; [ "$host" = "i9" ] && host_color="\033[38;2;244;63;94m"
out+="${user_color}${user}\033[0m"
out+="\033[38;2;148;163;184m@\033[0m"
out+="${host_color}${host}\033[0m"
out+=":\033[38;2;0;196;92m${short_cwd}\033[0m"

if [ -n "$branch" ]; then
  out+=" \033[38;2;139;92;246m(${branch})\033[0m"
fi

if [ -n "$used_pct" ]; then
  out+=" ${ctx_color}${pct_int}%\033[0m"
fi

short_model=$(echo "$model" | sed -E 's/^Claude (Sonnet|Opus|Haiku) ([0-9.]+).*/\1\2/; s/^Sonnet/So/; s/^Opus/Op/; s/^Haiku/Ha/; s/^([A-Z][a-z])[a-z]* ([0-9.]+).*/\1\2/')
[[ "$model" == *"1M"* ]] && short_model="${short_model}-1M"
out+=" \033[38;2;0;0;0m${short_model}\033[0m"

printf '%b' "$out"
