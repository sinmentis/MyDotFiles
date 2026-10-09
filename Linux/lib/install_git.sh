#!/usr/bin/env bash
#
# install_git.sh — git + git-delta, deploy the generic .gitconfig, and seed
# machine-local identity and credential configuration from examples.
#
# The generic .gitconfig [include]s ~/.gitconfig.local, which holds per-machine
# defaults and credential helpers. Azure DevOps remotes additionally include
# ~/.gitconfig-ado so work repositories can use a separate identity.
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

# 3. Seed machine-local files from examples if missing (never clobber).
seed_local_file "$DOTFILES_LINUX_DIR/.gitconfig.local.example" "$HOME/.gitconfig.local"
seed_local_file "$DOTFILES_LINUX_DIR/.gitconfig-ado.example" "$HOME/.gitconfig-ado"

# 4. Nudge if identity is still the placeholder.
if git config --global user.email | grep -q "you@example.com"; then
    warn "git identity is still the placeholder. Edit ~/.gitconfig.local:"
    warn "  git config -f ~/.gitconfig.local user.name  'Your Name'"
    warn "  git config -f ~/.gitconfig.local user.email 'you@example.com'"
fi
if git config -f "$HOME/.gitconfig-ado" user.email | grep -q "you@company.example"; then
    warn "Azure DevOps identity is still the placeholder. Edit ~/.gitconfig-ado:"
    warn "  git config -f ~/.gitconfig-ado user.name  'Your Work Name'"
    warn "  git config -f ~/.gitconfig-ado user.email 'you@company.example'"
fi

log "done."
