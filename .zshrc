# Zsh prompt: wires@mac:~$ 
PROMPT="%F{blue}%n%F{white}@%F{magenta}%m%F{white}:%F{green}%~%F{white}$ "

# Environment vars
export EDITOR=vim
export LS_COLORS="di=36:fi=0:ln=93:ex=32"

# Shell
alias c="clear"
alias cd..="cd .."
alias zconf="code ~/.zshrc"
alias ls="exa -bhlF --no-user --no-permissions --no-time --group-directories-first"
alias sl="exa -bhlF --no-user --no-permissions --no-time --group-directories-first"
alias lsa="exa -abhlF --no-user --no-permissions --no-time --group-directories-first"
alias cat="bat"
alias speedtest="speedtest-rs --bytes --no-upload --simple"

# Git
alias gits="git status"
alias gita="git add ."
alias gitd="git diff"
alias gitc="git commit"
alias gitp="git push"
alias glg="git log --graph --oneline --all"

# Rust
alias car="cargo run"
alias care="cargo run --example"
alias cac="cargo clean"
alias cab="cargo build"
alias cabr="cargo build --release"
alias carr="cargo run --release"
alias cabr="cargo build --release && cargo run --release"
alias caf="cargo fmt"

# Python
alias py="python3"
alias python="python3"
alias pip="pip3"
alias pr="poetry run"
export PATH="`python3 -m site --user-base`/bin:$PATH"

# Homebrew
alias brewb="brew bundle -f dump"

# Bun completions
[ -s "/Users/redacted/.bun/_bun" ] && source "/Users/redacted/.bun/_bun"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
alias brd="bun run dev"

# Node
export NVM_DIR=~/.nvm
source $(brew --prefix nvm)/nvm.sh

# AWS
alias cdks="cdk synth"
alias cdkd="cdk deploy"
alias cdkls="cdk ls"

# Moom
alias moomexport="defaults export com.manytricks.Moom /Users/$USER/Documents/ComputerBackup/Moom.plist"
alias moomload="defaults import com.manytricks.Moom /Users/$USER/Documents/ComputerBackup/Moom.plist"

# Amzn
alias a="kinit -f && mwinit -o"
alias bb="brazil-build"
export PATH="$PATH:/Users/redacted/.toolbox/bin"
export JAVA_HOME="/Library/Java/JavaVirtualMachines/amazon-corretto-17.jdk/Contents/Home"

# Youtube-dl
alias youtube-dl='python3 /usr/local/bin/youtube-dl'
alias ytd='youtube-dl -f bestaudio --extract-audio --audio-format wav --audio-quality 0'

# Load Zsh Functions
fpath+=~/.zfunc
autoload -Uz compinit && compinit

# Dependent aliases (MUST BE AT BOTTOM)
alias echopath="echo $PATH | tr ':' '\n'"