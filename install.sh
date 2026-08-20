#!/usr/bin/env bash
# ai-cgroup one-line installer.
#   curl -fsSL https://raw.githubusercontent.com/william1010121/ai-cgroup/master/install.sh | bash
set -euo pipefail

REPO_URL="https://github.com/william1010121/ai-cgroup.git"
INSTALL_DIR="${AI_CGROUP_HOME:-$HOME/.ai-cgroup}"
BIN_DIR="$HOME/.local/bin"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rbox"
CLAUDE_SKILL_DIR="$HOME/.claude/skills/rbox"
CODEX_AGENTS="$HOME/.codex/AGENTS.md"
MARKER="## Resource Sandbox (rbox)"

bold=$'\033[1m'; red=$'\033[31m'; grn=$'\033[32m'; ylw=$'\033[33m'; rst=$'\033[0m'
ok()   { printf '  %s✓%s %s\n' "$grn" "$rst" "$*"; }
warn() { printf '  %s!%s %s\n' "$ylw" "$rst" "$*"; }
step() { printf '\n%s%s%s\n' "$bold" "$*" "$rst"; }
die()  { printf '\n%serror:%s %s\n\n' "$red" "$rst" "$*" >&2; exit 1; }

printf '\n%sai-cgroup%s — CPU/RAM caps for AI coding agents on macOS\n' "$bold" "$rst"

# ---------- 1. preflight ----------
step "Checking prerequisites"

[[ "$(uname -s)" == "Darwin" ]] || die "macOS only (this tool exists because macOS lacks cgroups)."
ok "macOS $(sw_vers -productVersion) ($(uname -m))"

command -v git >/dev/null 2>&1 || die "git not found. Install Xcode command line tools: xcode-select --install"
ok "git"

# OrbStack: detect, guide, never auto-install.
if ! command -v orb >/dev/null 2>&1 && [[ ! -d /Applications/OrbStack.app ]]; then
  cat >&2 <<EOF

${red}OrbStack is required but not installed.${rst}

ai-cgroup needs a Linux kernel to provide cgroups, which macOS does not have.
OrbStack supplies that with a lightweight VM.

Install it, then re-run this script:

    ${bold}brew install orbstack${rst}

or download from https://orbstack.dev

EOF
  exit 1
fi
ok "OrbStack installed"

# Point docker at OrbStack's socket explicitly. Relying on the docker context
# alone is fragile (it lives in $HOME/.docker and may not be the active one).
ORB_SOCK="$HOME/.orbstack/run/docker.sock"
[[ -S "$ORB_SOCK" ]] && export DOCKER_HOST="unix://$ORB_SOCK"

if ! docker info >/dev/null 2>&1; then
  warn "OrbStack not running — starting it..."
  orb start >/dev/null 2>&1 || true
  for _ in $(seq 1 30); do
    [[ -S "$ORB_SOCK" ]] && export DOCKER_HOST="unix://$ORB_SOCK"
    docker info >/dev/null 2>&1 && break
    sleep 1
  done
  docker info >/dev/null 2>&1 || die "Could not start OrbStack. Start it manually ('orb start') and re-run."
fi
ok "OrbStack running ($(docker info --format '{{.NCPU}} cpu / {{printf "%.0f" (divf .MemTotal 1073741824)}}GB VM' 2>/dev/null || echo 'ready'))"

# ---------- 2. fetch ----------
step "Fetching ai-cgroup"
if [[ -d "$INSTALL_DIR/.git" ]]; then
  git -C "$INSTALL_DIR" pull --quiet --ff-only 2>/dev/null || warn "could not update, using existing copy"
  ok "updated $INSTALL_DIR"
else
  # Running from inside a clone? Use it. Otherwise clone.
  SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P || echo '')"
  if [[ -n "$SELF_DIR" && -f "$SELF_DIR/bin/rbox" ]]; then
    INSTALL_DIR="$SELF_DIR"
    ok "using local checkout $INSTALL_DIR"
  else
    git clone --quiet --depth 1 "$REPO_URL" "$INSTALL_DIR" || die "clone failed"
    ok "cloned to $INSTALL_DIR"
  fi
fi

# ---------- 3. CLI ----------
step "Installing CLI"
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/bin/rbox" "$BIN_DIR/rbox"
ok "rbox -> $BIN_DIR/rbox"

mkdir -p "$CFG_DIR"
if [[ -f "$CFG_DIR/default.toml" ]]; then
  ok "config kept: $CFG_DIR/default.toml"
else
  cp "$INSTALL_DIR/templates/rbox.toml" "$CFG_DIR/default.toml"
  ok "config: $CFG_DIR/default.toml (4 cpu / 6g default)"
fi

# ---------- 4. agent skills ----------
step "Configuring AI agents"

mkdir -p "$CLAUDE_SKILL_DIR"
cp "$INSTALL_DIR/skills/rbox/SKILL.md" "$CLAUDE_SKILL_DIR/SKILL.md"
ok "Claude Code skill: $CLAUDE_SKILL_DIR/SKILL.md"

mkdir -p "$(dirname "$CODEX_AGENTS")"
touch "$CODEX_AGENTS"
if grep -qF "$MARKER" "$CODEX_AGENTS"; then
  ok "Codex AGENTS.md already configured (unchanged)"
else
  cp "$CODEX_AGENTS" "$CODEX_AGENTS.bak.$(date +%Y%m%d%H%M%S)"
  cat "$INSTALL_DIR/skills/codex-snippet.md" >> "$CODEX_AGENTS"
  ok "Codex: appended to AGENTS.md (existing content preserved + backed up)"
fi

# ---------- 5. image ----------
step "Building sandbox image"
if docker image inspect rbox:local >/dev/null 2>&1; then
  ok "rbox:local already built"
else
  printf '  building (first time only, a few minutes)...\n'
  docker build -q -t rbox:local "$INSTALL_DIR" >/dev/null || die "image build failed"
  ok "rbox:local built"
fi

# ---------- 6. done ----------
step "Done"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR is not on your PATH. Add to ~/.zshrc:"
     printf '      export PATH="$HOME/.local/bin:$PATH"\n' ;;
esac

cat <<EOF

  Get started:

    cd your-project
    rbox init            # create .rbox.toml
    rbox npm run build   # runs capped at 4 cpu / 6GB

  Your AI agents now know to use it automatically.

EOF
