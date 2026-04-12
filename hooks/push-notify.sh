#!/usr/bin/env bash
# Push Notifications - Stop hook
# Sends a desktop notification when Claude completes work.
# Based on Claude Code's KAIROS_PUSH_NOTIFICATION feature.
#
# Uses notify-send for desktop and optionally ntfy.sh for mobile.

set -euo pipefail

# Parse the stop reason from hook input
HOOK_INPUT=$(cat)
STOP_REASON=$(echo "$HOOK_INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('stop_reason', 'unknown'))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

# Only notify on meaningful completions (not user interrupts)
case "$STOP_REASON" in
  end_turn|tool_use) ;; # These are normal completions
  *) exit 0 ;;
esac

# Desktop notification via notify-send
if command -v notify-send &>/dev/null; then
  notify-send -i terminal "Claude Code" "Task completed" -t 3000 2>/dev/null || true
fi

# Optional: mobile push via ntfy.sh
# Uncomment and set your topic to enable:
# NTFY_TOPIC="matt-claude-notify"
# curl -s -d "Claude Code task completed" "https://ntfy.sh/$NTFY_TOPIC" &>/dev/null || true

exit 0
