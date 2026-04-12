#!/bin/bash
# verify-before-commit.sh - PreToolUse hook on Bash
# Blocks `git commit` in TypeScript repos unless a typecheck/build/test
# command appears in recent transcript, preventing another b510c6a-class bug.
#
# Skips: docs/chore/ci/style commits, --amend, merges, [skip-verify] bypass.
# Added: 2026-04-12 after audits showed unverified commits shipping bugs.

INPUT=$(cat)

# Extract the bash command
CMD=$(echo "$INPUT" | node -e "
let d='';
process.stdin.on('data',c=>d+=c);
process.stdin.on('end',()=>{
  try{ process.stdout.write(JSON.parse(d).tool_input?.command||''); }
  catch{}
});
" 2>/dev/null)

# Only gate git commit commands
if [[ ! "$CMD" =~ git[[:space:]]+commit ]]; then exit 0; fi

# Skip amends, merges, no-verify (explicit bypass)
if [[ "$CMD" =~ --amend ]] || [[ "$CMD" =~ --no-verify ]]; then exit 0; fi

# Skip [skip-verify] escape hatch
if [[ "$CMD" =~ \[skip-verify\] ]]; then exit 0; fi

# Skip non-code commit types (docs, chore, ci, style)
if echo "$CMD" | grep -qP '(-m\s+["'"'"']\s*|<<.*EOF\n\s*)(docs|chore|ci|style)(\(.*?\))?:'; then exit 0; fi

# Find repo root - must be a TS project
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_ROOT" ] || [ ! -f "$PROJECT_ROOT/tsconfig.json" ]; then exit 0; fi

# Get transcript path from hook input
TRANSCRIPT=$(echo "$INPUT" | node -e "
let d='';
process.stdin.on('data',c=>d+=c);
process.stdin.on('end',()=>{
  try{ process.stdout.write(JSON.parse(d).transcript_path||''); }
  catch{}
});
" 2>/dev/null)

# If no transcript available, allow (fail open)
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then exit 0; fi

# Scan last 400 lines of transcript for verification evidence
# Matches: tsc, typecheck, build, test, vitest, jest, playwright, next build, expo build
if tail -400 "$TRANSCRIPT" | grep -qE '(tsc|typecheck|run build|run test|next build|expo build|vitest|jest|playwright)'; then
  exit 0
fi

# Block with actionable guidance
REASON="Verify-before-commit: no typecheck/build/test command found in recent transcript for this TypeScript repo ($PROJECT_ROOT). Run one of: pnpm tsc --noEmit, pnpm test, pnpm build - then retry the commit. Bypass: [skip-verify] in message, docs:/chore:/ci:/style: prefix, or --amend."

printf '{"decision":"block","reason":"%s"}\n' "$(echo "$REASON" | sed 's/"/\\"/g')"
exit 2
