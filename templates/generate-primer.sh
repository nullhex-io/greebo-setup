#!/usr/bin/env bash
# Generate SESSION_PRIMER.md for CoachSync
# Gives new Claude sessions a quick resume context without full codebase exploration
#
# Usage: ./scripts/generate-primer.sh
# Called automatically by post-commit hook

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

OUT=".planning/SESSION_PRIMER.md"
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
TODAY=$(date '+%Y-%m-%d')

# How many days of git history to include
DAYS=${PRIMER_DAYS:-7}

cat > "$OUT" << HEADER
# CoachSync Session Primer

Generated: ${NOW}
Read this instead of running /rlm-explore. Only explore when auditing for unknown issues.

HEADER

# --- Recent commits ---
echo "## Recent Changes (last ${DAYS} days)" >> "$OUT"
echo "" >> "$OUT"

COMMITS=$(git log --oneline --since="${DAYS} days ago" 2>/dev/null || true)
COMMIT_COUNT=$(echo "$COMMITS" | grep -c . || echo "0")

if [ "$COMMIT_COUNT" -gt 0 ]; then
    echo "${COMMIT_COUNT} commits:" >> "$OUT"
    echo '```' >> "$OUT"
    echo "$COMMITS" >> "$OUT"
    echo '```' >> "$OUT"
else
    echo "No commits in the last ${DAYS} days." >> "$OUT"
fi
echo "" >> "$OUT"

# --- Files changed summary ---
echo "## Changed Areas" >> "$OUT"
echo "" >> "$OUT"

if [ "$COMMIT_COUNT" -gt 0 ]; then
    echo "Directories with most changes:" >> "$OUT"
    echo '```' >> "$OUT"
    git log --since="${DAYS} days ago" --name-only --pretty=format: \
        | grep -v '^$' \
        | sed 's|/[^/]*$||' \
        | sort | uniq -c | sort -rn | head -15 >> "$OUT"
    echo '```' >> "$OUT"
else
    echo "No changes." >> "$OUT"
fi
echo "" >> "$OUT"

# --- Current branch state ---
echo "## Branch State" >> "$OUT"
echo "" >> "$OUT"
BRANCH=$(git branch --show-current)
AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "?")
BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "?")
echo "- Branch: \`${BRANCH}\`" >> "$OUT"
echo "- Ahead of main: ${AHEAD} commits" >> "$OUT"
echo "- Behind main: ${BEHIND} commits" >> "$OUT"

# Uncommitted changes
DIRTY=$(git status --porcelain | wc -l)
if [ "$DIRTY" -gt 0 ]; then
    echo "- **Uncommitted changes: ${DIRTY} files**" >> "$OUT"
    echo '```' >> "$OUT"
    git status --porcelain | head -20 >> "$OUT"
    [ "$DIRTY" -gt 20 ] && echo "... and $((DIRTY - 20)) more" >> "$OUT"
    echo '```' >> "$OUT"
fi
echo "" >> "$OUT"

# --- Open audit findings ---
echo "## Open Audit Findings" >> "$OUT"
echo "" >> "$OUT"

