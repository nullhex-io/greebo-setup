# Greebo Setup Changelog

## v2 - 2026-04-12

Full setup - everything from the guide.

- Memory engine: thinking_loop.sh (hourly briefing), lint-memories.sh (daily lint), dream-consolidation.sh (nightly synthesis)
- Token analyzer: scripts/token_analyzer.py for session cost analysis
- Telegram bot: launcher script + systemd service template
- Cron template: all recommended cron entries
- Bash additions: cs/css tmux functions, CLAUDE_CODE_NO_FLICKER
- tmux config template
- thinking_loop.env.example for secrets (tokens, URLs, API keys)
- Fixed hardcoded paths in gitnexus hook

## v1 - 2026-04-12

Initial release.

- Session primer pattern (generate-primer.sh + post-commit hook)
- Hook scripts: auto-format, extract-memories, push-notify, suggest-rlm, verify-before-commit
- GitNexus hook integration
- Memory hooks (pre_message, session_start, session_end, pre_compact)
- Statusline with token tracking (raw + effective cost)
- settings.json template with hooks, plugins, worktree config
- CLAUDE.md global rules template
