# Zsh prompt: wires@mac:~$ 
PROMPT='%F{blue}%n%F{white}@%F{magenta}%m%F{white}:%F{green}%~%F{white}$ '

export EDITOR=vim

# Shell
alias c='clear'
alias cd..='cd ..'
alias zconf='vim ~/.zshrc'
alias ls='exa -bhl --no-user --no-permissions'
alias sl='exa -bhl --no-user --no-permissions'
alias lsa='exa -abhl --no-user --no-permissions'
alias cat='bat'
echopath() { sed 's/:/\n/g' <<< "$PATH" }
set LS_COLORS='di=34:fi=0:ln=93:ex=32'
alias speedtest='speedtest-rs --bytes --no-upload --simple'

# Git
alias gits='git status'
alias gita='git add .'
alias gitd='git diff'
alias gitc='git commit'
alias gitp='git push'
alias glg='git log --graph --oneline --all'

# Python
alias py='python3'
alias pip='pip3'

# Homebrew
alias brewb='brew bundle -f dump'

# Rust
alias car='cargo run'
alias care='cargo run --example'
alias cac='cargo clean'
alias cab='cargo build'
alias cabr='cargo build --release'
alias caf='cargo fmt'

# AWS
alias cdks='cdk synth'
alias cdkd='cdk deploy'
alias cdkls='cdk ls'

# Amzn
alias a='kinit -f && mwinit -o'
alias bb=brazil-build

# Moom
alias moomexport='defaults export com.manytricks.Moom /Users/$USER/Documents/ComputerBackup/Moom.plist'
alias moomload='defaults import com.manytricks.Moom /Users/$USER/Documents/ComputerBackup/Moom.plist'

# Bun
[ -s "/Users/wires/.bun/_bun" ] && source "/Users/wires/.bun/_bun"
alias brd='bun run dev'
alias brf='bun run format'
alias bfs='bun run fs'
export BUN_INSTALL="/Users/wires/.bun"
export PATH="$BUN_INSTALL/bin:~/.local/bin:/Users/wires/Library/Python/3.9/bin:$PATH"

export PATH=$PATH:/Users/redacted/.toolbox/bin
export JAVA_HOME="/Library/Java/JavaVirtualMachines/amazon-corretto-17.jdk/Contents/Home"
