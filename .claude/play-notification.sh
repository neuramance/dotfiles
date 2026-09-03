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

lock_file="/tmp/play_notification_last"
now=$(date +%s%N 2>/dev/null)
[[ "$now" == *N ]] && now="$(date +%s)000000000"
now=$((now / 1000000))
should_play=1
if [ -f "$lock_file" ]; then
    last=$(cat "$lock_file" 2>/dev/null || echo 0)
    if [ $((now - last)) -lt 2000 ] && [ $((now - last)) -ge 0 ]; then
        should_play=0
    fi
fi

if [ "$should_play" -eq 1 ]; then
    echo "$now" > "$lock_file"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        afplay -v 1.8 "/System/Library/Sounds/${sound}.aiff" &
    elif [[ -f /proc/sys/kernel/osrelease ]] && grep -qi "microsoft" /proc/sys/kernel/osrelease 2>/dev/null; then
        powershell.exe -Command "(New-Object Media.SoundPlayer 'C:\Windows\Media\Windows Notify.wav').PlaySync()" 2>/dev/null &
    elif [[ "$OSTYPE" == "linux-gnu"* ]] && command -v paplay &> /dev/null; then
        paplay /usr/share/sounds/freedesktop/stereo/message.oga 2>/dev/null &
    fi
fi

if [ "$event" = "PreToolUse" ]; then
    printf '{"decision":"allow"}\n'
else
    printf '{}\n'
fi
