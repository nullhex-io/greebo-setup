#!/usr/bin/env bash
# audit-destructive.sh - PreToolUse hook on Bash
# Logs destructive commands to a dedicated audit file. Does NOT block - just records.
# Catches: rm, drop, delete, truncate, reset --hard, push --force, etc.

INPUT=$(cat)

CMD=$(echo "$INPUT" | node -e "
let d='';
process.stdin.on('data',c=>d+=c);
process.stdin.on('end',()=>{
  try{ process.stdout.write(JSON.parse(d).tool_input?.command||''); }
  catch{}
});
" 2>/dev/null)

[ -z "$CMD" ] && exit 0

# Check for destructive patterns
if echo "$CMD" | grep -qP '(rm\s+-rf|rm\s+-r|rmdir|drop\s+table|drop\s+database|truncate\s+table|git\s+reset\s+--hard|git\s+push\s+--force|git\s+push\s+-f|git\s+clean\s+-f|systemctl\s+stop|kill\s+-9|pkill|docker\s+rm|docker\s+system\s+prune)'; then
  LOG_DIR="$HOME/dev/infra/memory/hook-logs"
  AUDIT_FILE="$LOG_DIR/destructive-audit.jsonl"
  mkdir -p "$LOG_DIR"

  SESSION_ID=$(echo "$INPUT" | node -e "
  let d='';
  process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    try{ process.stdout.write(JSON.parse(d).session_id?.slice(0,12)||''); }
    catch{}
  });
  " 2>/dev/null)

  echo "{\"ts\":\"$(date -Iseconds)\",\"session\":\"$SESSION_ID\",\"command\":\"$(echo "$CMD" | head -c 500 | sed 's/"/\\"/g')\"}" >> "$AUDIT_FILE"
fi

exit 0
