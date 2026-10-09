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
export LOG_TAG="zsh"
DOTFILES_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=common.sh
source "$DOTFILES_LINUX_DIR/lib/common.sh"

ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

OH_MY_ZSH_COMMIT=9f9b28a13df35af968f0117cb142f0eba9cc6c41
POWERLEVEL10K_COMMIT=d05a1b00f9a61f9578bf9dc19b8451942dde8734
ZSH_SYNTAX_HIGHLIGHTING_COMMIT=0bfcb582e71d3abe604ce67bc0fe5a21f377507e
ZSH_AUTOSUGGESTIONS_COMMIT=85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5
ZSH_HISTORY_SUBSTRING_SEARCH_COMMIT=a0bdb0d47dbaba31dba2db7af8c48a5d9c74049a

# 1. Packages (git is required by the clones below; curl + ca-certificates by
#    GitHub clones, which may be absent on a minimal fresh image).
log "installing zsh, git, fzf, curl..."
apt_install zsh git fzf curl ca-certificates

# 2. Oh My Zsh. Clone directly rather than executing a moving remote installer.
log "installing Oh My Zsh..."
clone_at_commit https://github.com/ohmyzsh/ohmyzsh.git \
    "$ZSH_DIR" "$OH_MY_ZSH_COMMIT"

# 3. Theme + plugins into $ZSH_CUSTOM.
log "installing powerlevel10k + plugins..."
clone_at_commit https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k" "$POWERLEVEL10K_COMMIT"
clone_at_commit https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" "$ZSH_SYNTAX_HIGHLIGHTING_COMMIT"
clone_at_commit https://github.com/zsh-users/zsh-autosuggestions.git \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions" "$ZSH_AUTOSUGGESTIONS_COMMIT"
clone_at_commit https://github.com/zsh-users/zsh-history-substring-search.git \
    "$ZSH_CUSTOM/plugins/zsh-history-substring-search" "$ZSH_HISTORY_SUBSTRING_SEARCH_COMMIT"

# 4. Deploy generic dotfiles. Machine-local secrets live in ~/.zshrc.local,
#    which the generic .zshrc sources at the top (see .zshrc.local.example).
log "linking .zshrc and .p10k.zsh..."
link_dotfile "$DOTFILES_LINUX_DIR/.zshrc"    "$HOME/.zshrc"
link_dotfile "$DOTFILES_LINUX_DIR/.p10k.zsh" "$HOME/.p10k.zsh"

# 5. Default login shell -> zsh. Don't abort the run if chsh is refused.
ZSH_BIN="$(command -v zsh || printf '/bin/zsh')"
if [ "${SHELL:-}" != "$ZSH_BIN" ]; then
    if run sudo chsh -s "$ZSH_BIN" "$USER"; then
        log "default shell set to $ZSH_BIN (re-login to take effect)"
    else
        warn "could not change login shell automatically. Run manually:"
        warn "  chsh -s $ZSH_BIN"
    fi
fi

log "done. Open a new terminal to use zsh."
