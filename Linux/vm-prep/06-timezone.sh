#!/usr/bin/env bash
#
# 06-timezone.sh — set system timezone to Pacific/Auckland.
#
# Why bother: log timestamps, cron schedules, and `date` output all
# follow the system timezone. Reading journalctl in UTC when you live
# in NZ is annoying. Setting this correctly also makes auto-shutdown
# windows / unattended-upgrades run at sensible local hours.
#
# `timedatectl set-timezone` updates /etc/localtime symlink + writes
# /etc/timezone in one step, and the change applies immediately (no
# reboot needed) — running daemons may need a restart to pick it up,
# but for a fresh box that's a non-issue.
#
# Idempotent: setting the same zone twice is a no-op.

set -euo pipefail

TZ_TARGET="Pacific/Auckland"

echo "[06-tz] setting timezone to $TZ_TARGET..."
sudo timedatectl set-timezone "$TZ_TARGET"

echo "[06-tz] current time settings:"
timedatectl

echo "[06-tz] done."
