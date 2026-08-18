#requires -Version 7.4

[CmdletBinding()]
param(
    [switch]$SkipModules,
    [switch]$SkipExtensions,
    [switch]$SkipCopilotConfiguration
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = [Text.UTF8Encoding]::new($false)

function Backup-File {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $timestamp = Get-Date -Format 'yyyyMMddHHmmssfff'
    $backupPath = "$Path.bak.$timestamp"
    if (Test-Path -LiteralPath $backupPath) {
        $backupPath = "$backupPath.$([guid]::NewGuid().ToString('N'))"
    }
    Copy-Item -LiteralPath $Path -Destination $backupPath
    Write-Host "Backed up $Path -> $backupPath"
}

function Copy-ManagedFile {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination,

        [switch]$SeedOnly
    )

    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Path $parent -Force | Out-Null

    if ($SeedOnly -and (Test-Path -LiteralPath $Destination)) {
        Write-Host "Preserved existing $Destination"
        return
    }

    if (Test-Path -LiteralPath $Destination) {
        $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
        $destinationHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
        if ($sourceHash -eq $destinationHash) {
            return
        }
        Backup-File -Path $Destination
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    Write-Host "Installed $Destination"
}

function Write-ManagedText {
    param(
        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [string]$Content
    )

    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Path $parent -Force | Out-Null

    if (Test-Path -LiteralPath $Destination) {
        $existing = [IO.File]::ReadAllText($Destination)
        if ($existing -eq $Content) {
            return
        }
        Backup-File -Path $Destination
    }

    [IO.File]::WriteAllText($Destination, $Content, $script:utf8NoBom)
    Write-Host "Installed $Destination"
}

function Read-JsonHashtable {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [ordered]@{}
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [ordered]@{}
    }

    $options = [Text.Json.JsonDocumentOptions]::new()
    $options.AllowTrailingCommas = $true
    $options.CommentHandling = [Text.Json.JsonCommentHandling]::Skip
    try {
        $document = [Text.Json.JsonDocument]::Parse($raw, $options)
    }
    catch {
        throw "Unable to parse JSON settings at $Path`: $($_.Exception.Message)"
    }

    try {
        $normalized = $document.RootElement.ToString()
    }
    finally {
        $document.Dispose()
    }

    return $normalized | ConvertFrom-Json -AsHashtable
}

function Merge-Hashtable {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Target,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Overlay
    )

    foreach ($key in $Overlay.Keys) {
        if (
            $Target.Contains($key) -and
            $Target[$key] -is [System.Collections.IDictionary] -and
            $Overlay[$key] -is [System.Collections.IDictionary]
        ) {
            Merge-Hashtable -Target $Target[$key] -Overlay $Overlay[$key]
        }
        else {
            $Target[$key] = $Overlay[$key]
        }
    }
}

function Get-WindowsTerminalSettingsPath {
    $knownPaths = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )

    $existing = $knownPaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($existing) {
        return $existing
    }

    $stablePackage = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
    New-Item -ItemType Directory -Path $stablePackage -Force | Out-Null
    return Join-Path $stablePackage 'settings.json'
}

if (-not $SkipModules) {
    if (-not (Get-Command Install-PSResource -ErrorAction SilentlyContinue)) {
        throw 'Microsoft.PowerShell.PSResourceGet is required but Install-PSResource was not found.'
    }

    $requiredModules = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'required-modules.psd1')
    foreach ($module in $requiredModules.GetEnumerator()) {
        $installed = Get-InstalledPSResource -Name $module.Key -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($installed) {
            continue
        }

        Install-PSResource `
            -Name $module.Key `
            -Repository $module.Value.repository `
            -Scope CurrentUser `
            -TrustRepository `
            -AcceptLicense `
            -Quiet
    }
}

$configRoot = Join-Path $HOME '.config'
Copy-ManagedFile `
    -Source (Join-Path $PSScriptRoot '.config\powershell\user_profile.ps1') `
    -Destination (Join-Path $configRoot 'powershell\user_profile.ps1')
Copy-ManagedFile `
    -Source (Join-Path $PSScriptRoot '.config\starship.toml') `
    -Destination (Join-Path $configRoot 'starship.toml')
Copy-ManagedFile `
    -Source (Join-Path $PSScriptRoot '.gitconfig') `
    -Destination (Join-Path $HOME '.gitconfig')
