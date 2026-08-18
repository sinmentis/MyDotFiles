[CmdletBinding()]
param(
    [switch]$EnableWsl,
    [switch]$EnableDeveloperMode,
    [switch]$SkipPackages,
    [switch]$SkipUserConfiguration,
    [switch]$SkipSystemSettings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,

        [int[]]$SuccessExitCode = @(0)
    )

    & $FilePath @ArgumentList
    $exitCode = $LASTEXITCODE
    if ($SuccessExitCode -notcontains $exitCode) {
        throw "$FilePath exited with code $exitCode."
    }
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WinGetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    & $script:WingetPath list --id $Id --exact --source winget --accept-source-agreements 2>$null |
        Out-Null
    return ($LASTEXITCODE -eq 0)
}

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) {
    throw 'WinGet is required. Install or update App Installer from Microsoft Store.'
}

$script:WingetPath = $winget.Source
$userConfigurationPath = Join-Path $PSScriptRoot 'configure-user.ps1'
$runSystemActions = (
    -not $SkipPackages -or
    -not $SkipSystemSettings -or
    $EnableDeveloperMode -or
    $EnableWsl
)

if ($runSystemActions -and -not (Test-Administrator)) {
    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $elevatedArguments = @(
        '-NoLogo',
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $PSCommandPath),
        '-SkipUserConfiguration'
    )
    if ($EnableWsl) { $elevatedArguments += '-EnableWsl' }
    if ($EnableDeveloperMode) { $elevatedArguments += '-EnableDeveloperMode' }
    if ($SkipPackages) { $elevatedArguments += '-SkipPackages' }
    if ($SkipSystemSettings) { $elevatedArguments += '-SkipSystemSettings' }

    Write-Host 'Requesting elevation for packages and system settings...'
    $elevatedProcess = Start-Process `
        -FilePath $windowsPowerShell `
        -ArgumentList $elevatedArguments `
        -Verb RunAs `
        -Wait `
        -PassThru
    if ($elevatedProcess.ExitCode -ne 0) {
        throw "Elevated bootstrap failed with code $($elevatedProcess.ExitCode)."
    }
    $runSystemActions = $false
}

if ($runSystemActions -and -not $SkipPackages) {
    $packageManifest = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'packages.psd1')
    $packages = $packageManifest.Packages
    foreach ($package in $packages) {
        if (Test-WinGetPackage -Id $package) {
            if ($package -eq 'Microsoft.PowerShell') {
                Invoke-NativeCommand -FilePath $script:WingetPath -ArgumentList @(
                    'upgrade',
                    '--id', $package,
                    '--exact',
                    '--source', 'winget',
                    '--silent',
                    '--disable-interactivity',
                    '--accept-package-agreements',
                    '--accept-source-agreements'
                ) -SuccessExitCode @(0, 3010, -1978335189)
            }
            Write-Host "Already installed: $package"
            continue
        }

        Invoke-NativeCommand -FilePath $script:WingetPath -ArgumentList @(
            'install',
            '--id', $package,
            '--exact',
            '--source', 'winget',
            '--silent',
            '--disable-interactivity',
            '--accept-package-agreements',
            '--accept-source-agreements'
        ) -SuccessExitCode @(0, 3010, -1978335189)
    }
}

if ($runSystemActions -and -not $SkipSystemSettings) {
    New-ItemProperty `
        -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' `
        -Name LongPathsEnabled `
        -PropertyType DWord `
        -Value 1 `
        -Force | Out-Null
}

if ($runSystemActions -and $EnableDeveloperMode) {
    $developerModePath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    New-Item -Path $developerModePath -Force | Out-Null
    New-ItemProperty `
        -Path $developerModePath `
        -Name AllowDevelopmentWithoutDevLicense `
        -PropertyType DWord `
        -Value 1 `
        -Force | Out-Null
}

if (-not $SkipUserConfiguration) {
    $pwshPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
    if (-not (Test-Path -LiteralPath $pwshPath)) {
        $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
        if (-not $pwsh) {
            throw 'PowerShell 7 was not found after package provisioning.'
        }
        $pwshPath = $pwsh.Source
    }

    Invoke-NativeCommand -FilePath $pwshPath -ArgumentList @(
        '-NoLogo',
        '-NoProfile',
        '-File', $userConfigurationPath
    )
}

if ($runSystemActions -and $EnableWsl) {
    Invoke-NativeCommand -FilePath (Join-Path $env:SystemRoot 'System32\wsl.exe') `
        -ArgumentList @('--install', '--no-distribution') `
        -SuccessExitCode @(0, 3010)
    Write-Warning 'WSL platform changes may require a restart. No Linux distribution was installed or modified.'
}

Write-Host 'Windows host configuration completed.'
if (-not $EnableWsl) {
    Write-Host 'WSL was left unchanged. Re-run with -EnableWsl from an elevated PowerShell when ready.'
}
