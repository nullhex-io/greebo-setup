#!/usr/bin/env bash
# Pre-compaction hook - runs before Claude Code compresses the conversation
# Saves current status and prompts Claude to checkpoint

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="$SCRIPT_DIR/engine/memory_engine.py"
STATUS="$SCRIPT_DIR/status.md"

# Flush scores immediately (crash safety)
python3 "$ENGINE" flush 2>/dev/null

# Output status for context preservation
if [ -f "$STATUS" ]; then
    echo "<pre-compaction-checkpoint>"
    echo "Current status before compaction:"
    cat "$STATUS"
    echo ""
    echo "IMPORTANT: Before this conversation is compressed, update ~/dev/memory/status.md with:"
    echo "- What you were working on"
    echo "- What's done and what's remaining"
    echo "- Any decisions or context that should carry forward"
    echo "</pre-compaction-checkpoint>"
fi
