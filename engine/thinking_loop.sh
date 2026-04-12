#!/usr/bin/env bash
# Thinking loop - runs hourly via cron
# Generates ~/dev/memory/briefing.md for SessionStart hook
set -uo pipefail
trap '' PIPE

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRIEFING="$HOME/dev/memory/briefing.md"
MEMORY_DIR="$HOME/.claude/projects/-home-$(whoami)-dev/memory"

# Load secrets from env file
ENV_FILE="$HOME/dev/memory/thinking_loop.env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# Configurable project directories (comma-separated in env, or set defaults)
# Override via PROJECT_DIRS in thinking_loop.env
IFS=',' read -ra PROJECT_DIR_LIST <<< "${PROJECT_DIRS:-}"

# Configurable site URLs (comma-separated in env)
# Override via SITE_URLS in thinking_loop.env
IFS=',' read -ra SITE_URL_LIST <<< "${SITE_URLS:-}"

# Tokens loaded from env file
VERCEL_TOKEN_PROD="${VERCEL_TOKEN:-}"
SUPABASE_TOKEN="${SUPABASE_TOKEN:-}"
SUPABASE_REF="${SUPABASE_REF:-}"

NOW="$(date '+%Y-%m-%d %H:%M UTC')"

{
echo "# Briefing"
echo "Generated: $NOW"
echo ""

# --- DAILY SUMMARY ---
echo "## Recent Activity"
echo ""

# Git activity (last 24h) - iterate configured project dirs
echo "### Git (last 24h)"
echo ""
for dir_name in "${PROJECT_DIR_LIST[@]}"; do
  dir_name="$(echo "$dir_name" | xargs)"  # trim whitespace
  DIR_PATH="$HOME/dev/$dir_name"
  if [ -d "$DIR_PATH/.git" ]; then
    COMMITS=$(cd "$DIR_PATH" && git log --oneline --since="24 hours ago" 2>/dev/null | head -10)
    if [ -n "$COMMITS" ]; then
      echo "**$dir_name:**"
      echo '```'
      echo "$COMMITS"
      echo '```'
    else
      echo "**$dir_name:** no commits in 24h"
    fi
    echo ""
  fi
done

# --- EXTERNAL CHECKS ---
echo "## System Health"
echo ""

# Site uptime checks - iterate configured URLs
echo "### Sites"
for url in "${SITE_URL_LIST[@]}"; do
  url="$(echo "$url" | xargs)"  # trim whitespace
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "FAIL")
  echo "- $url: $STATUS"
done
echo ""

# Vercel deploy status (skip if no token)
echo "### Vercel Deploys"
if [ -n "$VERCEL_TOKEN_PROD" ]; then
  DEPLOY_INFO=$(curl -s -H "Authorization: Bearer $VERCEL_TOKEN_PROD" \
    "https://api.vercel.com/v6/deployments?limit=2" 2>/dev/null)

  if [ -n "$DEPLOY_INFO" ]; then
    echo "$DEPLOY_INFO" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for d in data.get('deployments', [])[:2]:
        state = d.get('state', 'unknown')
        created = d.get('created', 0)
        from datetime import datetime
        ts = datetime.fromtimestamp(created/1000).strftime('%Y-%m-%d %H:%M')
        url = d.get('url', 'unknown')
        print(f'- {state} at {ts} - {url}')
except:
    print('- Could not parse deploy info')
" 2>/dev/null || echo "- Could not fetch deploy info"
  fi
else
  echo "- Skipped (no VERCEL_TOKEN configured)"
fi
echo ""

# Supabase health (skip if no token)
echo "### Supabase"
if [ -n "$SUPABASE_TOKEN" ] && [ -n "$SUPABASE_REF" ]; then
  SUPA_STATUS=$(curl -s -H "Authorization: Bearer $SUPABASE_TOKEN" -H "apikey: $SUPABASE_TOKEN" \
    "https://api.supabase.com/v1/projects/$SUPABASE_REF" 2>/dev/null)
  if [ -n "$SUPA_STATUS" ]; then
    echo "$SUPA_STATUS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, dict):
        status = data.get('status', 'unknown')
        name = data.get('name', 'unknown')
        region = data.get('region', 'unknown')
        print(f'- {name}: {status} ({region})')
    elif isinstance(data, list):
        for svc in data:
            name = svc.get('name', 'unknown')
            status = svc.get('status', 'unknown')
            print(f'- {name}: {status}')
    else:
        print(f'- Response: {str(data)[:200]}')
except:
    print('- Could not parse health info')
" 2>/dev/null || echo "- Could not fetch Supabase health"
  fi
else
  echo "- Skipped (no SUPABASE_TOKEN or SUPABASE_REF configured)"
fi
echo ""

# Telegram service
echo "### Services"
TG_STATUS=$(systemctl --user is-active claude-telegram 2>/dev/null || echo "inactive")
echo "- claude-telegram: $TG_STATUS"
echo ""

