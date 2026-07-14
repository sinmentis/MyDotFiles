#!/usr/bin/env bash
#
# install_copilot.sh — deploy generic GitHub Copilot CLI config into ~/.copilot.
#
# Symlinks the repo's generic copilot-instructions.md + mcp-config.json and
# user-level hooks/ into ~/.copilot, then installs the repository's versioned
# personal-skills plugin from its local marketplace. Machine-local instructions
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

log "installing personal Copilot plugin..."
if command -v copilot >/dev/null 2>&1; then
    if [ -L "$COPILOT_DIR/skills" ]; then
        legacy_target="$(readlink "$COPILOT_DIR/skills" 2>/dev/null || true)"
        case "$legacy_target" in
            "$DOTFILES_LINUX_DIR/copilot/skills"|"$DOTFILES_ROOT/skills")
                unlink "$COPILOT_DIR/skills"
                log "removed legacy ~/.copilot/skills symlink"
                ;;
        esac
    fi

    marketplace_listing="$(copilot plugin marketplace list 2>&1)"
    if grep -Fq "sinmentis-marketplace (Local: $DOTFILES_ROOT)" <<<"$marketplace_listing"; then
        copilot plugin marketplace update sinmentis-marketplace >/dev/null
    elif grep -Fq "sinmentis-marketplace (" <<<"$marketplace_listing"; then
        copilot plugin marketplace remove sinmentis-marketplace >/dev/null
        copilot plugin marketplace add "$DOTFILES_ROOT" >/dev/null
    else
        copilot plugin marketplace add "$DOTFILES_ROOT" >/dev/null
    fi
    copilot plugin install sinmentis-skills@sinmentis-marketplace >/dev/null
    log "installed sinmentis-skills@sinmentis-marketplace"
else
    warn "copilot is not installed; skipping personal plugin installation"
fi

log "linking Copilot hooks..."
link_dotfile "$DOTFILES_LINUX_DIR/copilot/hooks" \
             "$COPILOT_DIR/hooks"

log "applying WSL clipboard (/copy) fix if needed..."
bash "$DOTFILES_LINUX_DIR/lib/patch_copilot_clipboard.sh"

log "done. Restart Copilot CLI to load plugin and hook changes; machine-local instructions stay in ~/.copilot/local."
