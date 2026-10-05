[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

export PATH="$HOME/.elan/bin:$PATH"

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

export SHELL_SESSIONS_DISABLE=1

[[ $OSTYPE == darwin* ]] && ! ssh-add -T ~/.ssh/id_ed25519.pub 2>/dev/null && ssh-add --apple-load-keychain -q


# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"

export PATH="$HOME/.local/share/mise/shims:$PATH"
