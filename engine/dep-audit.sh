#!/usr/bin/env bash
# dep-audit.sh - Weekly dependency vulnerability scan
# Checks npm audit for all active projects, writes report, alerts on HIGH+
#
# Install: 0 6 * * 1 $HOME/dev/infra/memory/engine/dep-audit.sh >> /tmp/dep-audit.log 2>&1

set -uo pipefail

REPORT="$HOME/dev/infra/memory/dep-audit-report.md"

# Load env for Telegram alerting (optional)
ENV_FILE="$HOME/dev/infra/memory/thinking_loop.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

# Projects to audit (must have package.json)
PROJECTS=(
  coachsync
  coachsync-mobile
  snackes
  nullhex-redesign
  pa-mcp
  ebay-mcp
  x-mcp
)

NOW="$(date '+%Y-%m-%d %H:%M')"
TOTAL_HIGH=0
TOTAL_CRITICAL=0

{
echo "# Dependency Audit Report"
echo "Generated: $NOW"
echo ""

for project in "${PROJECTS[@]}"; do
  DIR="$HOME/dev/$project"
  [ -f "$DIR/package.json" ] || continue

  echo "## $project"

  # Run npm audit in JSON mode
  AUDIT_JSON=$(cd "$DIR" && npm audit --json 2>/dev/null || echo '{}')

  # Parse results
  SUMMARY=$(echo "$AUDIT_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    meta = data.get('metadata', {}).get('vulnerabilities', {})
    if not meta:
        # Try audit v2 format
        vulns = data.get('vulnerabilities', {})
        counts = {'critical': 0, 'high': 0, 'moderate': 0, 'low': 0}
        for v in vulns.values():
            sev = v.get('severity', 'low')
            counts[sev] = counts.get(sev, 0) + 1
        meta = counts
    c = meta.get('critical', 0)
    h = meta.get('high', 0)
    m = meta.get('moderate', 0)
    l = meta.get('low', 0)
    total = c + h + m + l
    print(f'critical={c} high={h} moderate={m} low={l} total={total}')
except:
    print('critical=0 high=0 moderate=0 low=0 total=0')
" 2>/dev/null)

  # Extract counts
  CRITICAL=$(echo "$SUMMARY" | grep -oP 'critical=\K[0-9]+')
  HIGH=$(echo "$SUMMARY" | grep -oP 'high=\K[0-9]+')
  MODERATE=$(echo "$SUMMARY" | grep -oP 'moderate=\K[0-9]+')
  LOW=$(echo "$SUMMARY" | grep -oP 'low=\K[0-9]+')
  TOTAL=$(echo "$SUMMARY" | grep -oP 'total=\K[0-9]+')

  TOTAL_HIGH=$((TOTAL_HIGH + HIGH))
  TOTAL_CRITICAL=$((TOTAL_CRITICAL + CRITICAL))

  if [ "$TOTAL" -eq 0 ]; then
    echo "No vulnerabilities found."
  else
    echo "| Severity | Count |"
    echo "|----------|-------|"
    [ "$CRITICAL" -gt 0 ] && echo "| CRITICAL | $CRITICAL |"
    [ "$HIGH" -gt 0 ] && echo "| HIGH | $HIGH |"
    [ "$MODERATE" -gt 0 ] && echo "| Moderate | $MODERATE |"
    [ "$LOW" -gt 0 ] && echo "| Low | $LOW |"
  fi
  echo ""
done

echo "---"
echo "**Totals**: $TOTAL_CRITICAL critical, $TOTAL_HIGH high across all projects"

} > "$REPORT"

echo "[$(date)] Dep audit: $TOTAL_CRITICAL critical, $TOTAL_HIGH high. Report at $REPORT"

# Alert via Telegram if critical or high vulns found
if [ $((TOTAL_CRITICAL + TOTAL_HIGH)) -gt 0 ] && [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
  MSG="Dep audit: $TOTAL_CRITICAL critical, $TOTAL_HIGH high vulnerabilities found. Check ~/dev/infra/memory/dep-audit-report.md"
  curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${MSG}" > /dev/null 2>&1 || true
fi
