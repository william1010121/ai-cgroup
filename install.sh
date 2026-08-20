#!/usr/bin/env bash
# Install rbox: CLI symlink, global default config, and AI agent skills.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BIN_DIR="$HOME/.local/bin"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rbox"
CLAUDE_SKILL_DIR="$HOME/.claude/skills/rbox"
CODEX_AGENTS="$HOME/.codex/AGENTS.md"
MARKER="## Resource Sandbox (rbox)"

info() { printf '  %s\n' "$*"; }

echo "Installing rbox..."

# 1. CLI
mkdir -p "$BIN_DIR"
ln -sf "$REPO/bin/rbox" "$BIN_DIR/rbox"
info "CLI       -> $BIN_DIR/rbox"

# 2. Global fallback config (never clobber an existing one)
mkdir -p "$CFG_DIR"
if [[ -f "$CFG_DIR/default.toml" ]]; then
  info "config    -> $CFG_DIR/default.toml (kept existing)"
else
  cp "$REPO/templates/rbox.toml" "$CFG_DIR/default.toml"
  info "config    -> $CFG_DIR/default.toml"
fi

# 3. Claude skill
mkdir -p "$CLAUDE_SKILL_DIR"
cp "$REPO/skills/rbox/SKILL.md" "$CLAUDE_SKILL_DIR/SKILL.md"
info "claude    -> $CLAUDE_SKILL_DIR/SKILL.md"

# 4. Codex AGENTS.md - APPEND only, never overwrite (it holds personal instructions)
mkdir -p "$(dirname "$CODEX_AGENTS")"
touch "$CODEX_AGENTS"
if grep -qF "$MARKER" "$CODEX_AGENTS"; then
  info "codex     -> $CODEX_AGENTS (section already present, unchanged)"
else
  cp "$CODEX_AGENTS" "$CODEX_AGENTS.bak.$(date +%Y%m%d%H%M%S)"
  cat "$REPO/skills/codex-snippet.md" >> "$CODEX_AGENTS"
  info "codex     -> appended to $CODEX_AGENTS (backup saved)"
fi

echo
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "NOTE: $BIN_DIR is not on your PATH. Add it to your shell profile:"
     echo "      export PATH=\"\$HOME/.local/bin:\$PATH\"" ; echo ;;
esac

echo "Done. Next steps:"
echo "  rbox build      # build the sandbox image (first time, a few minutes)"
echo "  cd <project> && rbox init"
echo "  rbox npm test"
