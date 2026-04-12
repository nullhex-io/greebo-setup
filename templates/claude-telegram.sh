#!/usr/bin/env bash
set -euo pipefail

SESSION="claude-telegram"
SOCKET="claude-telegram"
CLAUDE="$HOME/.local/bin/claude"

export PATH="/usr/local/bin:$HOME/.local/bin:$HOME/.bun/bin:$PATH"
export TERM="${TERM:-xterm-256color}"
export TELEGRAM_POLL=1

cleanup() {
  tmux -L "$SOCKET" kill-server 2>/dev/null || true
}
trap cleanup EXIT

tmux -L "$SOCKET" kill-server 2>/dev/null || true

tmux -L "$SOCKET" new-session -d -s "$SESSION" -x 200 -y 50 \
  "$CLAUDE --dangerously-skip-permissions --channels plugin:telegram@claude-plugins-official"

tmux -L "$SOCKET" set-hook -g pane-died "run-shell 'tmux -L $SOCKET wait-for -S pane-exit'"
tmux -L "$SOCKET" wait-for pane-exit

exit 1  # Triggers systemd restart
