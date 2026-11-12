#!/usr/bin/env bash
# Claude Code hook: mirror session state into the tmux pane options that
# .tmux.conf already renders for Copilot (@copilot_state / @copilot_status),
# and ring the pane's bell when Claude finishes or needs input.
# Wired from ~/.claude/settings.json for SessionStart, UserPromptSubmit,
# PreToolUse, Notification, Stop and SessionEnd.

[ -n "$TMUX" ] && [ -n "$TMUX_PANE" ] && command -v tmux >/dev/null || exit 0

event=$(jq -r '.hook_event_name // empty' 2>/dev/null)
pane=$TMUX_PANE
lease=$(( $(date +%s) + 3600 ))

set_state() {
    tmux set-option -p -t "$pane" @copilot_state "$1" \; \
         set-option -p -t "$pane" @copilot_status "$2" \; \
         set-option -p -t "$pane" @copilot_status_until "$lease" 2>/dev/null
}

clear_state() {
    for opt in @copilot_state @copilot_status @copilot_status_until @copilot_status_owner; do
        tmux set-option -p -u -t "$pane" "$opt" 2>/dev/null
    done
}

ring() {
    tty=$(tmux display-message -p -t "$pane" '#{pane_tty}' 2>/dev/null)
    [[ "$tty" =~ ^/dev/pts/[0-9]+$ ]] && printf '\a' > "$tty"
}

case "$event" in
    UserPromptSubmit|PreToolUse) set_state running " 🤔" ;;
    Notification)                set_state waiting " ✋"; ring ;;
    Stop)                        set_state done " ✅"; ring ;;
    SessionStart|SessionEnd)     clear_state ;;
esac
exit 0
