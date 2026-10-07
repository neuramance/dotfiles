typeset -U path PATH fpath

skip_global_compinit=1

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export PATH="$PATH:$HOME/.foundry/bin"

export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

export SUPABASE_ANALYTICS_ENABLED=false
export SUPABASE_TELEMETRY_DISABLED=1
