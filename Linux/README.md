# Linux and WSL setup

## Prerequisites

- Ubuntu 24.04 or a compatible APT-based distribution
- A user with `sudo`
- Git for cloning this repository
- Node.js and GitHub Copilot CLI when installing the Copilot configuration

The setup installs shell, Git, and tmux packages. It configures Copilot but does
not install the Copilot CLI itself.

## Profiles

| Profile | zsh | Git | tmux | Copilot config | tmux auto-attach |
|---|:---:|:---:|:---:|:---:|:---:|
| `wsl` | yes | yes | yes | yes | on |
| `vm` | yes | yes | yes | yes | off |
| `minimal` | yes | yes | no | no | unchanged |

```bash
./install.sh --profile wsl
./install.sh --profile vm
./install.sh --profile minimal
```

Granular flags override profiles:

```bash
./install.sh --zsh --git
./install.sh --profile vm --no-copilot
./install.sh --profile vm --tmux-autoattach
```

Use `./install.sh --help` for all flags. `--dry-run` prints changes without
applying them. `--update` refreshes the pinned Oh My Zsh, theme, and plugin
checkouts.

## Local overrides

The installer creates missing Git and zsh examples once and preserves existing
files:

| File | Purpose |
|---|---|
| `~/.zshrc.local` | aliases, private tooling, tmux auto-attach |
| `~/.gitconfig.local` | default identity and credential helpers |
| `~/.gitconfig-ado` | identity used only by Azure DevOps remotes |
| `~/.copilot/instructions/*.instructions.md` | private global Copilot context |

Edit the local files after the first run. The example Git identities are
placeholders and must be replaced before committing. The Copilot instructions
directory is created, but private instruction files are added manually.

## Copilot configuration

`install_copilot.sh` installs:

- shared global instructions from `Shared/copilot/`
- user-level hooks for session tracking
- the `tmux-status` extension for animated running, waiting, and unread indicators
- the tracked MCP configuration
- the `playwright-mcp` launcher in `~/.local/bin`

Restart Copilot CLI after hook or extension changes. Reload tmux with
`tmux source-file ~/.tmux.conf` after status configuration changes.
See [`bin/README.md`](bin/README.md) for status indicators, session snapshot
commands, and Playwright profile settings.

## VM preparation

The optional scripts under [`vm-prep/`](vm-prep/) configure an Ubuntu VM before
the normal profile setup. Their runner requires explicit timezone and swap
settings and stops for a reboot after kernel updates.
