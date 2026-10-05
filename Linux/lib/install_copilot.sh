#!/usr/bin/env bash
#
# install_copilot.sh — deploy generic GitHub Copilot CLI config into ~/.copilot.
#
# Symlinks the repo's generic copilot-instructions.md + mcp-config.json and
# user-level hooks/ into ~/.copilot. Machine-local instructions
# (e.g. work context) are NOT managed here — keep those in
# ~/.copilot/local/*.instructions.md and load them via the
# COPILOT_CUSTOM_INSTRUCTIONS_DIRS env var (see .zshenv / .zshrc.local).
#
# Idempotent. Invoked by ../install.sh, or standalone:
#   bash lib/install_copilot.sh

set -euo pipefail
LOG_TAG="copilot"
DOTFILES_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_ROOT="$(cd "$DOTFILES_LINUX_DIR/.." && pwd)"
source "$DOTFILES_LINUX_DIR/lib/common.sh"

COPILOT_DIR="$HOME/.copilot"
mkdir -p "$COPILOT_DIR"

log "linking copilot-instructions.md + mcp-config.json..."
link_dotfile "$DOTFILES_LINUX_DIR/copilot/copilot-instructions.md" \
             "$COPILOT_DIR/copilot-instructions.md"
if [ -e "$COPILOT_DIR/mcp-config.json" ] && [ ! -L "$COPILOT_DIR/mcp-config.json" ]; then
    warn "preserving existing ~/.copilot/mcp-config.json; repo config remains available at Linux/copilot/mcp-config.json"
else
    link_dotfile "$DOTFILES_LINUX_DIR/copilot/mcp-config.json" \
                 "$COPILOT_DIR/mcp-config.json"
fi

log "linking Copilot hooks..."
link_dotfile "$DOTFILES_LINUX_DIR/copilot/hooks" \
             "$COPILOT_DIR/hooks"

log "applying WSL clipboard (/copy) fix if needed..."
bash "$DOTFILES_LINUX_DIR/lib/patch_copilot_clipboard.sh"

log "done. Restart Copilot CLI to load hook changes; machine-local instructions stay in ~/.copilot/local."
