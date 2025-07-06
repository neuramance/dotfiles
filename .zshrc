# zsh prompt: user@host:~$ 
PROMPT="%F{blue}%n%F{white}@%F{magenta}%m%F{white}:%F{green}%~%F{white}$ "

# environment vars
export EDITOR=vim
export LS_COLORS="di=36:fi=0:ln=93:ex=32"

# shell
alias c="clear"
alias cd..="cd .."
alias zconf="code ~/.zshrc"
alias ls="eza -bhlF --no-user --no-permissions --no-time --group-directories-first"
alias sl="eza -bhlF --no-user --no-permissions --no-time --group-directories-first"
alias lsa="eza -abhlF --no-user --no-permissions --no-time --group-directories-first"
alias cat="bat"
alias atop="sudo asitop --color 7"

# git
alias gits="git status"
alias gita="git add ."
alias gitd="git diff"
alias gitc="git commit"
alias gitp="git push"
alias glg="git log --graph --oneline --all"

# rust
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

# apt
alias aptup="sudo apt update && sudo apt upgrade"

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

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# personal only
[[ $(hostname) == "m4c" ]] && {

    # cursor
    function cursor {
        open -a "/Applications/Cursor.app" "$@"
    }

    # pyenv
    export PYENV_ROOT="$HOME/.pyenv"
    [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"

    # rust
    . "$HOME/.cargo/env"
}

# zshrc remote machine copying
copy_zshrc() {
  scp ~/.zshrc "$1":~/.zshrc
  scp ~/.zshrc "$1":/var/lib/postgresql/.zshrc
}

# ssh, copying .rc files for persistent use
function sshenv() {
    if [ -z "$1" ]; then
        echo "Usage: sshenv user@host"
        return 1
    fi
    local REMOTE="$1"
    local REMOTE_DIR=".austin_rc"

    # Paths to local configuration files/directories
    local LOCAL_ZSHRC="$HOME/.zshrc"
    local LOCAL_VIMRC="$HOME/.vimrc"
    local LOCAL_PSQLRC="$HOME/.psqlrc"
    local LOCAL_CONFIG_DIR="$HOME/.config/"

    # Remote host paths (relative to home directory)
    local REMOTE_ZSHRC="$REMOTE_DIR/.zshrc"
    local REMOTE_VIMRC="$REMOTE_DIR/.vimrc"
    local REMOTE_PSQLRC="$REMOTE_DIR/.psqlrc"
    local REMOTE_CONFIG_DIR="$REMOTE_DIR/.config/"

    # Ensure the remote directory exists
    ssh "$REMOTE" "mkdir -p ~/$REMOTE_DIR"

    # Function to transfer file if it doesn't exist on the remote host
    transfer_if_not_exists() {
        local local_file="$1"
        local remote_file="$2"
        ssh "$REMOTE" "[ -e ~/$remote_file ]" || rsync -av --ignore-existing "$local_file" "$REMOTE:~/$remote_file"
    }

    # Transfer files only if they don't exist on the remote host
    transfer_if_not_exists "$LOCAL_ZSHRC" "$REMOTE_ZSHRC"
    transfer_if_not_exists "$LOCAL_VIMRC" "$REMOTE_VIMRC"
    transfer_if_not_exists "$LOCAL_PSQLRC" "$REMOTE_PSQLRC"

    # Check if the remote .config directory exists
    ssh "$REMOTE" "[ -d ~/$REMOTE_CONFIG_DIR ]" || rsync -av --ignore-existing --exclude 'unnecessary_dir/' "$LOCAL_CONFIG_DIR" "$REMOTE:~/$REMOTE_CONFIG_DIR"

    # SSH into the remote host with environment variables set
    ssh -t "$REMOTE" "
        export VIMINIT='source ~/$REMOTE_DIR/.vimrc';
        export PSQLRC=~/$REMOTE_DIR/.psqlrc;
        export XDG_CONFIG_HOME=~/$REMOTE_DIR/.config;
        export ZDOTDIR=~/$REMOTE_DIR;
        exec zsh -i;
    "
}

# postgres
alias postgresmonitor="tail -f /var/log/postgresql/postgresql-*-main.log"

. "$HOME/.local/bin/env"
