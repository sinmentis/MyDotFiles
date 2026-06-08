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

SWAPFILE=/swapfile
SWAPSIZE=4G

if sudo swapon --show=NAME --noheadings | grep -qx "$SWAPFILE"; then
    echo "[05-swap] $SWAPFILE is already active. Skipping creation."
else
    if [ ! -f "$SWAPFILE" ]; then
        echo "[05-swap] creating $SWAPFILE ($SWAPSIZE)..."
        sudo fallocate -l "$SWAPSIZE" "$SWAPFILE"
        sudo chmod 600 "$SWAPFILE"
        sudo mkswap "$SWAPFILE"
    fi
    echo "[05-swap] enabling $SWAPFILE..."
    sudo swapon "$SWAPFILE"
fi

# fstab entry — only append if missing.
if ! grep -qE "^${SWAPFILE//\//\\/}\s" /etc/fstab; then
    echo "[05-swap] adding $SWAPFILE to /etc/fstab..."
    echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
fi

# swappiness — write a sysctl drop-in so it persists.
echo "[05-swap] setting vm.swappiness=10 (persistent)..."
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf

echo "[05-swap] swap status:"
sudo swapon --show
free -h

echo "[05-swap] done."
