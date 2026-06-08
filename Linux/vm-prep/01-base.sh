#!/usr/bin/env bash
#
# 01-base.sh — apt upgrade + install the toolchain I always want on a box.
#
# What this does:
#   1. Refresh the apt package index (`apt update`).
#   2. Upgrade every installed package to the latest available version
#      (`apt upgrade -y`). On a fresh Azure image this typically pulls in
#      a handful of security patches that have shipped since the image
#      was last published.
#   3. Install a fixed list of CLI tools I expect on every box:
#        - build-essential   gcc/g++/make, needed for compiling anything
#                            from source (Node native modules, etc.)
#        - curl, wget        HTTP clients
#        - git               version control
#        - vim, nano         editors (nano as fallback for muscle memory)
#        - htop, btop        interactive process viewers (top on steroids)
#        - net-tools         provides `ifconfig`, `netstat` (deprecated
#                            but still handy on legacy muscle memory)
#        - dnsutils          `dig`, `nslookup`
#        - jq                JSON CLI processor
#        - tree              directory tree printer
#        - tmux              terminal multiplexer (used by install_tmux.sh)
#        - ca-certificates   trusted root CA bundle (needed by curl/git over
#                            HTTPS on a minimal image)
#        - gnupg, lsb-release  required by many third-party apt repos
#                              (Docker, NodeSource) to validate signing keys
#                              and detect the distro codename
#        - git-delta         nicer git diff/log pager (referenced by .gitconfig)
#   4. Run `apt autoremove` to drop any packages left behind as orphans
#      by the upgrade (kernels, libs).
#
# Reboot: if the upgrade replaced the kernel (very likely on a fresh
# image), `/var/run/reboot-required` will exist when this script ends and
# the script will print a reminder. Reboot before continuing.

set -euo pipefail

echo "[01-base] apt update..."
sudo apt update

echo "[01-base] apt upgrade..."
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

echo "[01-base] installing base packages..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
    build-essential \
    curl wget \
    git git-delta \
    vim nano \
    htop btop \
    net-tools dnsutils \
    jq tree \
    tmux \
    ca-certificates gnupg lsb-release

echo "[01-base] autoremove..."
sudo apt autoremove -y

if [ -f /var/run/reboot-required ]; then
    echo
    echo "[01-base] *** /var/run/reboot-required exists — reboot before next step. ***"
    echo "[01-base] Run:  sudo reboot"
else
    echo "[01-base] done. No reboot required."
fi
