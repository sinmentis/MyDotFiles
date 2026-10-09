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

is_dry_run() {
    [ "${DOTFILES_DRY_RUN:-0}" = "1" ]
}

print_command() {
    printf '\033[1;36m[%s] DRY-RUN:\033[0m' "${LOG_TAG:-dotfiles}"
    printf ' %q' "$@"
    printf '\n'
}

run() {
    if is_dry_run; then
        print_command "$@"
        return 0
    fi
    "$@"
}

apt_update_once() {
    if [ "${DOTFILES_APT_UPDATED:-0}" = "1" ]; then
        return
    fi
    run sudo apt update
    export DOTFILES_APT_UPDATED=1
}

# apt_install <pkg>...  — install packages non-interactively (idempotent).
apt_install() {
    apt_update_once
    run sudo env DEBIAN_FRONTEND=noninteractive apt install -y "$@"
}

# link_dotfile <src> <dest> — symlink src→dest, backing up any existing real
# file (not symlink) as <dest>.bak.<timestamp>. Idempotent.
link_dotfile() {
    local src="$1" dest="$2"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        local backup
        backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
        warn "backing up existing $dest -> $backup"
        run mv "$dest" "$backup"
    fi
    run mkdir -p "$(dirname "$dest")"
    run ln -sfn "$src" "$dest"
    log "linked $dest -> $src"
}

# clone_at_commit <url> <dest> <commit> — reproducible clone. Existing clones
# are updated only when DOTFILES_UPDATE=1 so routine installs preserve them.
clone_at_commit() {
    local url="$1" dest="$2" commit="$3"
    if [ ! -d "$dest/.git" ]; then
        if [ -e "$dest" ]; then
            warn "cannot install $dest because it exists and is not a Git checkout"
            return 1
        fi
        local temporary
        temporary="${dest}.tmp.$$"
        run mkdir -p "$(dirname "$dest")"
        run git clone --filter=blob:none --no-checkout "$url" "$temporary"
        if is_dry_run; then
            print_command git -C "$temporary" checkout --detach "$commit"
            print_command mv "$temporary" "$dest"
            return
        fi
        if ! git -C "$temporary" fetch --depth=1 origin "$commit" ||
           ! git -C "$temporary" checkout --detach "$commit"; then
            rm -rf "$temporary"
            return 1
        fi
        mv "$temporary" "$dest"
        return
    fi

    if [ "${DOTFILES_UPDATE:-0}" != "1" ] &&
       git -C "$dest" rev-parse --verify HEAD >/dev/null 2>&1; then
        return
    fi
    if git -C "$dest" rev-parse --verify HEAD >/dev/null 2>&1 &&
       { ! git -C "$dest" diff --quiet || ! git -C "$dest" diff --cached --quiet; }; then
        warn "not updating $dest because it has local changes"
        return
    fi
    run git -C "$dest" fetch --depth=1 origin "$commit"
    run git -C "$dest" checkout --detach "$commit"
}

# seed_local_file <example> <dest> — copy example to dest only if dest missing,
# so machine-local overrides are never clobbered.
seed_local_file() {
    local example="$1" dest="$2"
    if [ -e "$dest" ]; then
        log "$dest already exists, leaving it untouched"
    else
        run mkdir -p "$(dirname "$dest")"
        run cp "$example" "$dest"
        log "seeded $dest from $(basename "$example") — edit it with your own values"
    fi
}
