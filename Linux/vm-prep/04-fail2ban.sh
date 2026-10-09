#!/usr/bin/env bash
#
# 04-fail2ban.sh — install fail2ban with default SSH protection.
#
# fail2ban watches log files (sshd, by default) and bans source IPs that
# fail authentication N times in M minutes. On a public-IP box on the
# internet this drops SSH brute-force noise from many thousands of hits
# per day to ~0.
#
# What this does:
#   1. Install the `fail2ban` package + start the service.
#   2. Drop in a small local override (`/etc/fail2ban/jail.local`) that
#      defines a more aggressive default ban policy:
#         - bantime  1h   (default is 10m, too lenient)
#         - findtime 10m  (count failures inside a 10-minute sliding window)
#         - maxretry 5    (5 fails inside findtime → ban for bantime)
#      and explicitly enables the `sshd` jail using systemd journal as
#      the log source (Ubuntu 24.04 uses systemd-journald, not /var/log/auth.log).
#   3. Restart fail2ban so the config takes effect.
#   4. Show the active jails.
#
# We use `jail.local` (not jail.conf) per upstream guidance — package
# upgrades may overwrite jail.conf but never touch jail.local.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ignore_private_networks=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --ignore-private-networks) ignore_private_networks=1; shift ;;
        -h|--help)
            echo "Usage: $0 [--ignore-private-networks]"
            exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

echo "[04-f2b] installing fail2ban..."
vm_sudo env DEBIAN_FRONTEND=noninteractive apt install -y fail2ban

echo "[04-f2b] writing /etc/fail2ban/jail.local..."
ignore_ip="127.0.0.1/8 ::1"
if [ "$ignore_private_networks" = "1" ]; then
    ignore_ip="$ignore_ip 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"
fi

config_file="$(mktemp)"
trap 'rm -f "$config_file"' EXIT
cat >"$config_file" <<EOF
# Managed by MyDotFiles/Linux/vm-prep/04-fail2ban.sh — edits will be
# overwritten if you re-run that script.

[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
ignoreip = $ignore_ip

[sshd]
enabled  = true
backend  = systemd
EOF
vm_sudo install -m 644 "$config_file" /etc/fail2ban/jail.local

echo "[04-f2b] (re)starting fail2ban..."
vm_sudo systemctl enable --now fail2ban
vm_sudo systemctl restart fail2ban

# Give the service a second to bring jails up before querying status.
vm_run sleep 1

echo "[04-f2b] active jails:"
vm_sudo fail2ban-client status || true
echo
echo "[04-f2b] sshd jail detail:"
vm_sudo fail2ban-client status sshd || true

echo "[04-f2b] done."
