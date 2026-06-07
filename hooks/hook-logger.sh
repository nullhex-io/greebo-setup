#!/usr/bin/env bash
# hook-logger.sh - PostToolUse hook for all tools
# Logs structured JSON for every tool execution. Lightweight (no blocking).
# Log rotation: files per day, keep 14 days.

INPUT=$(cat)
LOG_DIR="$HOME/dev/infra/memory/hook-logs"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).jsonl"

# Extract fields from hook input
python3 -c "
import json, sys, time

try:
    data = json.loads('''$( echo "$INPUT" | sed "s/'/\\\\'/g" )''')
except:
    try:
        data = json.load(open('/dev/stdin'))
    except:
        sys.exit(0)

entry = {
    'ts': time.strftime('%Y-%m-%dT%H:%M:%S'),
    'tool': data.get('tool_name', 'unknown'),
    'session': data.get('session_id', '')[:12],
}

# Add relevant details based on tool type
tool_input = data.get('tool_input', {})
if data.get('tool_name') == 'Bash':
    cmd = tool_input.get('command', '')
    entry['command'] = cmd[:200]
elif data.get('tool_name') in ('Edit', 'Write'):
    entry['file'] = tool_input.get('file_path', '')
elif data.get('tool_name') in ('Grep', 'Glob'):
    entry['pattern'] = tool_input.get('pattern', '')[:100]

# Check for error in output
output = data.get('tool_output', {})
if isinstance(output, dict):
    entry['error'] = bool(output.get('stderr') or output.get('error'))
else:
    entry['error'] = False

print(json.dumps(entry))
" >> "$LOG_FILE" 2>/dev/null

# Rotate - keep 14 days
find "$LOG_DIR" -name "*.jsonl" -mtime +14 -delete 2>/dev/null

exit 0
