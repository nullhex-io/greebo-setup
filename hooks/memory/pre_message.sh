#!/usr/bin/env bash
# Pre-message hook - loads MEMORY.md index for context
# Memory search is handled by Cortex MCP (recall tool)

MEMORY_DIR="$HOME/.claude/projects/-home-matt-dev/memory"
MEMORY_FILE="$MEMORY_DIR/MEMORY.md"

if [ -f "$MEMORY_FILE" ]; then
    echo "<memory-context>"
    echo ""
    echo "## Recent context"
    echo ""
    echo "### MEMORY ($MEMORY_FILE)"
    cat "$MEMORY_FILE"
    echo "</memory-context>"
fi
