#!/usr/bin/env bash
# Session start hook - runs when a Claude Code session begins
# Rebuilds index, runs health check, loads briefing

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="$SCRIPT_DIR/engine/memory_engine.py"
HEALTH="$SCRIPT_DIR/engine/memory_check.py"
BRIEFING="$SCRIPT_DIR/assistant/briefing.md"

# Rebuild search index (fast - skips unchanged files)
python3 "$ENGINE" index 2>/dev/null

# Run health check (non-blocking)
python3 "$HEALTH" 2>/dev/null

# Load briefing if it exists
if [ -f "$BRIEFING" ]; then
    echo "<session-briefing>"
    cat "$BRIEFING"
    echo "</session-briefing>"
fi
