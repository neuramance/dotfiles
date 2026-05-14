# zsh prompt: user@host:~$  (root → red user, i9 → red host)
setopt PROMPT_SUBST
PROMPT='%(!.%F{red}.%F{blue})%n%f@%F{${${${${HOST%%.*}:#i9}:+magenta}:-red}}%m%f:%F{green}%~%f$ '

# environment vars
export EDITOR=vim
export LS_COLORS="di=36:fi=0:ln=93:ex=32"
export PAGER="less"
export LESS="-FRX"
export TMUX_GTA=20000
export BROWSER=wslview
export BAT_THEME="ansi"

# python
export PATH="`python3 -m site --user-base`/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# uv Python package manager
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# aliases (sourced last so PATH is fully set for echopath)
[ -f "$HOME/.zsh_aliases" ] && source "$HOME/.zsh_aliases"

# secrets (untracked)
[ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"

# fastfetch on every new interactive shell
# Clear first so the iTerm inline-image logo lines up with the text modules.
if [[ -o interactive ]] && command -v fastfetch >/dev/null; then
  # Point logo.png at the per-host image (logo.<short-hostname>.png) if present.
  _ff_dir="$HOME/.config/fastfetch"
  _ff_host_logo="$_ff_dir/logo.$(hostname -s).png"
  [[ -f "$_ff_host_logo" ]] && ln -sfn "${_ff_host_logo##*/}" "$_ff_dir/logo.png"
  unset _ff_dir _ff_host_logo
  clear
  fastfetch
fi
