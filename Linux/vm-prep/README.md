# Ubuntu VM preparation

Opinionated, parameterized setup for a personal Ubuntu 24.04 VM. It installs a
base toolchain, unattended security updates, UFW, fail2ban, swap, and timezone
configuration.

Preview the full plan:

```bash
./run.sh \
  --timezone Pacific/Auckland \
  --swap-size 4G \
  --allow-http \
  --allow-https \
  --dry-run
```

Apply it:

```bash
./run.sh \
  --timezone Pacific/Auckland \
  --swap-size 4G \
  --allow-http \
  --allow-https
```

Only SSH is opened unless `--allow-http` or `--allow-https` is supplied.
fail2ban ignores only loopback by default. Add `--ignore-private-networks` only
when trusted RFC1918 clients must never be banned.

`01-base.sh` stops the runner with exit code `75` when a reboot is required.
After reboot, rerun the printed command with `--skip-base`.

Password authentication is unchanged by default. To disable it after verifying
that `~/.ssh/authorized_keys` is populated, add:

```bash
--disable-ssh-password-auth
```

After VM preparation:

```bash
cd ~/MyDotFiles
./install.sh --profile vm
```

Application stacks such as Docker, Caddy, Tailscale, and language runtimes are
outside this VM preparation layer.
