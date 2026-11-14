#!/bin/sh
# Turns a Claude Code hook event on stdin into a crownotify card. Notification cards say what
# Claude waits for, PermissionRequest cards name the tool, Stop cards carry the first line of
# the answer. Prints nothing, so no hook decision is implied.
set -eu

input=$(cat)
field() { printf '%s' "$input" | jq -r "$1"; }

event=$(field '.hook_event_name // ""')
app='Claude Code'
urgency=normal
icon=dialog-information

case $event in
    Notification)
        summary=$(field '.title // "Claude Code"')
        body=$(field '.message // "Needs your attention"')
        case $(field '.notification_type // ""') in
            permission_prompt) urgency=critical; icon=dialog-password ;;
            idle_prompt) summary='Claude is waiting for you' ;;
        esac
        ;;
    PermissionRequest)
        tool=$(field '.tool_name // "a tool"')
        summary="Claude asks to use $tool"
        body=$(field '.tool_input.command // .tool_input.description // .tool_input.file_path // ""' | cut -c1-200)
        urgency=critical
        icon=dialog-password
        ;;
    Stop)
        summary='Claude finished'
        body=$(field '.last_assistant_message // ""' | sed -n '1p' | cut -c1-200)
        icon=emblem-ok-symbolic
        ;;
    *)
        exit 0
        ;;
esac

command -v notify-send >/dev/null 2>&1 || exit 0
notify-send --app-name "$app" --urgency "$urgency" --icon "$icon" --expire-time 10000 \
    -- "$summary" "$body" >/dev/null 2>&1 || true
