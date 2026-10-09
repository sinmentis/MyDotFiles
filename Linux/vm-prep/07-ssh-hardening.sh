#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [ "${1:-}" != "--disable-password-auth" ] || [ "$#" -ne 1 ]; then
    echo "Usage: $0 --disable-password-auth" >&2
    exit 2
fi

authorized_keys="$HOME/.ssh/authorized_keys"
if [ ! -s "$authorized_keys" ]; then
    echo "Refusing to disable SSH password authentication: $authorized_keys is missing or empty." >&2
    exit 1
fi

config_file="$(mktemp)"
trap 'rm -f "$config_file"' EXIT
cat >"$config_file" <<'EOF'
# Managed by MyDotFiles/Linux/vm-prep/07-ssh-hardening.sh
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF

vm_sudo install -m 644 "$config_file" /etc/ssh/sshd_config.d/99-mydotfiles.conf
vm_sudo sshd -t
vm_sudo systemctl reload ssh

echo "[07-ssh] password authentication disabled after validating authorized_keys."
