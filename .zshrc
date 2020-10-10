PROMPT="%F{blue}%n %F{white}%m %F{magenta}%~ %F{white}$ "

# setup proxy if config file exists
if [ -f ~/.proxyconf ]; then
    . ~/.proxyconf
fi

# utility:
command_exists () {
  type "$1" &> /dev/null ;
}

export LS_COLORS

export VISUAL=vim
export EDITOR="$VISUAL"


### aliases ###\
alias c="clear"

alias ls="gls --color=auto --group-directories-first"
alias lsa="gls -a --color=auto --group-directories-first"
LS_COLORS='di=34:fi=0:ln=93:ex=32'

alias sshhm="ssh bitnami@52.88.130.137"
alias glog="git log --graph --oneline --all"

bindkey '\e[A' history-beginning-search-backward
bindkey '\e[B' history-beginning-search-forward
