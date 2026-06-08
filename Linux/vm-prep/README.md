# VM Prep — fresh Ubuntu hardening

One-time setup scripts for a new Ubuntu 24.04 LTS VM (Azure / any cloud /
bare metal). Run them in order on a freshly provisioned box, before
installing application stacks (Docker, Node, Caddy, etc.).

Every script is **idempotent** — safe to re-run if interrupted or if
something failed midway. Each script does one thing and prints what it
did at the end.

## Order

| # | Script                       | What it does                                     | Reboot?   |
|---|------------------------------|--------------------------------------------------|-----------|
| 1 | `01-base.sh`                 | apt upgrade + base toolchain (vim, htop, git…)   | Maybe     |
| 2 | `02-unattended-upgrades.sh`  | Auto-install security patches nightly            | No        |
| 3 | `03-firewall.sh`             | UFW: deny inbound, allow ssh/http/https          | No        |
| 4 | `04-fail2ban.sh`             | Auto-ban IPs that brute-force SSH                | No        |
| 5 | `05-swap.sh`                 | 4 GB swapfile (insurance vs. OOM)                | No        |
| 6 | `06-timezone.sh`             | Set timezone to Pacific/Auckland                 | No        |

## Run

```bash
cd ~/MyDotFiles/Linux/vm-prep   # or wherever you cloned the repo
bash 01-base.sh
bash 02-unattended-upgrades.sh
bash 03-firewall.sh
bash 04-fail2ban.sh
bash 05-swap.sh
bash 06-timezone.sh
```

Or, if you want to skip the prompt-by-prompt walk-through:

```bash
for s in 0?-*.sh; do bash "$s"; done
```

All scripts use `sudo` internally — you don't need to run them as root, but
you'll be prompted for your password the first time `sudo` is invoked.

## After all six

1. Reboot if `01-base.sh` upgraded the kernel (it'll tell you).
2. Re-SSH in. `uptime` should show ~0 minutes if you rebooted.
3. Provision your shell + tools with the orchestrator:
   - `cd ~/MyDotFiles && ./install.sh --profile vm`
     (zsh + oh-my-zsh + p10k, git, tmux without auto-attach, copilot config)
   - Install Tailscale, Docker, Node, etc. (separate scripts / manual).

## What's intentionally NOT here

- **SSH key restrictions / disabling password auth** — Azure cloud-init
  already configured key-only auth for the admin user during VM creation.
  Re-doing it here would be redundant.
- **Application installs** (Docker, Node, Caddy, Tailscale) — kept separate
  so each can be re-run / re-configured independently.
- **Snapshots / backups** — handled at the cloud-provider level, not on
  the guest.