Copy-ManagedFile `
    -Source (Join-Path $PSScriptRoot '.gitconfig.local.example') `
    -Destination (Join-Path $HOME '.gitconfig.local') `
    -SeedOnly

$profileLoader = @'
$managedProfile = Join-Path $HOME '.config\powershell\user_profile.ps1'
if (-not (Test-Path -LiteralPath $managedProfile)) {
    throw "Managed PowerShell profile is missing: $managedProfile"
}
. $managedProfile
'@
Write-ManagedText -Destination $PROFILE.CurrentUserAllHosts -Content "$profileLoader`n"

$terminalSettingsPath = Get-WindowsTerminalSettingsPath
$terminalSettings = Read-JsonHashtable -Path $terminalSettingsPath
$terminalOverlay = Read-JsonHashtable -Path (
    Join-Path $PSScriptRoot 'WindowsTerminal\settings.overlay.json'
)
Merge-Hashtable -Target $terminalSettings -Overlay $terminalOverlay
$terminalJson = $terminalSettings | ConvertTo-Json -Depth 100
Write-ManagedText -Destination $terminalSettingsPath -Content "$terminalJson`n"

Copy-ManagedFile `
    -Source (Join-Path $PSScriptRoot 'WindowsTerminal\copilot.fragment.json') `
    -Destination (
        Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\MyDotFiles\copilot.fragment.json'
    )

if (-not $SkipCopilotConfiguration) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    Copy-ManagedFile `
        -Source (Join-Path $repoRoot 'Linux\copilot\copilot-instructions.md') `
        -Destination (Join-Path $HOME '.copilot\copilot-instructions.md')

    $copilotCandidates = @(
        (Get-Command copilot.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\copilot.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    $copilotPath = $copilotCandidates | Select-Object -First 1
    if (-not $copilotPath) {
        throw 'GitHub Copilot CLI was not found after package provisioning.'
    }

    $inheritedGitExecPath = $env:GIT_EXEC_PATH
    Remove-Item Env:GIT_EXEC_PATH -ErrorAction SilentlyContinue
    try {
        $marketplaceListing = @(& $copilotPath plugin marketplace list 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "Copilot marketplace listing failed with code $LASTEXITCODE."
        }
        if (($marketplaceListing -join "`n") -notmatch '\bsinmentis\s+\(') {
            & $copilotPath plugin marketplace add sinmentis/MyDotFiles
            if ($LASTEXITCODE -ne 0) {
                throw "Copilot marketplace installation failed with code $LASTEXITCODE."
            }
        }

        $pluginListing = @(& $copilotPath plugin list 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "Copilot plugin listing failed with code $LASTEXITCODE."
        }
        if (($pluginListing -join "`n") -notmatch 'shunbox@sinmentis') {
            & $copilotPath plugin install shunbox@sinmentis
            if ($LASTEXITCODE -ne 0) {
                throw "Copilot plugin installation failed with code $LASTEXITCODE."
            }
        }
    }
    finally {
        if ($null -ne $inheritedGitExecPath) {
            $env:GIT_EXEC_PATH = $inheritedGitExecPath
        }
        else {
            Remove-Item Env:GIT_EXEC_PATH -ErrorAction SilentlyContinue
        }
    }
}

if (-not $SkipExtensions) {
    $codeCandidates = @(
        (Get-Command code.cmd -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1),
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'),
        (Join-Path $env:ProgramFiles 'Microsoft VS Code\bin\code.cmd')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    $codePath = $codeCandidates | Select-Object -First 1
    if (-not $codePath) {
        throw 'VS Code CLI was not found after package provisioning.'
    }

    $installedExtensions = @(& $codePath --list-extensions)
    if ($LASTEXITCODE -ne 0) {
        throw "VS Code extension listing failed with code $LASTEXITCODE."
    }

    $extensions = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'vscode-extensions.txt') |
        Where-Object { $_ -and -not $_.StartsWith('#') }
    foreach ($extension in $extensions) {
        if ($installedExtensions -notcontains $extension) {
            & $codePath --install-extension $extension --force
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to install VS Code extension $extension."
            }
        }
    }
}

Write-Host 'User-level PowerShell, Git, Terminal, and VS Code configuration completed.'
