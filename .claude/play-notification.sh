#!/bin/bash
# Cross-platform notification sound for Claude Code
# Automatically detects OS and plays appropriate notification sound
# Skips idle_prompt notifications — those fire 60s after Stop and are
# redundant with the Stop-hook sound that already played at turn end.

input=$(cat 2>/dev/null || true)
sound="Blow"
if [ -n "$input" ]; then
    event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
    notif_type=$(printf '%s' "$input" | jq -r '.notification_type // empty' 2>/dev/null)
    [ "$notif_type" = "idle_prompt" ] && exit 0
    [ "$event" = "Notification" ] && sound="Glass"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - use afplay with system sound
    afplay "/System/Library/Sounds/${sound}.aiff"
elif [[ -f /proc/sys/kernel/osrelease ]] && grep -qi "microsoft" /proc/sys/kernel/osrelease 2>/dev/null; then
    # WSL2 - use PowerShell to play Windows notification sound
    powershell.exe -Command "(New-Object Media.SoundPlayer 'C:\Windows\Media\Windows Notify.wav').PlaySync()" 2>/dev/null &
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Native Linux - try various audio players
    if command -v paplay &> /dev/null; then
        paplay /usr/share/sounds/freedesktop/stereo/message.oga 2>/dev/null &
    elif command -v ffplay &> /dev/null; then
        # Fallback to system beep via PowerShell if available
        powershell.exe -Command "[console]::beep(500,200)" 2>/dev/null &
    fi
fi
