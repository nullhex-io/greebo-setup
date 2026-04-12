#!/usr/bin/env bash
# suggest-rlm.sh - Suggests /rlm-explore for exploration-style prompts.
# Called by UserPromptSubmit hook. Reads prompt from stdin (JSON).
# Prints suggestion to stdout only when prompt matches exploration patterns.
# Silent (no output) otherwise.

set -euo pipefail

# Read the hook input from stdin
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('prompt', ''))
except:
    print('')
" 2>/dev/null)

# Lowercase for matching
LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Skip short prompts (< 20 chars) - unlikely to be exploration tasks
if [ ${#LOWER} -lt 20 ]; then
    exit 0
fi

# Skip if already invoking rlm-explore
if echo "$LOWER" | grep -q '/rlm-explore'; then
    exit 0
fi

# Negative patterns - implementation tasks, not exploration
if echo "$LOWER" | grep -qE '(^fix |^add |^create |^build |^implement |^refactor |^update |^remove |^delete |^deploy |^commit |^push |^merge )'; then
    exit 0
fi

# Exploration action words
ACTION_MATCH=0
if echo "$LOWER" | grep -qE '(find all|audit |review all|analyze |explore |investigate |trace |check every|search for all|list all|map out|understand how)'; then
    ACTION_MATCH=1
fi

# Scope indicators
SCOPE_MATCH=0
if echo "$LOWER" | grep -qE '(across|codebase|everywhere|all files|end.to.end|all routes|all api|all the|every file|the whole|entire)'; then
    SCOPE_MATCH=1
fi

# Question patterns about flows/architecture
QUESTION_MATCH=0
if echo "$LOWER" | grep -qE '(how does .* work|what calls |where is .* used|what depends on|what touches|what connects)'; then
    QUESTION_MATCH=1
fi

# Need at least one strong signal, or action + scope together
if [ $ACTION_MATCH -eq 1 ] && [ $SCOPE_MATCH -eq 1 ]; then
    echo "This looks like a deep exploration task. Consider /rlm-explore for recursive analysis (less context bloat, better coverage)."
elif [ $QUESTION_MATCH -eq 1 ] && [ $SCOPE_MATCH -eq 1 ]; then
    echo "This looks like a flow-tracing question. Consider /rlm-explore for recursive analysis (keeps main context lean)."
fi

exit 0
