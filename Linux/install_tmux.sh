#!/usr/bin/env bash
#
# One-shot tmux setup.
#
# Running this script will:
#   1. Install tmux and xclip (xclip is used by the "copy to system clipboard"
#      binding in .tmux.conf).
#   2. Symlink .tmux.conf from this repo into your $HOME
#      (any existing real file is backed up as *.bak.<timestamp>).
#
# This script does NOT auto-start tmux. zsh integration lives in .zshrc via
# the Oh My Zsh `tmux` plugin. Escape hatches:
#   - export NO_TMUX=1           disable auto-attach for this shell
#   - already inside tmux        never nests
#   - VS Code integrated term    auto-disabled (keeps AI agents out of tmux)
#
# Safe to re-run: every step is idempotent.
#
# Usage:
#   ./install_tmux.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Install tmux + xclip
sudo apt update
sudo apt install -y tmux xclip

# 2. Deploy .tmux.conf as a symlink (back up any existing real file)
link_dotfile() {
    local src="$1" dest="$2"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "$dest.bak.$(date +%Y%m%d%H%M%S)"
    fi
    ln -sfn "$src" "$dest"
}

link_dotfile "$SCRIPT_DIR/.tmux.conf" "$HOME/.tmux.conf"

echo "Done. Open a new terminal (or run 'tmux') to start using tmux."
