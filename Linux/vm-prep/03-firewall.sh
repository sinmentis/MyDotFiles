#!/usr/bin/env bash
#
# 03-firewall.sh — install + enable UFW with a sane default-deny policy.
#
# UFW (Uncomplicated Firewall) is a friendly wrapper over iptables/nftables.
# Azure already filters inbound traffic at the NSG layer, but having a
# host-based firewall is defense-in-depth: if the NSG is ever loosened
# or the VM is moved off Azure, UFW still protects it.
#
# Policy:
#   - default DENY incoming
#   - default ALLOW outgoing (no egress filtering, this is a dev box)
#   - allow SSH (22)         — admin access
#   - optionally allow HTTP (80) and HTTPS (443)
#
# Anything else (game-server ports, Tailscale-only services) is blocked
# at the host even if NSG lets it through.
#
# WARNING: this enables UFW. If you are SSH'd in over port 22 on a
# different VPS without the "allow ssh" rule applied first, you can lock
# yourself out. Here `ufw allow ssh` runs before `ufw enable`, so you're
# safe.
#
# Idempotent: re-running adjusts the rules in place; UFW dedupes them.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

allow_http=0
allow_https=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --allow-http) allow_http=1; shift ;;
        --allow-https) allow_https=1; shift ;;
        -h|--help)
            echo "Usage: $0 [--allow-http] [--allow-https]"
            exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

echo "[03-fw] installing ufw..."
vm_sudo env DEBIAN_FRONTEND=noninteractive apt install -y ufw

echo "[03-fw] applying default policies..."
vm_sudo ufw default deny incoming
vm_sudo ufw default allow outgoing

echo "[03-fw] allowing ssh..."
vm_sudo ufw allow ssh
if [ "$allow_http" = "1" ]; then
    vm_sudo ufw allow http
fi
if [ "$allow_https" = "1" ]; then
    vm_sudo ufw allow https
fi

echo "[03-fw] enabling ufw..."
# --force = skip the "are you sure (y/n)" prompt
vm_sudo ufw --force enable

echo "[03-fw] current rules:"
vm_sudo ufw status verbose

echo "[03-fw] done."
