#!/usr/bin/env bash
# Claude Code statusline with cumulative session token usage.
# Input: JSON on stdin with session_id, transcript_path, cwd, model, workspace, session_name, context_window.

set -euo pipefail

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
session_name=$(echo "$input" | jq -r '.session_name // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')

dir_name=$(basename "$cwd")

# Git branch (if any)
git_branch=""
if [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  [ -n "$git_branch" ] && git_branch=" ($git_branch)"
fi

# Session token totals from the transcript JSONL
tokens=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  tokens=$(python3 - "$transcript" <<'PY'
import json, sys
path = sys.argv[1]
fin = fcw = fcr = fout = 0
try:
    with open(path) as f:
        for line in f:
            try:
                obj = json.loads(line)
            except Exception:
                continue
            if obj.get("type") == "assistant":
                u = obj.get("message", {}).get("usage", {}) or {}
                fin += u.get("input_tokens", 0)
                fcw += u.get("cache_creation_input_tokens", 0)
                fcr += u.get("cache_read_input_tokens", 0)
                fout += u.get("output_tokens", 0)
except Exception:
    sys.exit(0)

raw = fin + fcw + fcr + fout
# Effective cost weights: input 1x, cache_write 1.25x, cache_read 0.1x, output 5x
eff = fin * 1.0 + fcw * 1.25 + fcr * 0.10 + fout * 5.0

def fmt(n):
    if n >= 1_000_000_000:
        return f"{n/1_000_000_000:.1f}B"
    if n >= 1_000_000:
        return f"{n/1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n/1_000:.0f}k"
    return str(int(n))

print(f"{fmt(raw)} raw / {fmt(eff)} eff")
PY
)
fi

# Assemble output
status="$dir_name$git_branch"
[ -n "$session_name" ] && status="$status | $session_name"
status="$status | $model"
[ -n "$remaining" ] && status="$status | Ctx: ${remaining}%"
[ -n "$tokens" ] && status="$status | $tokens"
echo "$status"
