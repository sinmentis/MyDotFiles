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
| copilot skills | `Linux/copilot/skills/`           | n/a — skills are public-safe by design |

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

#### Personal Copilot skills

`Linux/copilot/skills/` holds personal GitHub Copilot CLI skills (one
subdirectory per skill, each with a `SKILL.md`). `install_copilot.sh`
symlinks the whole directory to `~/.copilot/skills`, so any skill added here
is picked up on the next `install.sh --copilot` (or `--profile wsl|vm`) run.
Add a new skill by creating `Linux/copilot/skills/<name>/SKILL.md`.

### First-time VM provisioning (hardening)

For a brand-new cloud VM, run the hardening scripts in `Linux/vm-prep/` once
before `install.sh` (apt upgrade, unattended-upgrades, ufw, fail2ban, swap,
timezone). See `Linux/vm-prep/README.md`.

### Repo layout

```
MyDotFiles/
|-- install.sh                  # entry point: --profile {vm,wsl,minimal} + flags
|-- .gitignore                  # hides *.local / secrets / backups
`-- Linux/
    |-- .zshrc / .p10k.zsh      # generic zsh
    |-- .gitconfig              # generic git (includes ~/.gitconfig.local)
    |-- .tmux.conf
    |-- *.local.example         # templates for machine-local overrides
    |-- copilot/                # copilot-instructions.md + mcp-config.json + skills/
    |-- lib/                    # idempotent install_*.sh components
    `-- vm-prep/                # one-time VM hardening scripts
```

## PowerShell

1. Install Scoop and tools

```
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
scoop install curl sudo
winget install -e --id Git.Git
scoop install neovim gcc
```

2. Setup user profile
```
mkdir .config
cp powershell .config
echo $env:USERPROFILE\.config\powershell\user_profile.ps1 > $PROFILE.CurrentUserCurrentHost
```

3. Install oh my posh
```
Install-Module posh-git -Scope CurrentUser -Force
Install-Module oh-my-posh -Scope CurrentUser -Force
```

4. Install related tools - Terminal Icons / z / PSReadLine / fzf
```
Install-Module -Name Terminal-Icons -Repository PSGallery -Force
Install-Module -Name z -Force
Install-Module -Name PSReadLine -AllowPrerelease -Scope CurrentUser -Force - SkipPublisherCheck
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
scoop install fzf
Install-Module -Name PSFzf -Scope CurrentUser -Force
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'
```


## Nerd Font
[Hack Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Hack.zip)
