# zsh prompt: user@host:~$ 
PROMPT="%F{blue}%n%F{white}@%F{magenta}%m%F{white}:%F{green}%~%F{white}$ "

# environment vars
export EDITOR=vim
export LS_COLORS="di=36:fi=0:ln=93:ex=32"

# zsh autocompletion
autoload -Uz compinit && compinit

# shell
alias c="clear"
alias cd..="cd .."
alias zconf="code ~/.zshrc"
alias ls="eza -bhlF --no-user --no-permissions --no-time --group-directories-first"
alias sl="eza -bhlF --no-user --no-permissions --no-time --group-directories-first"
alias lsa="eza -abhlF --no-user --no-permissions --no-time --group-directories-first"
alias cat="batcat"

# git
alias gits="git status"
alias gita="git add ."
alias gitd="git diff"
alias gitc="git commit"
alias gitp="git push"
alias glg="git log --graph --oneline --all"

# rust
. "$HOME/.cargo/env"
alias car="cargo run"
alias care="cargo run --example"
alias cac="cargo clean"
alias cc="cargo check"
alias cab="cargo build"
alias cabr="cargo build --release"
alias carr="cargo run --release"
alias cabr="cargo build --release && cargo run --release"
alias caf="cargo fmt"

# python
alias py="python3"
alias python="python3"
alias pip="pip3"
alias pr="poetry run"
export PATH="`python3 -m site --user-base`/bin:$PATH"

# homebrew
alias brewb="brew bundle -f dump"

# AWS
alias cdks="cdk synth"
alias cdkd="cdk deploy"
alias cdkls="cdk ls"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
alias brd="bun run dev -- --open"

# bun completions
[ -s "/Users/wires/.bun/_bun" ] && source "/Users/wires/.bun/_bun"

# dependent aliases (MUST BE AT BOTTOM)
alias echopath="echo $PATH | tr ':' '\n'"