AUDIT_FILES=$(ls .planning/AUDIT_*.md 2>/dev/null || true)
if [ -n "$AUDIT_FILES" ]; then
    for audit_file in $AUDIT_FILES; do
        AUDIT_DATE=$(basename "$audit_file" | sed 's/AUDIT_//;s/.md//')
        # Count from resolution tracking table only (avoids double-counting findings tables)
        OPEN_COUNT=$(grep -c "| OPEN |" "$audit_file" 2>/dev/null || true)
        OPEN_COUNT=${OPEN_COUNT:-0}
        FIXED_COUNT=$(grep -cE "\| (FIXED|WONTFIX) \|" "$audit_file" 2>/dev/null || true)
        FIXED_COUNT=${FIXED_COUNT:-0}
        TOTAL_COUNT=$((OPEN_COUNT + FIXED_COUNT))
        if [ "$OPEN_COUNT" -gt 0 ]; then
            echo "### Audit ${AUDIT_DATE}: ${OPEN_COUNT}/${TOTAL_COUNT} open" >> "$OUT"
            echo "" >> "$OUT"
            # Extract HIGH findings from the findings tables (exclude resolution table lines)
            grep -E "^\| H[0-9]+ \|" "$audit_file" 2>/dev/null | grep -v "| OPEN |" | grep -v "| FIXED |" | head -5 | while IFS='|' read -r _ num finding _ _; do
                num=$(echo "$num" | xargs)
                finding=$(echo "$finding" | xargs | head -c 120)
                echo "- **${num}**: ${finding}" >> "$OUT"
            done
            # Count MEDIUM and LOW from resolution table
            MEDIUM_OPEN=$(grep -cE "^\| M[0-9]+.*OPEN" "$audit_file" 2>/dev/null || true)
            MEDIUM_OPEN=${MEDIUM_OPEN:-0}
            LOW_OPEN=$(grep -cE "^\| L[0-9]+.*OPEN" "$audit_file" 2>/dev/null || true)
            LOW_OPEN=${LOW_OPEN:-0}
            [ "$MEDIUM_OPEN" -gt 0 ] && echo "- Plus ${MEDIUM_OPEN} MEDIUM findings open" >> "$OUT"
            [ "$LOW_OPEN" -gt 0 ] && echo "- Plus ${LOW_OPEN} LOW findings open" >> "$OUT"
            echo "" >> "$OUT"
        fi
    done
else
    echo "No audit files found." >> "$OUT"
fi

# --- Project state ---
echo "## Project State" >> "$OUT"
echo "" >> "$OUT"

if [ -f ".planning/STATE.md" ]; then
    # Extract key fields from frontmatter
    MILESTONE=$(grep "^milestone_name:" .planning/STATE.md | sed 's/milestone_name: //' || echo "unknown")
    STATUS=$(grep "^status:" .planning/STATE.md | sed 's/status: //' || echo "unknown")
    LAST_ACTIVITY=$(grep "^  last_activity:" .planning/STATE.md 2>/dev/null || grep "^last_activity:" .planning/STATE.md 2>/dev/null | sed 's/.*last_activity: //' || echo "unknown")
    echo "- Milestone: ${MILESTONE}" >> "$OUT"
    echo "- Status: ${STATUS}" >> "$OUT"
    echo "- Last activity: ${LAST_ACTIVITY}" >> "$OUT"

    # Extract remaining tech debt section if it exists
    TECH_DEBT=$(sed -n '/### Remaining Tech Debt/,/^###/p' .planning/STATE.md | head -10)
    if [ -n "$TECH_DEBT" ]; then
        echo "" >> "$OUT"
        echo "$TECH_DEBT" >> "$OUT"
    fi
else
    echo "No STATE.md found." >> "$OUT"
fi
echo "" >> "$OUT"

# --- Quick stats ---
echo "## Codebase Stats" >> "$OUT"
echo "" >> "$OUT"

ROUTE_COUNT=$(find src/app/api -name "route.ts" 2>/dev/null | wc -l)
COMPONENT_COUNT=$(find src/components -name "*.tsx" 2>/dev/null | wc -l)
TEST_COUNT=$(find src/__tests__ -name "*.test.ts" -o -name "*.test.tsx" 2>/dev/null | wc -l)
echo "- API routes: ${ROUTE_COUNT}" >> "$OUT"
echo "- Components: ${COMPONENT_COUNT}" >> "$OUT"
echo "- Tests: ${TEST_COUNT}" >> "$OUT"

echo "" >> "$OUT"
echo "---" >> "$OUT"
echo "*For deep analysis or unknown-bug hunting, use \`/rlm-explore coachsync\`. This primer covers resume context only.*" >> "$OUT"

echo "Primer generated: ${OUT}"
