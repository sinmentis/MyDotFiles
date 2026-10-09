#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

timezone=""
swap_size=""
allow_http=0
allow_https=0
ignore_private_networks=0
disable_ssh_password_auth=0
skip_base=0
DOTFILES_DRY_RUN="${DOTFILES_DRY_RUN:-0}"

usage() {
    cat <<'EOF'
Usage:
  ./run.sh --timezone ZONE --swap-size SIZE [options]

Required:
  --timezone ZONE              IANA timezone, for example Pacific/Auckland
  --swap-size SIZE             Swap size accepted by fallocate, for example 4G

Options:
  --allow-http                 Open TCP port 80
  --allow-https                Open TCP port 443
  --ignore-private-networks    Exempt RFC1918 sources from fail2ban
  --disable-ssh-password-auth  Require SSH keys after validating authorized_keys
  --skip-base                  Resume after reboot without rerunning 01-base.sh
  --dry-run                    Print privileged changes without applying them
  -h, --help                   Show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --timezone)
            [ "$#" -ge 2 ] || { echo "--timezone requires a value" >&2; exit 2; }
            timezone="$2"; shift 2 ;;
        --timezone=*) timezone="${1#*=}"; shift ;;
        --swap-size)
            [ "$#" -ge 2 ] || { echo "--swap-size requires a value" >&2; exit 2; }
            swap_size="$2"; shift 2 ;;
        --swap-size=*) swap_size="${1#*=}"; shift ;;
        --allow-http) allow_http=1; shift ;;
        --allow-https) allow_https=1; shift ;;
        --ignore-private-networks) ignore_private_networks=1; shift ;;
        --disable-ssh-password-auth) disable_ssh_password_auth=1; shift ;;
        --skip-base) skip_base=1; shift ;;
        --dry-run) DOTFILES_DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

[ -n "$timezone" ] || { echo "--timezone is required" >&2; usage; exit 2; }
[ -n "$swap_size" ] || { echo "--swap-size is required" >&2; usage; exit 2; }
export DOTFILES_DRY_RUN

if [ "$skip_base" = "0" ]; then
    bash "$SCRIPT_DIR/01-base.sh"
    if [ "$DOTFILES_DRY_RUN" != "1" ] && [ -f /var/run/reboot-required ]; then
        echo "A reboot is required. Reboot, then resume with:"
        printf '  %q --skip-base --timezone %q --swap-size %q' "$0" "$timezone" "$swap_size"
        [ "$allow_http" = "1" ] && printf ' --allow-http'
        [ "$allow_https" = "1" ] && printf ' --allow-https'
        [ "$ignore_private_networks" = "1" ] && printf ' --ignore-private-networks'
        [ "$disable_ssh_password_auth" = "1" ] && printf ' --disable-ssh-password-auth'
        printf '\n'
        exit 75
    fi
fi

bash "$SCRIPT_DIR/02-unattended-upgrades.sh"

firewall_args=()
[ "$allow_http" = "1" ] && firewall_args+=(--allow-http)
[ "$allow_https" = "1" ] && firewall_args+=(--allow-https)
bash "$SCRIPT_DIR/03-firewall.sh" "${firewall_args[@]}"

fail2ban_args=()
[ "$ignore_private_networks" = "1" ] && fail2ban_args+=(--ignore-private-networks)
bash "$SCRIPT_DIR/04-fail2ban.sh" "${fail2ban_args[@]}"

bash "$SCRIPT_DIR/05-swap.sh" --size "$swap_size"
bash "$SCRIPT_DIR/06-timezone.sh" --timezone "$timezone"

if [ "$disable_ssh_password_auth" = "1" ]; then
    bash "$SCRIPT_DIR/07-ssh-hardening.sh" --disable-password-auth
fi

echo "VM preparation completed."
