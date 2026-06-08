#!/usr/bin/env bash
#
# 02-unattended-upgrades.sh — auto-install security patches without me
# having to log in.
#
# Ubuntu ships an `unattended-upgrades` package + systemd timer that, by
# default, only installs `*-security` apt sources nightly and emails (or
# silently logs) the result. That's exactly what I want for a personal VM
# I'll forget to maintain.
#
# What this does:
#   1. Install the `unattended-upgrades` package (and its config files
#      `/etc/apt/apt.conf.d/20auto-upgrades` and `50unattended-upgrades`).
#   2. Run `dpkg-reconfigure --priority=low unattended-upgrades` to make
#      sure the auto-upgrades flag is turned on (the default is YES on
#      Ubuntu Server but this is explicit + idempotent).
#   3. Show the effective config + verify the systemd timer is enabled.
#
# What is NOT enabled here on purpose:
#   - Automatic reboot after a kernel upgrade. Manual reboots are fine for
#     a single VM. If you ever want this, add to 50unattended-upgrades:
#         Unattended-Upgrade::Automatic-Reboot "true";
#         Unattended-Upgrade::Automatic-Reboot-Time "04:00";

set -euo pipefail

echo "[02-uu] installing unattended-upgrades..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y unattended-upgrades

echo "[02-uu] reconfiguring (non-interactive)..."
# This writes /etc/apt/apt.conf.d/20auto-upgrades with the YES/YES defaults.
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

echo "[02-uu] effective 20auto-upgrades config:"
sudo cat /etc/apt/apt.conf.d/20auto-upgrades

echo "[02-uu] systemd timer status:"
systemctl status apt-daily.timer apt-daily-upgrade.timer --no-pager || true

echo "[02-uu] done."
