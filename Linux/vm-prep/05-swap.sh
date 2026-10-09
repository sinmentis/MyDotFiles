#!/usr/bin/env bash
#
# 05-swap.sh — create a 4 GiB swapfile.
#
# Azure VMs do NOT come with swap by default. On a 16 GiB box that
# usually doesn't matter — until something leaks (looking at you,
# Matrix-stack gateways) and the OOM killer reaps the wrong process
# at 3 AM.
#
# 4 GiB of swap on a 16 GiB box is a deliberate compromise:
#   - Big enough to absorb a transient leak / a runaway build so the
#     OOM killer doesn't fire on critical PIDs.
#   - Small enough that if you're actually swapping heavily, you'll
#     notice latency before the disk fills.
#
# What this does:
#   1. If /swapfile already exists and is active, exit early (idempotent).
#   2. fallocate a 4 GiB file at /swapfile.
#   3. chmod 600 so only root can read it (swap contents = process memory).
#   4. mkswap to format, swapon to activate.
#   5. Append to /etc/fstab so it comes back after reboot (only if not
#      already present).
#   6. Tune vm.swappiness down to 10 (default 60). Means "only swap when
#      you really have to" — appropriate for a single-purpose dev VM
#      that should prefer RAM until it's almost full.
#
# Idempotent: every step checks current state before acting.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

SWAPFILE=/swapfile
SWAPSIZE=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --size)
            [ "$#" -ge 2 ] || { echo "--size requires a value" >&2; exit 2; }
            SWAPSIZE="$2"; shift 2 ;;
        --size=*) SWAPSIZE="${1#*=}"; shift ;;
        -h|--help)
            echo "Usage: $0 --size SIZE"
            exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[ -n "$SWAPSIZE" ] || { echo "--size is required" >&2; exit 2; }

if ! vm_is_dry_run && sudo swapon --show=NAME --noheadings | grep -qx "$SWAPFILE"; then
    echo "[05-swap] $SWAPFILE is already active. Skipping creation."
else
    if [ ! -f "$SWAPFILE" ]; then
        requested_bytes="$(numfmt --from=iec "$SWAPSIZE")"
        available_bytes="$(df --output=avail -B1 / | tail -n 1 | tr -d ' ')"
        if [ "$requested_bytes" -gt "$available_bytes" ]; then
            echo "[05-swap] insufficient free disk space for $SWAPSIZE" >&2
            exit 1
        fi
        echo "[05-swap] creating $SWAPFILE ($SWAPSIZE)..."
        vm_sudo fallocate -l "$SWAPSIZE" "$SWAPFILE"
        vm_sudo chmod 600 "$SWAPFILE"
        vm_sudo mkswap "$SWAPFILE"
    fi
    echo "[05-swap] enabling $SWAPFILE..."
    vm_sudo swapon "$SWAPFILE"
fi

# fstab entry — only append if missing.
if ! grep -qE "^${SWAPFILE//\//\\/}\s" /etc/fstab; then
    echo "[05-swap] adding $SWAPFILE to /etc/fstab..."
    if vm_is_dry_run; then
        vm_print_command sh -c "printf '%s\\n' '$SWAPFILE none swap sw 0 0' >> /etc/fstab"
    else
        echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
    fi
fi

# swappiness — write a sysctl drop-in so it persists.
echo "[05-swap] setting vm.swappiness=10 (persistent)..."
if vm_is_dry_run; then
    vm_print_command sh -c "printf '%s\\n' 'vm.swappiness=10' > /etc/sysctl.d/99-swappiness.conf"
else
    echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
fi
vm_sudo sysctl -p /etc/sysctl.d/99-swappiness.conf

echo "[05-swap] swap status:"
vm_sudo swapon --show
vm_run free -h

echo "[05-swap] done."
