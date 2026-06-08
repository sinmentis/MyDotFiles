#!/usr/bin/env bash
#
# install_git.sh — git + git-delta, deploy the generic .gitconfig, and seed
# ~/.gitconfig.local (identity + credential helpers) from the example.
#
# The generic .gitconfig [include]s ~/.gitconfig.local, which holds per-machine
# identity + credential helpers and is never committed. This script makes sure
# that local file exists (seeded from the example) so git has an identity.
#
# Idempotent. Invoked by ../install.sh, or standalone:
#   bash lib/install_git.sh

set -euo pipefail
LOG_TAG="git"
DOTFILES_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DOTFILES_LINUX_DIR/lib/common.sh"

# 1. Packages. git-delta powers the pager/diff config in .gitconfig.
log "installing git + git-delta..."
sudo apt update
apt_install git git-delta

# 2. Deploy generic .gitconfig.
log "linking .gitconfig..."
link_dotfile "$DOTFILES_LINUX_DIR/.gitconfig" "$HOME/.gitconfig"

# 3. Seed ~/.gitconfig.local from the example if missing (never clobber).
seed_local_file "$DOTFILES_LINUX_DIR/.gitconfig.local.example" "$HOME/.gitconfig.local"

# 4. Nudge if identity is still the placeholder.
if git config --global user.email | grep -q "you@example.com"; then
    warn "git identity is still the placeholder. Edit ~/.gitconfig.local:"
    warn "  git config -f ~/.gitconfig.local user.name  'Your Name'"
    warn "  git config -f ~/.gitconfig.local user.email 'you@example.com'"
fi

log "done."
