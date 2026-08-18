# Windows host setup

This setup configures the Windows host only. It does not create, import, start,
or modify a WSL distribution.

Node.js LTS is installed on Windows for native tooling. Other language
runtimes, compilers, and Docker belong to the restored WSL environment.

## What is automated

- WinGet packages: PowerShell 7, Windows Terminal, Git, GitHub CLI, Copilot CLI,
  VS Code, Node.js LTS, Starship, zoxide, fzf, fd, ripgrep, eza, jq, delta, and
  a Nerd Font.
- Win32 long-path support, with optional Windows Developer Mode.
- PowerShell modules and profile deployment.
- A portable Git configuration with a machine-local identity file.
- Windows Terminal defaults without replacing its generated profile list.
- VS Code's WSL and PowerShell extensions.
- The tracked global Copilot instructions and `shunbox@sinmentis` plugin.

Run from a normal Windows PowerShell. The script requests elevation for package
and system changes, then returns to the original user context for profile files:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Windows\bootstrap.ps1 -EnableWsl
```

`-EnableWsl` runs `wsl --install --no-distribution`. It enables the WSL host
without installing a Linux distribution. Omit it when WSL should remain
untouched. Add `-EnableDeveloperMode` only when Windows sideloading or
unprivileged symlink creation is needed.

To redeploy only user configuration:

```powershell
pwsh -NoProfile -File .\Windows\configure-user.ps1
```

## Manual steps

1. Restart Windows if WSL setup requests it, then import the existing WSL backup
   with `wsl --import` or `wsl --import-in-place`.
2. Edit `~/.gitconfig.local` and add the Git user name and email.
3. Run `gh auth login`, followed by `gh auth setup-git`.
4. Start `copilot` and use `/login` if it does not reuse the GitHub CLI login.
5. Enable VS Code Settings Sync and sign in to any private cloud, VPN, or
   employer tooling separately.

## Why the old setup was replaced

The previous README commands dated from 2022, mixed Scoop and WinGet without a
package manifest, installed Oh My Posh while the profile used Starship, omitted
PowerShell 7 and zoxide, and wrote a profile loader that did not dot-source the
managed profile. The checked-in Scoop file was machine state, not a reproducible
package list. The full Windows Terminal export also contained generated,
machine-specific profiles and a Ctrl+C copy binding that intercepted shell
interrupts.

The current design uses a reviewable WinGet package manifest and an idempotent
PowerShell layer. This avoids requiring the Store-delivered DSC processor on
machines where WinGet Configuration has not been enabled.
