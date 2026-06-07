#!/usr/bin/env bash
# Dream Consolidation - Memory synthesis agent
# Based on Claude Code's KAIROS_DREAM feature (autoDream.ts + consolidationPrompt.ts)
#
# Runs periodically (via cron) to consolidate memories across sessions.
# Gates: 24h since last run + 5+ sessions since last consolidation.
#
# Install: Add to cron alongside thinking loop
#   0 3 * * * $HOME/dev/infra/memory/engine/dream-consolidation.sh
#
# Or run manually: ./dream-consolidation.sh

set -euo pipefail

MEMORY_ROOT="$HOME/.claude/projects/-home-$(whoami)-dev/memory"
TRANSCRIPT_DIR="$HOME/.claude/projects/-home-$(whoami)-dev"
LOCK_FILE="/tmp/claude-dream-consolidation.lock"
LAST_RUN_FILE="$MEMORY_ROOT/.last-dream-consolidation"
MAX_ENTRYPOINT_LINES=200

# Gate 1: Time - at least 24 hours since last consolidation
if [ -f "$LAST_RUN_FILE" ]; then
  LAST_RUN=$(cat "$LAST_RUN_FILE")
  NOW=$(date +%s)
  HOURS_SINCE=$(( (NOW - LAST_RUN) / 3600 ))
  if [ "$HOURS_SINCE" -lt 24 ]; then
    echo "Dream: Only ${HOURS_SINCE}h since last consolidation (need 24h). Sleeping."
    exit 0
  fi
fi

# Gate 2: Sessions - at least 5 sessions since last consolidation
if [ -d "$TRANSCRIPT_DIR" ]; then
  if [ -f "$LAST_RUN_FILE" ]; then
    SESSION_COUNT=$(find "$TRANSCRIPT_DIR" -maxdepth 1 -name "*.jsonl" -newer "$LAST_RUN_FILE" 2>/dev/null | wc -l)
  else
    SESSION_COUNT=$(find "$TRANSCRIPT_DIR" -maxdepth 1 -name "*.jsonl" 2>/dev/null | wc -l)
  fi
  if [ "$SESSION_COUNT" -lt 5 ]; then
    echo "Dream: Only ${SESSION_COUNT} sessions since last consolidation (need 5). Sleeping."
    exit 0
  fi
else
  echo "Dream: No transcript directory found. Sleeping."
  exit 0
fi

# Gate 3: Lock - no concurrent consolidation
if [ -f "$LOCK_FILE" ]; then
  if [ "$(find "$LOCK_FILE" -mmin +30 2>/dev/null)" ]; then
    rm -f "$LOCK_FILE"
  else
    echo "Dream: Another consolidation in progress. Sleeping."
    exit 0
  fi
fi

touch "$LOCK_FILE"
echo "Dream: Starting consolidation (${SESSION_COUNT} sessions since last run)..."

# Create archive directory for soft-deleted memories
ARCHIVE_DIR="$MEMORY_ROOT/.archive"
mkdir -p "$ARCHIVE_DIR"

# Get recent session IDs for context
if [ -f "$LAST_RUN_FILE" ]; then
  RECENT_SESSIONS=$(find "$TRANSCRIPT_DIR" -maxdepth 1 -name "*.jsonl" -newer "$LAST_RUN_FILE" 2>/dev/null | \
    head -20 | while read -r f; do basename "$f" .jsonl; done | tr '\n' ', ') || true
else
  RECENT_SESSIONS=$(find "$TRANSCRIPT_DIR" -maxdepth 1 -name "*.jsonl" -mtime -7 2>/dev/null | \
    head -20 | while read -r f; do basename "$f" .jsonl; done | tr '\n' ', ') || true
fi

# Generate fresh staleness report before dreaming (optional - depends on your setup)
if [ -d "$HOME/dev/infra/memory-freshness" ]; then
  cd "$HOME/dev/infra/memory-freshness" && bun src/index.ts --briefing --no-telegram 2>/dev/null || true
fi
FRESHNESS_REPORT="$HOME/dev/infra/memory/freshness-report.md"

PROMPT_FILE=$(mktemp /tmp/dream-prompt-XXXXXX.md)
cat > "$PROMPT_FILE" << PROMPT_EOF
# Dream: Memory Consolidation

You are performing a dream - a reflective pass over your memory files. Synthesize what you've learned recently into durable, well-organized memories so that future sessions can orient quickly.

Memory directory: $MEMORY_ROOT

## Strategy: Two-turn parallel

