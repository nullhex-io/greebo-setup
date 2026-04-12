# Greebo Setup

Shareable Claude Code configuration. Hooks, settings, status line, memory system, and workflow patterns.

Full setup guide: [nullhex.io/guides/greebo](https://nullhex.io/guides/greebo)

## Quick Start

```bash
git clone <this-repo> ~/greebo-setup
cd ~/greebo-setup
./sync.sh --dry-run    # Preview changes
./sync.sh              # Apply
```

## Staying Updated

```bash
cd ~/greebo-setup
git pull && ./sync.sh
```

Or just check if you're behind:

```bash
./sync.sh --check
```

## What Gets Synced

| Category | Files | Location |
|----------|-------|----------|
| Hook scripts | auto-format, extract-memories, verify-before-commit, etc. | `~/.claude/hooks/` |
| GitNexus hooks | Code intelligence integration | `~/.claude/hooks/gitnexus/` |
| Memory hooks | Session start/end, pre-message context injection | `~/dev/memory/hooks/` |
| Status line | Token tracking (raw + effective cost) | `~/.claude/scripts/` |
| Settings | Hooks config, plugins, worktree, effort level | `~/.claude/settings.json` (merged) |

## What's NOT Synced (personal)

- `settings.local.json` - your personal overrides
- `settings.user.json` - MCP servers with auth tokens
- Memory files - your project memories
- API keys and tokens
- Project-specific CLAUDE.md files

## Templates

- `templates/CLAUDE.md` - Global workspace rules (copy to `~/dev/CLAUDE.md` and customize)
- `templates/settings.json` - Full settings reference (sync script merges this automatically)
- `templates/generate-primer.sh` - Session primer for any project (see below)

## Session Primer Pattern

Instead of running expensive codebase exploration at the start of every session, generate a compact resume document:

```bash
# Copy to your project
cp templates/generate-primer.sh ~/dev/your-project/scripts/
chmod +x ~/dev/your-project/scripts/generate-primer.sh

# Run it
cd ~/dev/your-project && ./scripts/generate-primer.sh

# Auto-regenerate on every commit
cat > .git/hooks/post-commit << 'EOF'
#!/usr/bin/env bash
REPO_ROOT=$(git rev-parse --show-toplevel)
SCRIPT="${REPO_ROOT}/scripts/generate-primer.sh"
[ -x "$SCRIPT" ] && "$SCRIPT" > /dev/null 2>&1 &
EOF
chmod +x .git/hooks/post-commit
```

Then add to your project's CLAUDE.md:
> Session start: Read `.planning/SESSION_PRIMER.md` first. Only run full exploration for audits.

## Options

```
./sync.sh              # Sync everything
./sync.sh --dry-run    # Preview without changing
./sync.sh --check      # Just check if behind
./sync.sh --hooks-only # Only sync hook scripts
```
