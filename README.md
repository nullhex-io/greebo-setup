# Greebo Setup

Complete Claude Code configuration. Hooks, settings, memory system, token tracking, cron automation, Telegram bot, and workflow patterns.

Full setup guide: [nullhex.io/guides/greebo](https://nullhex.io/guides/greebo)

## Quick Start

```bash
git clone https://github.com/nullhex-io/greebo-setup.git ~/greebo-setup
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

## What's Included

### Auto-synced (via `./sync.sh`)

| Category | Files | Location |
|----------|-------|----------|
| Hook scripts | auto-format, extract-memories, verify-before-commit, suggest-rlm, etc. | `~/.claude/hooks/` |
| GitNexus hooks | Code intelligence integration | `~/.claude/hooks/gitnexus/` |
| Memory hooks | Session start/end, pre-message context injection | `~/dev/memory/hooks/` |
| Status line | Token tracking (raw + effective cost) | `~/.claude/scripts/` |
| Settings | Hooks config, plugins, worktree, effort level | `~/.claude/settings.json` (merged) |

### Manual setup (templates)

| Category | Files | What to do |
|----------|-------|------------|
| Global rules | `templates/CLAUDE.md` | Copy to `~/dev/CLAUDE.md`, customize |
| Bash additions | `templates/bashrc-additions.sh` | Append to `~/.bashrc` |
| tmux config | `templates/tmux.conf` | Copy to `~/.tmux.conf` |
| Telegram bot | `templates/claude-telegram.sh` + `templates/systemd/claude-telegram.service` | See Telegram section below |
| Cron jobs | `templates/cron/crontab.template` | `crontab -e` and add entries |
| Thinking loop secrets | `templates/thinking_loop.env.example` | Copy to `~/dev/memory/thinking_loop.env`, fill in |
| Session primer | `templates/generate-primer.sh` | Copy to each project's `scripts/` |

### Memory engine (copy to `~/dev/memory/engine/`)

| Script | Purpose | Cron |
|--------|---------|------|
| `engine/thinking_loop.sh` | Hourly briefing (git, health, Cortex, AI feed) | `0 * * * *` |
| `engine/lint-memories.sh` | Daily structural lint of memory files | `0 5 * * *` |
| `engine/dream-consolidation.sh` | Nightly memory synthesis and pruning | `0 3 * * *` |

### Analysis tools

| Script | Purpose |
|--------|---------|
| `scripts/token_analyzer.py` | Analyze token usage across all Claude Code sessions |

## What's NOT Synced (personal)

- `settings.local.json` - your personal overrides
- `settings.user.json` - MCP servers with auth tokens
- Memory files - your project memories
- API keys and tokens
- Project-specific CLAUDE.md files

## Setup Order

**Layer 0 - Core (5 min)**
1. `./sync.sh` - installs hooks, settings, statusline
2. Copy `templates/CLAUDE.md` to `~/dev/CLAUDE.md` and customize
3. Append `templates/bashrc-additions.sh` to `~/.bashrc`
4. Copy `templates/tmux.conf` to `~/.tmux.conf`

**Layer 1 - Cortex (canonical memory)**
5. Install PostgreSQL + pgvector
6. Create cortex database: `sudo -u postgres createdb cortex && sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS vector;" cortex`
7. Install Cortex plugin: `/install cortex@cortex-plugins` in a Claude session
8. Patch DATABASE_URL in the plugin config

**Layer 2 - GitNexus (code intelligence)**
9. `npm install -g gitnexus && gitnexus setup`
10. Index repos: `cd ~/dev/myapp && gitnexus analyze`

**Layer 3 - Memory Freshness**
11. Clone memory-freshness to `~/dev/memory-freshness`, run `bun install`
12. `sudo ln -s $(pwd)/mf.sh /usr/local/bin/mf`

**Memory engine**
13. Copy `engine/` scripts to `~/dev/memory/engine/`
14. Copy `templates/thinking_loop.env.example` to `~/dev/memory/thinking_loop.env` and fill in secrets
15. Add cron entries from `templates/cron/crontab.template`

**Optional**
16. Set up Telegram bot using templates in `templates/systemd/` and `templates/claude-telegram.sh`
17. Install community skills: `npx skills add sickn33/antigravity-awesome-skills --all`

## Session Primer Pattern

Instead of running expensive codebase exploration at the start of every session, generate a compact resume document:

```bash
cp templates/generate-primer.sh ~/dev/your-project/scripts/
chmod +x ~/dev/your-project/scripts/generate-primer.sh
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

Add to your project's CLAUDE.md:
> Session start: Read `.planning/SESSION_PRIMER.md` first. Only run full exploration for audits.

## Token Analyzer

See how much your sessions cost:

```bash
python3 scripts/token_analyzer.py                    # All time
SINCE_DAYS=7 python3 scripts/token_analyzer.py       # Last 7 days
SINCE_DATE=2026-04-01 python3 scripts/token_analyzer.py  # Since a date
```

## Options

```
./sync.sh              # Sync everything
./sync.sh --dry-run    # Preview without changing
./sync.sh --check      # Just check if behind
./sync.sh --hooks-only # Only sync hook scripts
```
