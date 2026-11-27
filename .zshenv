typeset -U path PATH fpath

skip_global_compinit=1

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export PATH="$PATH:$HOME/.foundry/bin"
export PATH="$PATH:/usr/lib/postgresql/18/bin"

export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

[[ ${HOST%%.*} == i9 && -z ${TURBO_HASH-} ]] && export TURBO_BINARY_PATH="$HOME/.local/bin/turbo-gate"

export SUPABASE_ANALYTICS_ENABLED=false
export SUPABASE_TELEMETRY_DISABLED=1
