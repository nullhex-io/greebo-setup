#!/usr/bin/env bash
# Extract Memories - Stop hook
# Runs after each conversation turn, spawns a background memory extraction agent
# that scans recent messages and saves durable memories.
#
# Based on Claude Code's EXTRACT_MEMORIES feature (tengu_passport_quail gate)
# Extracted from: src/services/extractMemories/extractMemories.ts

set -euo pipefail

# Only run if auto-memory is enabled (memory dir exists)
MEMORY_DIR="$HOME/.claude/projects/-home-matt-dev/memory"
[ -d "$MEMORY_DIR" ] || exit 0

# Throttle: only run every 3rd invocation to avoid excessive API calls
COUNTER_FILE="/tmp/claude-extract-memories-counter"
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"
[ $((COUNT % 3)) -eq 0 ] || exit 0

# Check if extraction is already running
LOCK_FILE="/tmp/claude-extract-memories.lock"
if [ -f "$LOCK_FILE" ]; then
  # Check if lock is stale (older than 5 minutes)
  if [ "$(find "$LOCK_FILE" -mmin +5 2>/dev/null)" ]; then
    rm -f "$LOCK_FILE"
  else
    exit 0
  fi
fi

touch "$LOCK_FILE"

# Get list of existing memory files for context
MEMORY_MANIFEST=$(ls -1 "$MEMORY_DIR"/*.md 2>/dev/null | while read f; do
  basename "$f"
done | tr '\n' ', ')

# Spawn extraction agent in background
(
  claude -p --print "You are the memory extraction subagent. Analyze the conversation that just ended and update persistent memory if warranted.

Available memory files: ${MEMORY_MANIFEST:-none}
Memory directory: $MEMORY_DIR

You MUST only save information that will be useful in FUTURE conversations. Do not save:
- Code patterns, architecture, file paths (derivable from code)
- Git history (derivable from git log)
- Debugging solutions (the fix is in the code)
- Ephemeral task details

DO save:
- User preferences and corrections (feedback type)
- Project status changes (project type)
- New external references (reference type)
- User role/knowledge updates (user type)

If nothing worth remembering happened, say 'No new memories' and stop.

Use the memory file format with YAML frontmatter (name, description, type fields).
Update MEMORY.md index if you create/modify files.
Check existing files before creating duplicates - prefer updating." \
  --allowedTools "Read,Edit,Write,Glob,Grep" \
  --max-turns 5 \
  2>/dev/null || true

  rm -f "$LOCK_FILE"
) &

exit 0
