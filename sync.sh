#!/usr/bin/env bash
# Greebo Setup Sync
# Syncs shareable Claude Code config from this repo to your local setup.
# Safe to run repeatedly - only overwrites shared files, never touches personal config.
#
# Usage:
#   git pull && ./sync.sh          # Update everything
#   ./sync.sh --dry-run            # Show what would change without changing anything
#   ./sync.sh --hooks-only         # Only sync hook scripts
#   ./sync.sh --check              # Just check if you're behind

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SCRIPTS_DIR="$CLAUDE_DIR/scripts"

DRY_RUN=false
HOOKS_ONLY=false
CHECK_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --hooks-only) HOOKS_ONLY=true ;;
        --check) CHECK_ONLY=true ;;
    esac
done

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

changed=0
skipped=0

sync_file() {
    local src="$1"
    local dst="$2"
    local label="$3"

    if [ ! -f "$dst" ]; then
        changed=$((changed + 1))
        if $DRY_RUN || $CHECK_ONLY; then
            echo -e "  ${GREEN}[NEW]${NC} $label"
        else
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
            chmod +x "$dst" 2>/dev/null || true
            echo -e "  ${GREEN}[NEW]${NC} $label"
        fi
    elif ! diff -q "$src" "$dst" > /dev/null 2>&1; then
        changed=$((changed + 1))
        if $DRY_RUN || $CHECK_ONLY; then
            echo -e "  ${YELLOW}[UPD]${NC} $label"
        else
            cp "$src" "$dst"
            chmod +x "$dst" 2>/dev/null || true
            echo -e "  ${YELLOW}[UPD]${NC} $label"
        fi
    fi
}

echo ""
echo "Greebo Setup Sync v$(cat "$REPO_DIR/VERSION")"
echo "=============================="

if $CHECK_ONLY; then
    echo "Checking for updates..."
    echo ""
fi

# --- Hook scripts ---
echo ""
echo "Hook scripts ($HOOKS_DIR/):"

