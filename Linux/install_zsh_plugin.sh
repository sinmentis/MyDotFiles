#!/usr/bin/env bash
#
# One-shot zsh setup.
#
# Running this script will:
#   1. Install zsh and fzf (via apt).
#   2. Install Oh My Zsh (unattended, keeps your existing .zshrc).
#   3. Install the Powerlevel10k theme.
#   4. Install zsh plugins: zsh-syntax-highlighting, zsh-autosuggestions,
#      zsh-history-substring-search.
#   5. Symlink .zshrc and .p10k.zsh from this repo into your $HOME
#      (any existing real files are backed up as *.bak.<timestamp>).
#   6. Set zsh as your default login shell (may prompt for your password).
#
# Safe to re-run: every step is idempotent.
#
# Usage:
#   ./install_zsh_plugin.sh
#
# After it finishes, open a new terminal to start using zsh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

# 1. Install zsh + fzf
sudo apt update
sudo apt install -y zsh fzf

# 2. Install Oh My Zsh (skip if already present; keep our .zshrc)
if [ ! -d "$ZSH_DIR" ]; then
    RUNZSH=no KEEP_ZSHRC=yes CHSH=no \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 3. Powerlevel10k theme
clone_if_missing() {
    local url="$1" dest="$2"
    if [ ! -d "$dest" ]; then
        git clone --depth=1 "$url" "$dest"
    fi
}

clone_if_missing https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k"

# 4. Zsh plugins (into custom/plugins so OMZ doesn't clobber them)
clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions.git \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_if_missing https://github.com/zsh-users/zsh-history-substring-search.git \
    "$ZSH_CUSTOM/plugins/zsh-history-substring-search"

# 5. Deploy dotfiles from repo as symlinks (back up any existing real files)
link_dotfile() {
    local src="$1" dest="$2"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "$dest.bak.$(date +%Y%m%d%H%M%S)"
    fi
    ln -sfn "$src" "$dest"
}

link_dotfile "$SCRIPT_DIR/.zshrc"    "$HOME/.zshrc"
link_dotfile "$SCRIPT_DIR/.p10k.zsh" "$HOME/.p10k.zsh"

# 6. Set zsh as default login shell
ZSH_BIN="$(command -v zsh)"
if [ "${SHELL:-}" != "$ZSH_BIN" ]; then
    chsh -s "$ZSH_BIN" "$USER"
fi

echo "Done. Start a new terminal to use zsh."
