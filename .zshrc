# Zsh prompt: wires@mac:~$ 
PROMPT='%F{blue}%n%F{white}@%F{magenta}%m%F{white}:%F{green}%~%F{white}$ '

export EDITOR=vim

# Bash commands
alias c='clear'
alias cd..='cd ..'
alias zconf='vim ~/.zshrc'
alias ls='ls'
alias lsa='ls -a'
set LS_COLORS='di=34:fi=0:ln=93:ex=32'

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
alias cdkls='cdk ls'
alias bfs='bun run fs'

# Moom
alias moomexport='defaults export com.manytricks.Moom /Users/$USER/Documents/ComputerBackup/Moom.plist'
alias moomload='defaults import com.manytricks.Moom /Users/$USER/Documents/ComputerBackup/Moom.plist'

# Bun completions
[ -s "/Users/wires/.bun/_bun" ] && source "/Users/wires/.bun/_bun"

# Bun
export BUN_INSTALL="/Users/wires/.bun"
export PATH="$BUN_INSTALL/bin:~/.local/bin:$PATH"
