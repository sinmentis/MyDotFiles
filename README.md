# MyDotFiles

Personal workstation and VM setup for Linux, WSL, and Windows. The repository
contains portable defaults plus idempotent setup scripts. Secrets and
machine-specific identity stay in untracked local files.

## Linux / WSL

```bash
git clone https://github.com/sinmentis/MyDotFiles.git ~/MyDotFiles
cd ~/MyDotFiles
./install.sh --profile wsl
```

Use `--profile vm` for a server without tmux auto-attach, or
`--profile minimal` for zsh and Git only. Preview changes with `--dry-run`.

See [`Linux/README.md`](Linux/README.md) for profiles, prerequisites, local
overrides, helper commands, and optional VM preparation.

## Windows

From a normal Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Windows\bootstrap.ps1 -EnableWsl
```

See [`Windows/README.md`](Windows/README.md) for prerequisites, package
manifests, rerun switches, authentication, and WSL restoration.

## Local configuration

Setup scripts preserve existing local files. Git and zsh examples are seeded
when missing; private Copilot instruction files are added manually:

- `~/.zshrc.local`
- `~/.gitconfig.local`
- `~/.gitconfig-ado`
- `~/.copilot/instructions/*.instructions.md`

Edit those files in place. Do not copy the examples over an existing setup.

## Other assets

- [`Linux/bin/README.md`](Linux/bin/README.md): `copilot-tmux` and Playwright MCP
- [`Linux/vm-prep/README.md`](Linux/vm-prep/README.md): Ubuntu VM preparation
- [`Chrome/`](Chrome/): browser configuration exports
- [`Hardware/`](Hardware/): hardware configuration exports
