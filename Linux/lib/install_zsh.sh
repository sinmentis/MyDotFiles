#!/usr/bin/env bash
#
# install_zsh.sh — zsh + Oh My Zsh + Powerlevel10k + plugins, and deploy the
# generic .zshrc / .p10k.zsh as symlinks.
#
# Fixes over the old install_zsh_plugin.sh:
#   - installs git explicitly (step 3 git-clones p10k/plugins; relying on it
#     being pre-installed made standalone runs fail).
#   - chsh failure no longer aborts the whole run (over-SSH/PAM can refuse);
#     prints a manual hint instead.
#   - only touches zsh files; .gitconfig/.tmux.conf are handled by their own
#     lib scripts so each concern can be re-run independently.
#
# Idempotent. Normally invoked by ../install.sh, but safe to run standalone:
#   bash lib/install_zsh.sh

set -euo pipefail
LOG_TAG="zsh"
DOTFILES_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_LINUX_DIR/lib/common.sh"

ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

# 1. Packages (git is required by the clones below).
log "installing zsh, git, fzf..."
sudo apt update
apt_install zsh git fzf

# 2. Oh My Zsh (unattended; keep our own .zshrc).
if [ ! -d "$ZSH_DIR" ]; then
    log "installing Oh My Zsh..."
    RUNZSH=no KEEP_ZSHRC=yes CHSH=no \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 3. Theme + plugins into $ZSH_CUSTOM.
log "installing powerlevel10k + plugins..."
clone_if_missing https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k"
clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions.git \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_if_missing https://github.com/zsh-users/zsh-history-substring-search.git \
    "$ZSH_CUSTOM/plugins/zsh-history-substring-search"

# 4. Deploy generic dotfiles. Machine-local secrets live in ~/.zshrc.local,
#    which the generic .zshrc sources at the top (see .zshrc.local.example).
log "linking .zshrc and .p10k.zsh..."
link_dotfile "$DOTFILES_LINUX_DIR/.zshrc"    "$HOME/.zshrc"
link_dotfile "$DOTFILES_LINUX_DIR/.p10k.zsh" "$HOME/.p10k.zsh"

# 5. Default login shell -> zsh. Don't abort the run if chsh is refused.
ZSH_BIN="$(command -v zsh)"
if [ "${SHELL:-}" != "$ZSH_BIN" ]; then
    if sudo chsh -s "$ZSH_BIN" "$USER"; then
        log "default shell set to $ZSH_BIN (re-login to take effect)"
    else
        warn "could not change login shell automatically. Run manually:"
        warn "  chsh -s $ZSH_BIN"
    fi
fi

log "done. Open a new terminal to use zsh."
