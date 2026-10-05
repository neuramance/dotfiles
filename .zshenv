typeset -U path PATH fpath

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export PATH="$PATH:$HOME/.foundry/bin"

export PATH="$HOME/.local/share/mise/shims:$PATH"

export SUPABASE_ANALYTICS_ENABLED=false
