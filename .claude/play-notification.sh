#!/bin/bash
# Shared by Claude Code and Codex CLI; both pass hook_event_name on stdin.
# Claude Code's idle_prompt fires 60s after Stop and would double the turn-end sound.

input=$(cat 2>/dev/null || true)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // (if .toolCall or .tool_call then "PreToolUse" else empty end)' 2>/dev/null)
notif_type=$(printf '%s' "$input" | jq -r '.notification_type // empty' 2>/dev/null)
[ "$notif_type" = "idle_prompt" ] && exit 0

case "$event" in
    Notification|PermissionRequest|PreToolUse) sound="Funk" ;;
    *) sound="Purr" ;;
esac

mac_sound_port=47123

play_through_ssh_tunnel() {
    timeout 1 bash -c 'exec 3<>"/dev/tcp/127.0.0.1/$2" && printf "%s\n" "$1" >&3 && read -r reply <&3 && [ "$reply" = ok ]' _ "$1" "$mac_sound_port" 2>/dev/null
}

ring_terminal_bell() {
    { printf '\a' > /dev/tty; } 2>/dev/null && return
    local pid=$PPID tty
    while [ "${pid:-1}" -gt 1 ]; do
        tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -n "$tty" ] && [ "$tty" != "?" ]; then
            { printf '\a' > "/dev/$tty"; } 2>/dev/null
            return
        fi
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    done
}

lock_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-$HOME/.cache}}"
mkdir -p "$lock_dir"
lock_file="$lock_dir/play_notification_last"
now=$(date +%s%N 2>/dev/null)
[[ "$now" == *N ]] && now="$(date +%s)000000000"
now=$((now / 1000000))
should_play=1
if [ -f "$lock_file" ]; then
    last=$(cat "$lock_file" 2>/dev/null)
    [[ "$last" =~ ^[0-9]+$ ]] || last=0
    if [ $((now - last)) -lt 2000 ] && [ $((now - last)) -ge 0 ]; then
        should_play=0
    fi
fi

if [ "$should_play" -eq 1 ]; then
    echo "$now" > "$lock_file"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        afplay -v 1.8 "/System/Library/Sounds/${sound}.aiff" >/dev/null 2>&1 &
    elif [[ -f /proc/sys/kernel/osrelease ]] && grep -qi "microsoft" /proc/sys/kernel/osrelease 2>/dev/null; then
        powershell.exe -Command "(New-Object Media.SoundPlayer 'C:\Windows\Media\Windows Notify.wav').PlaySync()" >/dev/null 2>&1 &
    elif [[ -z "${SSH_CONNECTION:-}" ]] && command -v paplay &> /dev/null; then
        paplay /usr/share/sounds/freedesktop/stereo/message.oga >/dev/null 2>&1 &
    else
        play_through_ssh_tunnel "$sound" || ring_terminal_bell
    fi
fi

printf '{}\n'
