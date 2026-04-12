#!/usr/bin/env bash
# Memory Lint - Structural health check for the memory wiki
# Inspired by Karpathy's LLM Wiki lint operation.
#
# Checks:
#   1. MEMORY.md links resolve to actual files
#   2. All .md files in memory dir are indexed in MEMORY.md
#   3. Frontmatter 'verified' dates - flags memories older than 14 days
#   4. Empty or near-empty memory files
#
# Runs daily via cron. No LLM needed - pure structural checks.
# Deep semantic lint (contradictions, cross-refs) is handled by dream consolidation.
#
# Install:
#   0 5 * * * $HOME/dev/memory/engine/lint-memories.sh >> /tmp/memory-lint.log 2>&1

set -euo pipefail

MEMORY_DIR="$HOME/.claude/projects/-home-$(whoami)-dev/memory"
INDEX="$MEMORY_DIR/MEMORY.md"
REPORT="$HOME/dev/memory/lint-report.md"
NOW_EPOCH=$(date +%s)
STALE_DAYS=14

errors=0
warnings=0

# Collect results
broken_links=()
orphan_files=()
stale_memories=()
empty_files=()
index_over_limit=false

# --- Check 1: MEMORY.md links resolve ---
if [ -f "$INDEX" ]; then
  while IFS= read -r link; do
    # Extract relative path from markdown links like [Title](file.md)
    if [ ! -f "$MEMORY_DIR/$link" ]; then
      broken_links+=("$link")
      ((errors++)) || true
    fi
  done < <(grep -oP '\]\(\K[^)]+\.md' "$INDEX" 2>/dev/null || true)
else
  broken_links+=("MEMORY.md itself is missing!")
  ((errors++)) || true
fi

# --- Check 2: All .md files are indexed ---
while IFS= read -r filepath; do
  filename=$(basename "$filepath")
  # Skip MEMORY.md itself
  [ "$filename" = "MEMORY.md" ] && continue
  # Check if referenced in MEMORY.md
  if ! grep -qF "$filename" "$INDEX" 2>/dev/null; then
    orphan_files+=("$filename")
    ((warnings++)) || true
  fi
done < <(find "$MEMORY_DIR" -maxdepth 2 -name "*.md" -not -name "MEMORY.md" 2>/dev/null)

# --- Check 3: Stale verified dates ---
while IFS= read -r filepath; do
  filename=$(basename "$filepath")
  [ "$filename" = "MEMORY.md" ] && continue

  # Extract verified date from frontmatter
  verified=$(sed -n '/^---$/,/^---$/{ /^verified:/{ s/^verified: *//; p; } }' "$filepath" 2>/dev/null | head -1)
  if [ -n "$verified" ]; then
    # Parse date
    verified_epoch=$(date -d "$verified" +%s 2>/dev/null || echo "0")
    if [ "$verified_epoch" != "0" ]; then
      days_old=$(( (NOW_EPOCH - verified_epoch) / 86400 ))
      if [ "$days_old" -gt "$STALE_DAYS" ]; then
        stale_memories+=("$filename (${days_old}d old)")
        ((warnings++)) || true
      fi
    fi
  fi
done < <(find "$MEMORY_DIR" -maxdepth 2 -name "*.md" -not -name "MEMORY.md" 2>/dev/null)

# --- Check 4: Empty or near-empty files ---
while IFS= read -r filepath; do
  filename=$(basename "$filepath")
  [ "$filename" = "MEMORY.md" ] && continue

  # Count non-frontmatter, non-blank lines
  content_lines=$(sed '/^---$/,/^---$/d' "$filepath" 2>/dev/null | grep -c '[^ ]' 2>/dev/null || echo "0")
  if [ "$content_lines" -lt 2 ]; then
    empty_files+=("$filename (${content_lines} content lines)")
    ((warnings++)) || true
  fi
done < <(find "$MEMORY_DIR" -maxdepth 2 -name "*.md" -not -name "MEMORY.md" 2>/dev/null)

# --- Check 5: MEMORY.md line count ---
if [ -f "$INDEX" ]; then
  line_count=$(wc -l < "$INDEX")
  if [ "$line_count" -gt 200 ]; then
    index_over_limit=true
    ((warnings++)) || true
  fi
fi

# --- Generate report ---
{
  echo "# Memory Lint Report"
  echo "Generated: $(date '+%Y-%m-%d %H:%M')"
  echo "Errors: $errors | Warnings: $warnings"
  echo ""

  if [ "$errors" -eq 0 ] && [ "$warnings" -eq 0 ]; then
    echo "All clear. No issues found."
  fi

  if [ ${#broken_links[@]} -gt 0 ]; then
    echo "## Broken Links (ERROR)"
    echo "MEMORY.md references files that don't exist:"
    for link in "${broken_links[@]}"; do
      echo "- \`$link\`"
    done
    echo ""
  fi

  if [ ${#orphan_files[@]} -gt 0 ]; then
    echo "## Orphan Files (WARNING)"
    echo "Memory files not referenced in MEMORY.md:"
    for f in "${orphan_files[@]}"; do
      echo "- \`$f\`"
    done
    echo ""
  fi

  if [ ${#stale_memories[@]} -gt 0 ]; then
    echo "## Stale Memories (WARNING)"
    echo "Memories with verified date older than ${STALE_DAYS} days:"
    for m in "${stale_memories[@]}"; do
      echo "- \`$m\`"
    done
    echo ""
  fi

  if [ ${#empty_files[@]} -gt 0 ]; then
    echo "## Empty/Sparse Files (WARNING)"
    echo "Memory files with almost no content:"
    for f in "${empty_files[@]}"; do
      echo "- \`$f\`"
    done
    echo ""
  fi

  if [ "$index_over_limit" = true ]; then
    echo "## Index Over Limit (WARNING)"
    echo "MEMORY.md has $line_count lines (limit: 200). Truncation will occur."
    echo ""
  fi

} > "$REPORT"

echo "[$(date)] Lint: $errors errors, $warnings warnings. Report at $REPORT"

# Exit non-zero if errors found (useful for alerting)
[ "$errors" -eq 0 ]
