# zsh prompt: user@host:~$  (root → red user, i9 → red host)
setopt PROMPT_SUBST
PROMPT='%(!.%F{red}.%F{blue})%n%f@%F{${${${${HOST%%.*}:#i9}:+magenta}:-red}}%m%f:%F{green}%~%f$ '

# environment vars
export EDITOR=vim
export LS_COLORS="di=36:fi=0:ln=93:ex=32"
export PAGER="less"
export LESS="-FRX"
export LESSHISTFILE="$HOME/.cache/less-history"
export IPYTHONDIR="$HOME/.config/ipython"
export BAT_THEME="ansi"

# python
export PATH="`python3 -m site --user-base`/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# uv Python package manager
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# aliases (sourced last so PATH is fully set for echopath)
[ -f "$HOME/.zsh_aliases" ] && source "$HOME/.zsh_aliases"

# secrets (untracked)
[ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"

# completions (compinit must precede any completion source)
autoload -Uz compinit && compinit -C -d "$HOME/.cache/zcompdump"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

sb() { [ -d ~/code/sb/"$1" ] || gh repo clone "superbuilders/$1" ~/code/sb/"$1" -- --filter=blob:none; cd ~/code/sb/"$1"; }

# herdr 0.8.0 leaks kitty keyboard flags on detach, leaving keys as CSI u escapes
herdr() {
  command herdr "$@"
  local s=$?
  printf '\033[<u\033[=0;1u\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?2004l\033[?1049l\033[?25h' >/dev/tty 2>/dev/null
  return $s
}

# fzf
command -v fzf >/dev/null && source <(fzf --zsh)

# zoxide
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"


# Added by Antigravity CLI installer
export PATH="/Users/w/.local/bin:$PATH"
