#!/usr/bin/env bash
# Compaction Reminder - PostToolUse hook
# Tracks approximate token usage and warns when approaching context limits.
# Based on Claude Code's COMPACTION_REMINDERS and CONTEXT_COLLAPSE features.

set -euo pipefail

# Track tool call count as a rough proxy for context growth
COUNTER_FILE="/tmp/claude-tool-counter-$$"
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# Warn at different thresholds
if [ "$COUNT" -eq 80 ]; then
  echo '{"warning": "Context growing large (~80 tool calls). Consider using /compact if responses slow down."}' >&2
elif [ "$COUNT" -eq 120 ]; then
  echo '{"warning": "Context very large (~120 tool calls). Strongly recommend /compact to preserve quality."}' >&2
elif [ "$COUNT" -eq 150 ]; then
  echo '{"warning": "Context critically large (~150 tool calls). Run /compact now to avoid degraded responses."}' >&2
fi

exit 0
