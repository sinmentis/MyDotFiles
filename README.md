# MyDotFiles

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

