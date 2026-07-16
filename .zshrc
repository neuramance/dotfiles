# zsh prompt: user@host:~$  (root → red user, i9 → red host)
setopt PROMPT_SUBST
PROMPT='%(!.%F{red}.%F{blue})%n%f@%F{${${${${HOST%%.*}:#i9}:+magenta}:-red}}%m%f:%F{green}%~%f$ '

# environment vars
export EDITOR=vim
export LS_COLORS="di=36:fi=0:ln=93:ex=32"
export PAGER="less"
export LESS="-FRX"
export BAT_THEME="ansi"

# python
export PATH="`python3 -m site --user-base`/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# uv Python package manager
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# aliases (sourced last so PATH is fully set for echopath)
[ -f "$HOME/.zsh_aliases" ] && source "$HOME/.zsh_aliases"

# secrets (untracked)
[ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<

sb() { [ -d ~/code/sb/"$1" ] || gh repo clone "superbuilders/$1" ~/code/sb/"$1" -- --filter=blob:none; cd ~/code/sb/"$1"; }
