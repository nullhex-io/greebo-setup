#!/usr/bin/env bash
# Greebo bashrc additions
# Source this from ~/.bashrc or copy the functions you want:
#   source ~/dev/projects/greebo-setup/templates/bashrc-additions.sh

# Prevent Claude Code terminal flicker
export CLAUDE_CODE_NO_FLICKER=1

# cs - Claude Session launcher
# Creates or attaches to a named tmux session running Claude Code.
# Usage:
#   cs myproject           # Create/attach to session "myproject"
#   cs feature-x myapp     # Create session with worktree isolation for ~/dev/myapp
cs() {
  local name="${1:?Usage: cs <session-name> [project]}"
  local project="${2:-}"
  if tmux has-session -t "$name" 2>/dev/null; then
    tmux attach -d -t "$name"
  else
    if [ -n "$project" ] && [ -d "$HOME/dev/$project/.git" ]; then
      # Worktree mode: isolated git checkout for parallel feature work
      tmux new -s "$name" -c "$HOME/dev/$project" \
        "claude --dangerously-skip-permissions -n $name -w $name"
    else
      # Standard mode
      tmux new -s "$name" "claude --dangerously-skip-permissions -n $name"
    fi
  fi
}

# css - list all active Claude sessions
alias css='tmux list-sessions 2>/dev/null || echo "No sessions"'
