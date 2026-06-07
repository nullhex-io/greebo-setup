#!/usr/bin/env bash
# Session end hook - runs when a Claude Code session ends
# Flushes salience scores back to files

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="$SCRIPT_DIR/engine/memory_engine.py"

# Flush salience scores to file front-matter
python3 "$ENGINE" flush 2>/dev/null

# Reminder to update status (output goes to Claude as prompt)
echo "Remember: update ~/dev/infra/memory/status.md with what you were working on."
