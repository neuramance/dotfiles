#!/usr/bin/env bash
IFS=$'\x1f' read -r cwd model pct worktree < <(jq -r '[
  .workspace.current_dir // .cwd // "",
  .model.display_name // .model.id // "",
  (.context_window.used_percentage | if . == null then "" else floor | tostring end),
  .workspace.git_worktree // ""
] | join("\u001f")')
cwd=${cwd:-$PWD}

reset=$'\e[0m'
bold=$'\e[1m'
text=$'\e[38;2;226;232;240m'
muted=$'\e[38;2;148;163;184m'
red=$'\e[38;2;248;113;113m'
yellow=$'\e[38;2;250;204;21m'
green=$'\e[38;2;74;222;128m'
violet=$'\e[38;2;167;139;250m'
teal=$'\e[38;2;45;212;191m'

compact() {
  local slashes=${1//[^\/]/}
  if [ ${#slashes} -lt 3 ]; then printf '%s' "$1"; return; fi
  local rest=${1%/*}
  printf '…/%s/%s' "${rest##*/}" "${1##*/}"
}

host=${HOSTNAME%%.*}
host_color=$muted
[ "$host" = i9 ] && host_color=$red
user_color=$'\e[38;2;56;189;248m'
[ "$EUID" -eq 0 ] && user_color=$red
out="${user_color}${USER:-$(id -un)}${muted}@${bold}${host_color}${host}${reset} "

export GIT_OPTIONAL_LOCKS=0
if info=$(git -C "$cwd" rev-parse --path-format=absolute --show-prefix --git-common-dir 2>/dev/null); then
  prefix=${info%%$'\n'*}
  common=${info#*$'\n'}
  repo=${common%/.git}
  repo=${repo##*/}
  repo=${repo%.git}
  [ "$common" = "$HOME/.git" ] && repo="~"
  out+="${bold}${text}${repo}${reset}"
  [ -n "$prefix" ] && out+="${muted}/$(compact "${prefix%/}")${reset}"

  branch=$(git -C "$cwd" symbolic-ref --short -q HEAD || git -C "$cwd" rev-parse --short -q HEAD)
  glyph=⎇
  branch_color=$violet
  if [ -n "$worktree" ]; then
    glyph=⧉
    branch_color=$teal
    [ "$branch" = "worktree-$worktree" ] && branch=$worktree
  fi
  [ ${#branch} -gt 28 ] && branch="${branch:0:27}…"
  [ -n "$branch" ] && out+=" ${branch_color}${glyph} ${branch}${reset}"
else
  case $cwd in
    "$HOME" | "$HOME"/*) loc="~${cwd#"$HOME"}" ;;
    *) loc=$cwd ;;
  esac
  out+="${bold}${text}$(compact "$loc")${reset}"
fi

name=${model#Claude }
family=${name%% *}
version=${name#* }
short=$name
[ "$family" != "$name" ] && short="${family:0:2}${version%% *}"
case $family in
  Opus) model_color=$'\e[38;2;251;191;36m' ;;
  Sonnet) model_color=$'\e[38;2;96;165;250m' ;;
  Haiku) model_color=$'\e[38;2;52;211;153m' ;;
  Fable) model_color=$'\e[38;2;244;114;182m' ;;
  *) model_color=$text ;;
esac
out+="  ${model_color}${short}${reset}"
case $model in *1M*) out+="${muted}·1M${reset}" ;; esac

if [ -n "$pct" ]; then
  level=$green
  [ "$pct" -ge 70 ] && level=$yellow
  [ "$pct" -ge 90 ] && level=$red
  out+=" ${level}${pct}%${reset}"
fi

printf '%s' "$out"
