#!/usr/bin/env bash
#
# install_copilot.sh — deploy generic GitHub Copilot CLI config into ~/.copilot.
#
# Symlinks the repo's generic copilot-instructions.md + mcp-config.json,
# personal skills/, and user-level hooks/ into ~/.copilot (backing up any
# existing real files/dirs). Machine-local, non-public instruction files
# (e.g. work context) are NOT managed here — keep those in
# ~/.copilot/local/*.instructions.md and load them via the
# COPILOT_CUSTOM_INSTRUCTIONS_DIRS env var (see .zshenv / .zshrc.local).
#
# Idempotent. Invoked by ../install.sh, or standalone:
#   bash lib/install_copilot.sh

set -euo pipefail
LOG_TAG="copilot"
DOTFILES_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_LINUX_DIR/lib/common.sh"

COPILOT_DIR="$HOME/.copilot"
mkdir -p "$COPILOT_DIR"

log "linking copilot-instructions.md + mcp-config.json..."
link_dotfile "$DOTFILES_LINUX_DIR/copilot/copilot-instructions.md" \
             "$COPILOT_DIR/copilot-instructions.md"
link_dotfile "$DOTFILES_LINUX_DIR/copilot/mcp-config.json" \
             "$COPILOT_DIR/mcp-config.json"

log "linking personal skills..."
link_dotfile "$DOTFILES_LINUX_DIR/copilot/skills" \
             "$COPILOT_DIR/skills"

log "linking Copilot hooks..."
link_dotfile "$DOTFILES_LINUX_DIR/copilot/hooks" \
             "$COPILOT_DIR/hooks"

log "applying WSL clipboard (/copy) fix if needed..."
bash "$DOTFILES_LINUX_DIR/lib/patch_copilot_clipboard.sh"

log "done. Restart Copilot CLI to load hook changes; machine-local instructions stay in ~/.copilot/local."
