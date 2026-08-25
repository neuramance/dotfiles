#!/bin/bash
# Shared by Claude Code and Codex CLI; both pass hook_event_name on stdin.
# Claude Code's idle_prompt fires 60s after Stop and would double the turn-end sound.

input=$(cat 2>/dev/null || true)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
notif_type=$(printf '%s' "$input" | jq -r '.notification_type // empty' 2>/dev/null)
[ "$notif_type" = "idle_prompt" ] && exit 0

case "$event" in
    Notification|PermissionRequest|PreToolUse) sound="Funk" ;;
    *) sound="Purr" ;;
esac

if [[ "$OSTYPE" == "darwin"* ]]; then
    afplay -v 1.8 "/System/Library/Sounds/${sound}.aiff"
elif [[ -f /proc/sys/kernel/osrelease ]] && grep -qi "microsoft" /proc/sys/kernel/osrelease 2>/dev/null; then
    powershell.exe -Command "(New-Object Media.SoundPlayer 'C:\Windows\Media\Windows Notify.wav').PlaySync()" 2>/dev/null &
elif [[ "$OSTYPE" == "linux-gnu"* ]] && command -v paplay &> /dev/null; then
    paplay /usr/share/sounds/freedesktop/stereo/message.oga 2>/dev/null &
fi
