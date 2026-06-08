#!/usr/bin/env bash
#
# install_copilot.sh — deploy generic GitHub Copilot CLI config into ~/.copilot.
#
# Symlinks the repo's generic copilot-instructions.md + mcp-config.json into
# ~/.copilot (backing up any existing real files). Machine-local, non-public
# instruction files (e.g. work context) are NOT managed here — keep those in
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

log "done. Machine-local instructions stay in ~/.copilot/local (not managed here)."
