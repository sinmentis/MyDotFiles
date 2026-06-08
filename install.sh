#!/usr/bin/env bash
#
# install.sh — one-shot dotfiles provisioner.
#
# Picks which components to install based on a --profile, with optional
# per-component overrides. Each component is an idempotent lib/install_*.sh.
#
# Usage:
#   ./install.sh --profile wsl          # workstation: zsh+git+tmux+copilot, tmux auto-attach ON
#   ./install.sh --profile vm           # server:      zsh+git+tmux+copilot, tmux auto-attach OFF
#   ./install.sh --profile minimal      # bare:        zsh+git only
#
#   # granular overrides (combine freely, override the profile):
#   ./install.sh --zsh --git            # just these two
#   ./install.sh --profile vm --no-tmux
#   ./install.sh --profile vm --tmux-autoattach     # force auto-attach on a server
#
# Profile matrix:
#   profile   zsh  git  tmux  copilot   tmux-autoattach
#   wsl        y    y    y      y          on
#   vm         y    y    y      y          off
#   minimal    y    y    n      n          off
#
# Safe to re-run. Components back up any pre-existing real dotfiles.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$REPO_ROOT/Linux"
LIB_DIR="$LINUX_DIR/lib"
LOG_TAG="install"
source "$LIB_DIR/common.sh"

usage() { sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; /^set -euo/d'; }

# --- defaults (unset = "follow profile") --------------------------------------
PROFILE=""
WANT_ZSH=""; WANT_GIT=""; WANT_TMUX=""; WANT_COPILOT=""; WANT_AUTOATTACH=""

# --- arg parsing --------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --profile)
            if [ $# -lt 2 ]; then warn "--profile needs a value (wsl|vm|minimal)"; exit 2; fi
            PROFILE="$2"; shift 2 ;;
        --profile=*) PROFILE="${1#*=}"; shift ;;
        --zsh)     WANT_ZSH=1; shift ;;
        --no-zsh)  WANT_ZSH=0; shift ;;
        --git)     WANT_GIT=1; shift ;;
        --no-git)  WANT_GIT=0; shift ;;
        --tmux)    WANT_TMUX=1; shift ;;
        --no-tmux) WANT_TMUX=0; shift ;;
        --copilot)    WANT_COPILOT=1; shift ;;
        --no-copilot) WANT_COPILOT=0; shift ;;
        --tmux-autoattach)    WANT_AUTOATTACH=1; shift ;;
        --no-tmux-autoattach) WANT_AUTOATTACH=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) warn "unknown argument: $1"; usage; exit 2 ;;
    esac
done

# --- resolve profile defaults; granular flags above win -----------------------
case "$PROFILE" in
    wsl)     : "${WANT_ZSH:=1}" "${WANT_GIT:=1}" "${WANT_TMUX:=1}" "${WANT_COPILOT:=1}" "${WANT_AUTOATTACH:=1}" ;;
    vm)      : "${WANT_ZSH:=1}" "${WANT_GIT:=1}" "${WANT_TMUX:=1}" "${WANT_COPILOT:=1}" "${WANT_AUTOATTACH:=0}" ;;
    minimal) : "${WANT_ZSH:=1}" "${WANT_GIT:=1}" "${WANT_TMUX:=0}" "${WANT_COPILOT:=0}" "${WANT_AUTOATTACH:=0}" ;;
    "")
        # No profile: require at least one granular component.
        if [ -z "$WANT_ZSH$WANT_GIT$WANT_TMUX$WANT_COPILOT" ]; then
            warn "no --profile and no component flags given."; usage; exit 2
        fi
        : "${WANT_ZSH:=0}" "${WANT_GIT:=0}" "${WANT_TMUX:=0}" "${WANT_COPILOT:=0}" "${WANT_AUTOATTACH:=0}" ;;
    *) warn "unknown profile: $PROFILE (use wsl|vm|minimal)"; exit 2 ;;
esac

log "profile=${PROFILE:-none} zsh=$WANT_ZSH git=$WANT_GIT tmux=$WANT_TMUX copilot=$WANT_COPILOT autoattach=$WANT_AUTOATTACH"

# --- ensure ~/.zshrc.local exists + reflects the auto-attach choice -----------
# The generic .zshrc reads DOTFILES_TMUX_AUTOATTACH from ~/.zshrc.local.
ensure_autoattach() {
    local want="$1" dest="$HOME/.zshrc.local"
    [ -e "$dest" ] || seed_local_file "$LINUX_DIR/.zshrc.local.example" "$dest"
    # Drop any existing active setting, then append the desired one.
    if grep -qE '^[[:space:]]*export DOTFILES_TMUX_AUTOATTACH=' "$dest"; then
        sed -i -E '/^[[:space:]]*export DOTFILES_TMUX_AUTOATTACH=/d' "$dest"
    fi
    if [ "$want" = "1" ]; then
        printf '\nexport DOTFILES_TMUX_AUTOATTACH=1\n' >> "$dest"
        log "tmux auto-attach: ON (set in ~/.zshrc.local)"
    else
        log "tmux auto-attach: OFF (not set in ~/.zshrc.local)"
    fi
}

# --- run selected components --------------------------------------------------
[ "$WANT_ZSH" = "1" ]     && bash "$LIB_DIR/install_zsh.sh"
[ "$WANT_GIT" = "1" ]     && bash "$LIB_DIR/install_git.sh"
[ "$WANT_TMUX" = "1" ]    && bash "$LIB_DIR/install_tmux.sh"
[ "$WANT_COPILOT" = "1" ] && bash "$LIB_DIR/install_copilot.sh"

# Auto-attach state only matters once zsh is in play.
[ "$WANT_ZSH" = "1" ] && ensure_autoattach "$WANT_AUTOATTACH"

log "all done. Open a new terminal (or 'exec zsh') to pick up changes."
