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
#   - allow HTTP (80)        — Caddy ACME http-01 challenge + redirects
#   - allow HTTPS (443)      — main web traffic
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

echo "[03-fw] installing ufw..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y ufw

echo "[03-fw] applying default policies..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "[03-fw] allowing ssh / http / https..."
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https

echo "[03-fw] enabling ufw..."
# --force = skip the "are you sure (y/n)" prompt
sudo ufw --force enable

echo "[03-fw] current rules:"
sudo ufw status verbose

echo "[03-fw] done."
