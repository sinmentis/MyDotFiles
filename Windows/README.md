# Windows host setup

This setup configures the Windows host. `-EnableWsl` enables the WSL platform
without creating, importing, starting, or modifying a Linux distribution.

## Prerequisites

- Windows 11 with WinGet available through App Installer
- A local checkout of this repository
- Network access to the WinGet and PowerShell Gallery repositories

Run from a normal Windows PowerShell in the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Windows\bootstrap.ps1 -EnableWsl
```

The script requests elevation for packages and system settings, then returns to
the original user context for profile files.

## Installed configuration

- Packages listed in [`packages.psd1`](packages.psd1)
- Modules listed in [`required-modules.psd1`](required-modules.psd1)
- PowerShell, Git, Starship, Windows Terminal, and VS Code configuration
- Shared global Copilot instructions
- Optional WSL platform enablement without installing a distribution

Useful rerun switches:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Windows\bootstrap.ps1 -SkipPackages
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Windows\bootstrap.ps1 -SkipSystemSettings
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Windows\bootstrap.ps1 -SkipUserConfiguration
pwsh -NoProfile -File .\Windows\configure-user.ps1 -SkipModules -SkipExtensions
```

Add `-EnableDeveloperMode` only when Windows sideloading or unprivileged
symlink creation is required.

## Manual steps

1. Restart Windows if WSL setup requests it.
2. Import an existing WSL backup with `wsl --import` or
   `wsl --import-in-place`.
3. Replace the placeholder identity in `~/.gitconfig.local`.
4. Run `gh auth login`, then `gh auth setup-git`.
5. Start `copilot` and use `/login` when needed.
6. Enable VS Code Settings Sync and authenticate private tooling separately.
