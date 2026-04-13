#!/usr/bin/env bash
# scan-secrets.sh - PreToolUse hook on Bash
# Blocks git commit/push if staged files contain secrets.
# Uses pattern matching for common secret formats.

INPUT=$(cat)

CMD=$(echo "$INPUT" | node -e "
let d='';
process.stdin.on('data',c=>d+=c);
process.stdin.on('end',()=>{
  try{ process.stdout.write(JSON.parse(d).tool_input?.command||''); }
  catch{}
});
" 2>/dev/null)

# Only gate git commit and git push
if [[ ! "$CMD" =~ git[[:space:]]+(commit|push) ]]; then exit 0; fi

# Skip if not in a git repo
git rev-parse --show-toplevel > /dev/null 2>&1 || exit 0

# Scan staged files for secrets
STAGED=$(git diff --cached --name-only 2>/dev/null)
[ -z "$STAGED" ] && exit 0

# Secret patterns (high-entropy tokens, known prefixes)
PATTERNS=(
  'sk-or-v1-[a-f0-9]{64}'           # OpenRouter
  'sk-[a-zA-Z0-9]{48,}'             # OpenAI / Anthropic
  'ghp_[a-zA-Z0-9]{36}'             # GitHub PAT
  'ghu_[a-zA-Z0-9]{36}'             # GitHub user token
  'glpat-[a-zA-Z0-9\-]{20}'         # GitLab PAT
  'AKIA[0-9A-Z]{16}'                # AWS access key
  'xoxb-[0-9]{10,}-[a-zA-Z0-9]+'    # Slack bot token
  'xoxp-[0-9]{10,}-[a-zA-Z0-9]+'    # Slack user token
  'sbp_[a-f0-9]{40}'                # Supabase service key
  'eyJhbGciOi[A-Za-z0-9_-]{50,}'    # JWT (long base64)
  'AIza[0-9A-Za-z_-]{35}'           # Google API key
  'sq0[a-z]{3}-[A-Za-z0-9_-]{22}'   # Square
  'sk_live_[a-zA-Z0-9]{24,}'        # Stripe live key
  'rk_live_[a-zA-Z0-9]{24,}'        # Stripe restricted key
  'Bearer [a-zA-Z0-9_\-\.]{30,}'    # Bearer tokens in code
  'PRIVATE KEY-----'                 # PEM private keys
)

COMBINED=$(printf '%s|' "${PATTERNS[@]}")
COMBINED="${COMBINED%|}"

# Check staged content (not filenames)
HITS=$(git diff --cached -U0 2>/dev/null | grep -cP "$COMBINED" 2>/dev/null || echo "0")

if [ "$HITS" -gt 0 ]; then
  MATCHES=$(git diff --cached -U0 2>/dev/null | grep -P "$COMBINED" 2>/dev/null | head -3 | sed 's/.\{20\}$/[REDACTED]/')
  REASON="Secret scan: found $HITS potential secret(s) in staged files. Examples: $MATCHES. Remove secrets before committing. Bypass: [skip-secret-scan] in commit message."

  # Allow bypass
  if [[ "$CMD" =~ \[skip-secret-scan\] ]]; then exit 0; fi

  printf '{"decision":"block","reason":"%s"}\n' "$(echo "$REASON" | sed 's/"/\\"/g')"
  exit 2
fi

exit 0
