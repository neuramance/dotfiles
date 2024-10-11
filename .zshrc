# zsh prompt: user@host:~$ 
PROMPT="%F{blue}%n%F{white}@%F{magenta}%m%F{white}:%F{green}%~%F{white}$ "

# environment vars
export EDITOR=vim
export LS_COLORS="di=36:fi=0:ln=93:ex=32"

# shell
alias c="clear"
alias cd..="cd .."
alias zconf="cursor ~/.zshrc"
alias ls="eza -bhlF --no-user --no-permissions --no-time --group-directories-first"
alias sl="eza -bhlF --no-user --no-permissions --no-time --group-directories-first"
alias lsa="eza -abhlF --no-user --no-permissions --no-time --group-directories-first"
alias cat="bat"

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
alias brewup="brew update && brew upgrade"

# AWS
alias cdks="cdk synth"
alias cdkd="cdk deploy"
alias cdkls="cdk ls"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
alias brd="bun run dev"
alias brdo="bun run dev -- --open"
alias brb="bun run build"

# speedtest
alias speed="speedtest-cli --bytes --simple"

# dependent aliases (MUST BE AT BOTTOM)
alias echopath="echo $PATH | tr ':' '\n'"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# cursor (personal only)
[[ $(hostname) == "m4c" ]] && {
    function cursor {
        open -a "/Applications/Cursor.app" "$@"
    }
}

# zshrc remote machine copying
copy_zshrc() {
  scp ~/.zshrc "$1":~/.zshrc
}