For efficiency, batch your work:
- **Read phase**: Issue all Read/Glob/Grep calls in parallel first. Gather all the information you need before making changes.
- **Write phase**: Once oriented, issue all Edit/Write calls. Don't interleave reading and writing.

## Confidence tagging

When creating or updating memories, add a confidence field to frontmatter:
- **high** - directly stated by the user, observed in code, or verified by test
- **medium** - inferred from context or partially confirmed
- **low** - single observation, may not generalize

During consolidation: promote memories that accumulate evidence, demote/prune those that don't. Fewer strong memories > many weak ones.

## Save successes too

Don't only save corrections. If a feedback memory records an approach that worked well (not just "don't do X"), keep it. Drift away from validated patterns is as harmful as repeating mistakes.

## Phase 1 - Orient

- ls the memory directory to see what already exists
- Read MEMORY.md to understand the current index
- Skim existing topic files so you improve them rather than creating duplicates
- Read all files in the read phase before starting any writes

## Phase 2 - Triage stale memories

Read the freshness report at $FRESHNESS_REPORT (if it exists). For each stale memory:
- Read the memory file
- Check if its claims are still true (grep codebase, check git, verify files exist)
- If still accurate: update the verified date in frontmatter to today
- If outdated: fix the content, then update verified date
- If obsolete: move the file to $ARCHIVE_DIR/ (e.g. `mv file.md $ARCHIVE_DIR/file.md`) and remove from MEMORY.md index. NEVER hard-delete memory files.

This is the highest-priority phase. Stale memories cause wrong decisions in future sessions.

## Phase 3 - Gather recent signal

Look for new information worth persisting:
1. Existing memories that drifted - facts that contradict something you see in the codebase now
2. Check recent git activity: git log --oneline -20

Don't exhaustively search. Look only for things you already suspect matter.

## Phase 4 - Lint: cross-references and contradictions

Read the lint report at $HOME/dev/infra/memory/lint-report.md (if it exists). Address any errors first, then warnings.

Then do a semantic pass across memories you read:
- **Contradictions**: If memory A says "X is retired" but memory B still references X as active, fix B.
- **Missing cross-refs**: If two memories discuss the same entity (a project, tool, person) but don't reference each other, add a link or mention.
- **Orphan cleanup**: If a memory file exists but isn't in MEMORY.md, either add it to the index or move it to $ARCHIVE_DIR/.
- **Near-duplicates**: If two memories cover the same topic, merge them into one and move the other to $ARCHIVE_DIR/.

## Phase 5 - Consolidate (ingest ripple)

For each thing worth remembering, write or update a memory file at the top level of the memory directory. Use the memory file format with YAML frontmatter (name, description, type).

When creating or updating a memory, apply the ingest ripple:
- Identify 3-5 existing memories most related to the change
- Check if they need updating too (stale references, new cross-links, contradicted claims)
- Update them in the same pass

Focus on:
- Merging new signal into existing topic files rather than creating near-duplicates
- Converting relative dates to absolute dates so they remain interpretable
- Deleting contradicted facts

## Phase 6 - Prune and index

Update MEMORY.md so it stays under ${MAX_ENTRYPOINT_LINES} lines AND under ~25KB. It's an index, not a dump - each entry should be one line under ~150 characters.

- Remove pointers to stale/wrong/superseded memories
- Add pointers to newly important memories
- Resolve contradictions

Return a brief summary of what you consolidated, updated, or pruned.
PROMPT_EOF

claude -p "$(cat "$PROMPT_FILE")" \
  --allowedTools "Read,Edit,Write,Glob,Grep,Bash" \
  --dangerously-skip-permissions \
  < /dev/null 2>&1 || true

rm -f "$PROMPT_FILE"

# Rotate archive - purge files older than 30 days
find "$ARCHIVE_DIR" -name "*.md" -mtime +30 -delete 2>/dev/null || true

# Update last run timestamp
date +%s > "$LAST_RUN_FILE"

# Update Cortex's internal consolidation_log so memory_stats reports the
# correct last_consolidation timestamp. The marker file above only tracks
# this script's run cadence; Cortex queries the consolidation_log table.
psql -U "$(whoami)" -d cortex -c "INSERT INTO consolidation_log (timestamp) VALUES (now())" >/dev/null 2>&1 \
  && echo "Dream: consolidation_log updated." \
  || echo "Dream: warning - failed to update consolidation_log."

rm -f "$LOCK_FILE"

echo "Dream: Consolidation complete."