# --- MEMORY (CORTEX) ---
echo "## Memory Health (Cortex)"
echo ""

CORTEX_STATS=$(psql -h localhost -p 5432 -d cortex -t -A -c "
SELECT json_build_object(
  'total', (SELECT COUNT(*) FROM memories),
  'episodic', (SELECT COUNT(*) FROM memories WHERE store_type='episodic'),
  'semantic', (SELECT COUNT(*) FROM memories WHERE store_type='semantic'),
  'entities', (SELECT COUNT(*) FROM entities),
  'relationships', (SELECT COUNT(*) FROM relationships),
  'avg_heat', ROUND((SELECT AVG(heat) FROM memories)::numeric, 3),
  'protected', (SELECT COUNT(*) FROM memories WHERE is_protected=true),
  'stale', (SELECT COUNT(*) FROM memories WHERE is_stale=true),
  'has_vector', (SELECT COUNT(*) > 0 FROM memories WHERE embedding IS NOT NULL)
);" 2>/dev/null)

if [ -n "$CORTEX_STATS" ]; then
  echo '```'
  echo "$CORTEX_STATS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f\"Memories: {d['total']} ({d['episodic']} episodic, {d['semantic']} semantic)\")
print(f\"Entities: {d['entities']}, Relationships: {d['relationships']}\")
print(f\"Avg heat: {d['avg_heat']}, Protected: {d['protected']}, Stale: {d['stale']}\")
print(f\"Vector search: {'yes' if d['has_vector'] else 'no'}\")
" 2>/dev/null
  echo '```'
else
  echo '```'
  echo "Could not query Cortex database"
  echo '```'
fi
echo ""

# --- PROACTIVE SUGGESTIONS ---
echo "## Attention Needed"
echo ""

# Check Cortex for stale memories
STALE_COUNT=$(psql -h localhost -p 5432 -d cortex -t -A -c "SELECT COUNT(*) FROM memories WHERE is_stale=true;" 2>/dev/null || echo "0")
if [ "$STALE_COUNT" -gt 0 ]; then
  echo "- $STALE_COUNT stale memories in Cortex (run consolidation)"
fi

# Disk usage
DISK_USAGE=$(df -h "$HOME" | tail -1 | awk '{print $5}')
echo "- Disk usage: $DISK_USAGE"

# RAM
RAM_FREE=$(free -h | awk '/^Mem:/{print $4}')
echo "- RAM free: $RAM_FREE"

echo ""

# --- AI FEED (X/Twitter highlights) ---
echo "## AI Feed"
echo ""

# Two-pronged search: accounts we follow + topics we care about
# XAI_API_KEY can be set in thinking_loop.env
if [ -n "${XAI_API_KEY:-}" ]; then

  # Helper: run a Grok x_search query, extract text
  grok_search() {
    local query="$1"
    curl -s --max-time 45 "https://api.x.ai/v1/responses" \
      -H "Authorization: Bearer $XAI_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$(python3 -c "
import json
print(json.dumps({
    'model': 'grok-4-fast-non-reasoning',
    'stream': False,
    'input': [{'role': 'user', 'content': '''$query'''}],
    'tools': [{'type': 'x_search'}]
}))
")" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for item in data.get('output', []):
        if 'content' in item:
            for c in item['content']:
                if c.get('type') == 'output_text':
                    print(c['text'][:1500])
                    break
except:
    print('Could not fetch results')
" 2>/dev/null
  }

  # Search 1: Account-based - what are people we follow saying?
  # Customize these accounts in the query below
  echo "### Followed accounts"
  ACCOUNTS_FEED=$(grok_search "Search X for the most interesting posts from the last 24 hours by @claudeai @karpathy. Top 5 bullet points with account, brief summary, and link.") || ACCOUNTS_FEED="Could not fetch"
  echo "$ACCOUNTS_FEED"
  echo ""

  # Search 2: Topic-based - what's trending regardless of who posted?
  echo "### Trending topics"
  TOPICS_FEED=$(grok_search "Search X for the most interesting posts from the last 24 hours about: Claude Code plugins OR MCP servers OR AI agent memory OR AI coding tools OR knowledge graphs for code OR prompt engineering breakthroughs. Exclude basic tutorials. Only posts with real tools, repos, or novel techniques. Top 5 bullet points with account, summary, and link. Prioritize posts with GitHub links or technical depth.") || TOPICS_FEED="Could not fetch"
  echo "$TOPICS_FEED"
  echo ""

else
  echo "*AI feed not configured - set XAI_API_KEY in ~/dev/memory/thinking_loop.env*"
fi
echo ""

# --- MEMORY FRESHNESS ---
cat "$HOME/dev/memory/freshness-report.md" 2>/dev/null
echo ""

echo "---"
echo "*Next run: $(date -d '+1 hour' '+%Y-%m-%d %H:%M UTC' 2>/dev/null || echo 'in 1 hour')*"

} > "$BRIEFING"

echo "[$(date)] Briefing generated at $BRIEFING"
