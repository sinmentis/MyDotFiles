#!/usr/bin/env bash
#
# 06-timezone.sh — set the requested system timezone.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

TZ_TARGET=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --timezone)
            [ "$#" -ge 2 ] || { echo "--timezone requires a value" >&2; exit 2; }
            TZ_TARGET="$2"; shift 2 ;;
        --timezone=*) TZ_TARGET="${1#*=}"; shift ;;
        -h|--help)
            echo "Usage: $0 --timezone IANA_ZONE"
            exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[ -n "$TZ_TARGET" ] || { echo "--timezone is required" >&2; exit 2; }

echo "[06-tz] setting timezone to $TZ_TARGET..."
vm_sudo timedatectl set-timezone "$TZ_TARGET"

echo "[06-tz] current time settings:"
vm_run timedatectl

echo "[06-tz] done."
