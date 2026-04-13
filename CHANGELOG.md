# Greebo Setup Changelog

## v4 - 2026-04-13

Council-driven hardening + /craft skill.

Security:
- scan-secrets.sh: PreToolUse hook blocks git commit/push if staged files contain API keys, tokens, or PEM keys
- thinking_loop.sh: sanitize_external() strips prompt injection from X/Twitter feed, untrusted data markers added
- audit-destructive.sh: PreToolUse hook logs destructive commands (rm -rf, drop table, reset --hard, etc.) to audit trail

Observability:
- hook-logger.sh: PostToolUse hook writes structured JSON logs for all tool executions (14-day rotation)
- dep-audit.sh: weekly npm audit across all projects, Telegram alerts on HIGH+ CVEs

Resilience:
- dream-consolidation.sh: soft-delete (archive, don't delete), .archive/ dir with 30-day rotation
- backup-pa-system: pg_dump cortex added to backup tarball
- Two-agent review: use different model for reviewer to reduce correlated bias

New skill:
- /craft: turns vague intent into precise agent delegation prompts. Explores via GitNexus, recalls past patterns from Cortex, renders strict template, outputs to .planning/craft/

## v3 - 2026-04-12

- Removed plugin-managed hook scripts (now handled by plugins directly)

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
