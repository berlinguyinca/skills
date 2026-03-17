#!/usr/bin/env bash
set -euo pipefail

# Resolve repo dir: follow the symlink from ~/.claude/commands/gw, fall back to ~/.gw-skills
if [ -L "$HOME/.claude/commands/gw" ]; then
  REPO_DIR="$(cd "$(readlink "$HOME/.claude/commands/gw")/../.." && pwd)"
elif [ -d "$HOME/.gw-skills" ]; then
  REPO_DIR="$HOME/.gw-skills"
else
  exit 0  # can't find repo — skip silently
fi

cd "$REPO_DIR"

# Fetch silently, timeout after 3 seconds to avoid blocking
if ! git fetch --quiet 2>/dev/null & FETCH_PID=$! && { sleep 3; kill $FETCH_PID 2>/dev/null; } & wait $FETCH_PID 2>/dev/null; then
  exit 0  # network issue — skip silently
fi

LOCAL=$(git rev-parse HEAD 2>/dev/null)
REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "$LOCAL")

if [ "$LOCAL" != "$REMOTE" ]; then
  BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "?")
  echo "UPDATE_AVAILABLE=$BEHIND"
else
  echo "UP_TO_DATE"
fi
