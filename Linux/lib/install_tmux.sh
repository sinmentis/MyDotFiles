#!/usr/bin/env bash
#
# install_tmux.sh — install tmux and deploy .tmux.conf.
#
# Decoupled from auto-attach: this only installs tmux + the config. Whether a
# login shell drops you into tmux is controlled separately by the
# DOTFILES_TMUX_AUTOATTACH env var (set in ~/.zshrc.local), so a server can
# have tmux available without auto-attaching on every SSH login.
#
# Clipboard: .tmux.conf pipes copies to `xclip` (X11). On a headless server
# there's no X display, so that binding silently no-ops — harmless. For
# clipboard over SSH, use your terminal's own copy (most forward OSC52).
#
# Idempotent. Invoked by ../install.sh, or standalone:
#   bash lib/install_tmux.sh

set -euo pipefail
LOG_TAG="tmux"
DOTFILES_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_LINUX_DIR/lib/common.sh"

# 1. Packages. xclip only useful with an X display; install it anyway (tiny),
#    the binding degrades gracefully without $DISPLAY. Python runs the
#    copilot-tmux snapshot helper installed below.
log "installing tmux + xclip + python3..."
sudo apt update
apt_install tmux xclip python3

# 2. Deploy config.
log "linking .tmux.conf..."
link_dotfile "$DOTFILES_LINUX_DIR/.tmux.conf" "$HOME/.tmux.conf"

# 3. Install local tmux utilities.
log "linking copilot-tmux..."
mkdir -p "$HOME/.local/bin"
link_dotfile "$DOTFILES_LINUX_DIR/bin/copilot-tmux" \
             "$HOME/.local/bin/copilot-tmux"

if [ -z "${DISPLAY:-}" ]; then
    log "no \$DISPLAY detected (headless) — tmux clipboard via xclip will no-op."
fi

log "done. Start tmux with 'tmux' or manage Copilot snapshots with 'copilot-tmux'."
