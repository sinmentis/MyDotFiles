#!/usr/bin/env bash
#
# install_tmux.sh — install tmux and deploy .tmux.conf.
#
# Decoupled from auto-attach: this only installs tmux + the config. Whether a
# login shell drops you into tmux is controlled separately by the
# DOTFILES_TMUX_AUTOATTACH env var (set in ~/.zshrc.local), so a server can
# have tmux available without auto-attaching on every SSH login.
#
# Clipboard is handled by the outer terminal through OSC52.
#
# Idempotent. Invoked by ../install.sh, or standalone:
#   bash lib/install_tmux.sh

set -euo pipefail
export LOG_TAG="tmux"
DOTFILES_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=common.sh
source "$DOTFILES_LINUX_DIR/lib/common.sh"

# 1. Packages. Python runs the copilot-tmux snapshot helper installed below.
log "installing tmux + python3..."
apt_install tmux python3

# 2. Deploy config.
log "linking .tmux.conf..."
link_dotfile "$DOTFILES_LINUX_DIR/.tmux.conf" "$HOME/.tmux.conf"

# 3. Install local tmux utilities.
log "linking copilot-tmux..."
run mkdir -p "$HOME/.local/bin"
link_dotfile "$DOTFILES_LINUX_DIR/bin/copilot-tmux" \
             "$HOME/.local/bin/copilot-tmux"

log "done. Start tmux with 'tmux' or manage Copilot snapshots with 'copilot-tmux'."
