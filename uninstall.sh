#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="$HOME/.claude/commands/gw"

if [ -L "$TARGET_DIR" ]; then
  rm "$TARGET_DIR"
  echo "Removed symlink at $TARGET_DIR"
  echo "gw: skills uninstalled from Claude Code."
elif [ -d "$TARGET_DIR" ]; then
  echo "$TARGET_DIR exists but is not a symlink — not removing."
  echo "If you want to remove it manually: rm -rf $TARGET_DIR"
  exit 1
else
  echo "Nothing to uninstall — $TARGET_DIR does not exist."
fi
