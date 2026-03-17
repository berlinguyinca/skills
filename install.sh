#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$REPO_DIR/.claude/commands/gw"
TARGET_DIR="$HOME/.claude/commands/gw"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: skill source directory not found at $SOURCE_DIR"
  exit 1
fi

# If target exists and is a symlink, remove it so we can re-link
if [ -L "$TARGET_DIR" ]; then
  rm "$TARGET_DIR"
elif [ -d "$TARGET_DIR" ]; then
  echo "Warning: $TARGET_DIR already exists and is not a symlink."
  echo "Backing up to ${TARGET_DIR}.bak and replacing with symlink."
  mv "$TARGET_DIR" "${TARGET_DIR}.bak"
fi

mkdir -p "$(dirname "$TARGET_DIR")"
ln -s "$SOURCE_DIR" "$TARGET_DIR"

SKILL_COUNT=$(find "$SOURCE_DIR" -name '*.md' | wc -l | tr -d ' ')
echo "Installed $SKILL_COUNT gw: skill(s) -> $TARGET_DIR"
echo "Skills are now available as /gw:<name> in Claude Code."
