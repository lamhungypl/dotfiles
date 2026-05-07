#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "=== dotAgents Setup ==="
echo "Source: $SCRIPT_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

# Ensure target directories exist
mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/hooks"

# Symlink skills (top-level + _company/ subfolder)
link_skills() {
  local dir="$1" label="$2"
  for skill in "$dir"/*/; do
    [ -d "$skill" ] || continue
    name=$(basename "$skill")
    [[ "$name" == _* ]] && continue  # skip _company dir itself
    target="$CLAUDE_DIR/skills/$name"

    if [ -L "$target" ]; then
      echo "  OK (symlink exists): $name"
    elif [ -d "$target" ]; then
      echo "  SKIP (local dir exists): $name — remove it manually to use the repo version"
    else
      ln -sfn "$skill" "$target"
      echo "  LINKED: $name $label"
    fi
  done
}

echo "--- Skills ---"
link_skills "$SCRIPT_DIR/skills" ""
if [ -d "$SCRIPT_DIR/skills/_company" ]; then
  echo "--- Skills (company) ---"
  link_skills "$SCRIPT_DIR/skills/_company" "(company)"
fi

# Symlink hooks
echo ""
echo "--- Hooks ---"
for hook in "$SCRIPT_DIR/hooks"/*; do
  [ -f "$hook" ] || continue
  name=$(basename "$hook")
  target="$CLAUDE_DIR/hooks/$name"

  if [ -L "$target" ]; then
    echo "  OK (symlink exists): $name"
  else
    [ -f "$target" ] && mv "$target" "$target.bak"
    ln -sfn "$hook" "$target"
    echo "  LINKED: $name"
  fi
done

# Symlink config files
echo ""
echo "--- Config ---"
for conf in "$SCRIPT_DIR/config"/*; do
  [ -f "$conf" ] || continue
  name=$(basename "$conf")
  target="$CLAUDE_DIR/$name"

  if [ -L "$target" ]; then
    echo "  OK (symlink exists): $name"
  else
    [ -f "$target" ] && mv "$target" "$target.bak"
    ln -sfn "$conf" "$target"
    echo "  LINKED: $name (backed up original to $name.bak)"
  fi
done

# Check credentials
echo ""
if [ ! -f "$SCRIPT_DIR/.env.local" ]; then
  echo "WARNING: $SCRIPT_DIR/.env.local not found"
  echo "  Copy .env.example to .env.local and fill in your credentials"
else
  echo "OK: .env.local found"
fi

echo ""
echo "Done! Restart Claude Code to pick up changes."
