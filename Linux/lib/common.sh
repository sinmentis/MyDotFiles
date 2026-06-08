#!/usr/bin/env bash
#
# common.sh — shared helpers for the lib/install_*.sh scripts.
# Sourced, not executed. Do not run directly.

# Resolve the repo's Linux/ dir regardless of where a caller invokes from.
# Each lib script sets DOTFILES_LINUX_DIR before sourcing, but provide a
# fallback based on this file's own location.
if [ -z "${DOTFILES_LINUX_DIR:-}" ]; then
    DOTFILES_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "${LOG_TAG:-dotfiles}" "$*"; }
warn() { printf '\033[1;33m[%s] WARN:\033[0m %s\n' "${LOG_TAG:-dotfiles}" "$*" >&2; }

# apt_install <pkg>...  — install packages non-interactively (idempotent).
apt_install() {
    sudo DEBIAN_FRONTEND=noninteractive apt install -y "$@"
}

# link_dotfile <src> <dest> — symlink src→dest, backing up any existing real
# file (not symlink) as <dest>.bak.<timestamp>. Idempotent.
link_dotfile() {
    local src="$1" dest="$2"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        local backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
        warn "backing up existing $dest -> $backup"
        mv "$dest" "$backup"
    fi
    ln -sfn "$src" "$dest"
    log "linked $dest -> $src"
}

# clone_if_missing <url> <dest> — shallow clone only if dest absent.
clone_if_missing() {
    local url="$1" dest="$2"
    [ -d "$dest" ] || git clone --depth=1 "$url" "$dest"
}

# seed_local_file <example> <dest> — copy example to dest only if dest missing,
# so machine-local overrides are never clobbered.
seed_local_file() {
    local example="$1" dest="$2"
    if [ -e "$dest" ]; then
        log "$dest already exists, leaving it untouched"
    else
        cp "$example" "$dest"
        log "seeded $dest from $(basename "$example") — edit it with your own values"
    fi
}