for f in "$REPO_DIR"/hooks/*.sh "$REPO_DIR"/hooks/*.js; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    sync_file "$f" "$HOOKS_DIR/$name" "$name"
done

# GitNexus hooks
for f in "$REPO_DIR"/hooks/gitnexus/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    sync_file "$f" "$HOOKS_DIR/gitnexus/$name" "gitnexus/$name"
done

# Memory hooks
echo ""
echo "Memory hooks:"

MEMORY_HOOKS_DIR="$HOME/dev/infra/memory/hooks"
if [ -d "$MEMORY_HOOKS_DIR" ] || ! $CHECK_ONLY; then
    for f in "$REPO_DIR"/hooks/memory/*.sh; do
        [ -f "$f" ] || continue
        name=$(basename "$f")
        sync_file "$f" "$MEMORY_HOOKS_DIR/$name" "memory/$name"
    done
else
    echo "  (skipped - $MEMORY_HOOKS_DIR doesn't exist yet)"
    skipped=$((skipped + 1))
fi

if $HOOKS_ONLY; then
    echo ""
    echo "Hooks-only mode. Skipping settings and templates."
    echo "Changed: $changed | Skipped: $skipped"
    exit 0
fi

# --- Scripts ---
echo ""
echo "Scripts ($SCRIPTS_DIR/):"

for f in "$REPO_DIR"/scripts/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    sync_file "$f" "$SCRIPTS_DIR/$name" "$name"
done

# --- Settings merge ---
echo ""
echo "Settings:"

SETTINGS_SRC="$REPO_DIR/templates/settings.json"
SETTINGS_DST="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS_DST" ]; then
    if $DRY_RUN || $CHECK_ONLY; then
        # Show what keys would be added/updated
        DIFF=$(python3 -c "
import json, sys

with open('$SETTINGS_SRC') as f:
    src = json.load(f)
with open('$SETTINGS_DST') as f:
    dst = json.load(f)

# Check top-level keys
added = [k for k in src if k not in dst]
# Check hooks (the main thing that changes)
src_hooks = set()
dst_hooks = set()
for event, matchers in src.get('hooks', {}).items():
    for m in matchers:
        for h in m.get('hooks', []):
            src_hooks.add(h.get('command', '')[:60])
for event, matchers in dst.get('hooks', {}).items():
    for m in matchers:
        for h in m.get('hooks', []):
            dst_hooks.add(h.get('command', '')[:60])
new_hooks = src_hooks - dst_hooks

# Check plugins
src_plugins = set(src.get('enabledPlugins', {}).keys())
dst_plugins = set(dst.get('enabledPlugins', {}).keys())
new_plugins = src_plugins - dst_plugins

if added:
    print(f'  New top-level keys: {added}')
if new_hooks:
    for h in sorted(new_hooks):
        print(f'  New hook: {h}')
if new_plugins:
    for p in sorted(new_plugins):
        print(f'  New plugin: {p}')
if not added and not new_hooks and not new_plugins:
    print('  Up to date')
" 2>&1)
        echo "$DIFF"
    else
        # Merge: add new hooks and plugins without removing existing ones
        python3 -c "
import json

with open('$SETTINGS_SRC') as f:
    src = json.load(f)
with open('$SETTINGS_DST') as f:
    dst = json.load(f)

# Replace \$HOME with actual home dir in source
import os
home = os.path.expanduser('~')
def fix_paths(obj):
    if isinstance(obj, str):
        return obj.replace('\$HOME', home)
    if isinstance(obj, dict):
        return {k: fix_paths(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [fix_paths(i) for i in obj]
    return obj

src = fix_paths(src)

# Merge hooks: replace entire hooks config (canonical from repo)
if 'hooks' in src:
    dst['hooks'] = src['hooks']

# Merge plugins: add new ones, don't remove existing
for plugin, enabled in src.get('enabledPlugins', {}).items():
    if plugin not in dst.get('enabledPlugins', {}):
        dst.setdefault('enabledPlugins', {})[plugin] = enabled

# Merge simple keys (only add, don't overwrite existing)
for key in ['worktree', 'statusLine', 'effortLevel', 'enableAllProjectMcpServers']:
    if key in src and key not in dst:
        dst[key] = src[key]

# Always update statusLine (it's a shared script)
if 'statusLine' in src:
    dst['statusLine'] = src['statusLine']

with open('$SETTINGS_DST', 'w') as f:
    json.dump(dst, f, indent=2)
    f.write('\n')

print('  Settings merged')
" 2>&1
        changed=$((changed + 1))
    fi
else
    if ! $DRY_RUN && ! $CHECK_ONLY; then
        # First time - copy template and replace $HOME
        python3 -c "
import json, os
with open('$SETTINGS_SRC') as f:
    d = json.load(f)
home = os.path.expanduser('~')
def fix_paths(obj):
    if isinstance(obj, str):
        return obj.replace('\$HOME', home)
    if isinstance(obj, dict):
        return {k: fix_paths(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [fix_paths(i) for i in obj]
    return obj
d = fix_paths(d)
with open('$SETTINGS_DST', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
print('  Settings created from template')
"
        changed=$((changed + 1))
    else
        echo -e "  ${GREEN}[NEW]${NC} settings.json (will create from template)"
        changed=$((changed + 1))
    fi
fi

# --- CLAUDE.md template ---
echo ""
echo "CLAUDE.md template:"

CLAUDE_TEMPLATE="$REPO_DIR/templates/CLAUDE.md"
# We don't overwrite project CLAUDE.md files - just show if the template is newer
echo "  Available at: $CLAUDE_TEMPLATE"
echo "  Copy to your workspace ~/dev/CLAUDE.md and customize (brand names, personal rules)"

# --- Summary ---
echo ""
echo "=============================="
if $CHECK_ONLY; then
    if [ "$changed" -gt 0 ]; then
        echo -e "${YELLOW}$changed updates available.${NC} Run: git pull && ./sync.sh"
    else
        echo -e "${GREEN}Everything up to date.${NC}"
    fi
elif $DRY_RUN; then
    echo -e "Dry run complete. ${YELLOW}$changed files would change.${NC} Run without --dry-run to apply."
else
    echo -e "${GREEN}Sync complete.${NC} Changed: $changed | Skipped: $skipped"
    if [ "$changed" -gt 0 ]; then
        echo ""
        echo "Restart any running Claude Code sessions to pick up hook changes."
    fi
fi
echo ""
