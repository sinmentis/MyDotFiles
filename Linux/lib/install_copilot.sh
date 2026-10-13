#!/usr/bin/env bash
#
# install_copilot.sh — deploy generic GitHub Copilot CLI config into ~/.copilot.
#
# Symlinks the repo's generic copilot-instructions.md + mcp-config.json and
# user-level hooks/ and extensions into ~/.copilot. Machine-local instructions
# (e.g. work context) are NOT managed here — keep those in
# ~/.copilot/instructions/*.instructions.md, which Copilot CLI loads as
# user-level instructions automatically.
#
# Idempotent. Invoked by ../install.sh, or standalone:
#   bash lib/install_copilot.sh

set -euo pipefail
export LOG_TAG="copilot"
DOTFILES_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_ROOT="$(cd "$DOTFILES_LINUX_DIR/.." && pwd)"
# shellcheck source=common.sh
source "$DOTFILES_LINUX_DIR/lib/common.sh"

COPILOT_DIR="$HOME/.copilot"
run mkdir -p "$COPILOT_DIR/instructions"
run mkdir -p "$HOME/.local/bin"

log "linking Copilot helper commands..."
link_dotfile "$DOTFILES_LINUX_DIR/bin/copilot-tmux" \
             "$HOME/.local/bin/copilot-tmux"
link_dotfile "$DOTFILES_LINUX_DIR/bin/playwright-mcp" \
             "$HOME/.local/bin/playwright-mcp"

log "linking copilot-instructions.md + mcp-config.json..."
link_dotfile "$DOTFILES_ROOT/Shared/copilot/copilot-instructions.md" \
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

log "linking animated tmux status extension..."
link_dotfile "$DOTFILES_LINUX_DIR/copilot/extensions/tmux-status" \
             "$COPILOT_DIR/extensions/tmux-status"

log "done. Restart Copilot CLI to load hooks and extensions; machine-local instructions stay in ~/.copilot/instructions."
