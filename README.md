# MyDotFiles

One-shot dotfiles + provisioning for Linux (WSL / cloud VM / bare metal),
PowerShell, and Chrome.

## Linux: quick start

```bash
git clone https://github.com/sinmentis/MyDotFiles.git ~/MyDotFiles
cd ~/MyDotFiles
./install.sh --profile vm        # see profiles below
```

`install.sh` installs the selected components (each an idempotent
`Linux/lib/install_*.sh`) and symlinks the generic dotfiles into `$HOME`.

### Profiles

| profile   | zsh | git | tmux | copilot | tmux auto-attach |
|-----------|:---:|:---:|:----:|:-------:|:----------------:|
| `wsl`     |  y  |  y  |  y   |   y     | on               |
| `vm`      |  y  |  y  |  y   |   y     | off              |
| `minimal` |  y  |  y  |  -   |   -     | off              |

```bash
./install.sh --profile wsl       # workstation you live in
./install.sh --profile vm        # server: tmux available but no auto-attach on SSH login
./install.sh --profile minimal   # just a usable shell

# granular overrides (combine freely, they win over the profile):
./install.sh --zsh --git
./install.sh --profile vm --no-tmux
./install.sh --profile vm --tmux-autoattach
```

Run `./install.sh --help` for the full flag list.

### Layering: public base + machine-local overrides

The repo only holds **generic, public-safe** config. Anything secret,
employer-specific, or per-machine lives in `*.local` files that are gitignored
and never committed. Templates ship as `*.example`.

| concern | tracked (public)                        | local override (gitignored)            |
|---------|-----------------------------------------|----------------------------------------|
| zsh     | `Linux/.zshrc` sources it at top        | `~/.zshrc.local`                       |
| git     | `Linux/.gitconfig` `[include]`s it      | `~/.gitconfig.local` (identity, creds) |
| copilot | `Linux/copilot/copilot-instructions.md` | `~/.copilot/local/*.instructions.md`   |
| copilot skills | `skills/`                          | n/a — skills are public-safe by design |
| copilot hooks | `Linux/copilot/hooks/` | n/a — generic user hooks are public-safe |

Seed your local files from the examples:

```bash
cp Linux/.zshrc.local.example     ~/.zshrc.local
cp Linux/.gitconfig.local.example ~/.gitconfig.local
# then edit them with your own identity / secrets / tooling
```

`install.sh` seeds `~/.gitconfig.local` and `~/.zshrc.local` automatically if
they're missing, so a fresh machine still gets a working git identity and the
tmux auto-attach flag.

#### tmux auto-attach

The generic `.zshrc` only drops you into tmux on login when
`DOTFILES_TMUX_AUTOATTACH` is set (done in `~/.zshrc.local`). Servers leave it
unset, so an SSH login *from* a machine that already runs tmux never nests.
Re-attach manually with `tmux a` when you want a persistent server session, or
run long-lived services under systemd instead of tmux.

#### Copilot instruction layering

GitHub Copilot CLI loads `**/*.instructions.md` from every directory listed in
`COPILOT_CUSTOM_INSTRUCTIONS_DIRS` (comma-separated) and **appends** them onto
`~/.copilot/copilot-instructions.md`. Keep generic rules in the tracked
`copilot-instructions.md`; keep work/private context in
`~/.copilot/local/*.instructions.md` and point the env var there (e.g. from
`~/.zshenv`).

#### Personal Copilot plugin marketplace

The repository root is a versioned Copilot CLI plugin:

```text
plugin.json                         # shunbox manifest
.github/plugin/marketplace.json     # sinmentis catalog
skills/<name>/SKILL.md              # one directory per skill
```

Install it from GitHub:

```bash
copilot plugin marketplace add sinmentis/MyDotFiles
copilot plugin install shunbox@sinmentis
```

Update it after a new release:

```bash
copilot plugin marketplace update sinmentis
copilot plugin update shunbox@sinmentis
```

For a local clone, `install_copilot.sh` registers the clone as a development
marketplace and reinstalls the cached plugin. Add a skill under
`skills/<name>/SKILL.md`, validate it, then reinstall:

```bash
node scripts/validate-plugin.js
copilot plugin install shunbox@sinmentis
```

The installer preserves an existing real `~/.copilot/mcp-config.json`, so
machine-local MCP servers are not replaced by the tracked generic config.

Release a new version by updating `CHANGELOG.md`, then synchronizing the plugin
and marketplace manifests:

```bash
node scripts/set-plugin-version.js 0.2.0
node scripts/validate-plugin.js
git add plugin.json .github/plugin/marketplace.json CHANGELOG.md
git commit -m "chore(plugin): release v0.2.0"
git tag v0.2.0
git push origin main v0.2.0
```

#### Copilot CLI tmux alerts

`Linux/copilot/hooks/tmux-alerts.json` emits a terminal bell when the main
Copilot agent finishes a turn or requests permission or additional input.
tmux monitors that bell and highlights the originating background window until
you select it. `install_copilot.sh` links the tracked hooks directory to
`~/.copilot/hooks`.

Copilot CLI loads hook configuration at startup, so restart existing sessions
after changing hooks.

### First-time VM provisioning (hardening)

For a brand-new cloud VM, run the hardening scripts in `Linux/vm-prep/` once
before `install.sh` (apt upgrade, unattended-upgrades, ufw, fail2ban, swap,
timezone). See `Linux/vm-prep/README.md`.

### Repo layout

```
MyDotFiles/
|-- install.sh                  # entry point: --profile {vm,wsl,minimal} + flags
|-- .gitignore                  # hides *.local / secrets / backups
|-- Linux/
|   |-- .zshrc / .p10k.zsh      # generic zsh
|   |-- .gitconfig              # generic git (includes ~/.gitconfig.local)
|   |-- .tmux.conf
|   |-- *.local.example         # templates for machine-local overrides
|   |-- copilot/                # instructions + MCP config + hooks/
|   |-- lib/                    # idempotent install_*.sh components
|   `-- vm-prep/                # one-time VM hardening scripts
|-- Windows/
|   |-- bootstrap.ps1           # Windows host entry point
|   |-- packages.psd1           # exact WinGet package IDs
|   |-- configure-user.ps1      # user-level config deployment
|   |-- .config/                # PowerShell + Starship config
|   `-- WindowsTerminal/        # settings overlay + Copilot profile
|-- plugin.json                 # Copilot plugin manifest
|-- skills/                     # root-level personal Copilot skills
`-- .github/plugin/marketplace.json
```

## Windows host: quick start

The Windows setup uses a WinGet package manifest and leaves WSL distributions
untouched. From a normal Windows PowerShell (it requests UAC elevation):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Windows\bootstrap.ps1 -EnableWsl
```

This installs the Windows-side terminal, Git/GitHub, Copilot, editor, prompt,
modern CLI tools, and the WSL platform without installing a distribution. See
[`Windows/README.md`](Windows/README.md) for the exact package list, rerun
options, WSL restore command, and manual authentication steps.
