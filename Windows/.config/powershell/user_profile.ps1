# PowerShell 7 profile managed by MyDotFiles.

$utf8NoBom = [Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$interactiveConsole = (
    $Host.Name -eq 'ConsoleHost' -and
    $Host.UI.SupportsVirtualTerminal -and
    -not [Console]::IsInputRedirected -and
    -not [Console]::IsOutputRedirected
)

# Each of these modules adds about a second to startup, so load them after the
# first prompt is shown. Starship already renders Git status, replacing posh-git.
if ($interactiveConsole) {
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        foreach ($module in @('Terminal-Icons', 'PSFzf')) {
            if (Get-Module -ListAvailable -Name $module) {
                Import-Module -Name $module -Global
            }
            else {
                Write-Warning "PowerShell module is not installed: $module"
            }
        }
        if (Get-Command Set-PsFzfOption -ErrorAction SilentlyContinue) {
            Set-PsFzfOption `
                -PSReadlineChordProvider 'Ctrl+f' `
                -PSReadlineChordReverseHistory 'Ctrl+r'
        }
    }
}

# Cache shell init scripts and regenerate them when the tool is updated.
function Get-CachedInitScript {
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [scriptblock]$Generate
    )

    $executable = Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $executable) {
        Write-Warning "$Command is not installed."
        return $null
    }

    $cache = Join-Path $env:LOCALAPPDATA "MyDotFiles\$Command-init.ps1"
    if (
        -not (Test-Path -LiteralPath $cache) -or
        (Get-Item -LiteralPath $cache).LastWriteTimeUtc -lt
            (Get-Item -LiteralPath $executable.Source).LastWriteTimeUtc
    ) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $cache) -Force | Out-Null
        [IO.File]::WriteAllText($cache, (& $Generate | Out-String), $utf8NoBom)
    }
    return $cache
}

if ($interactiveConsole -and (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue)) {
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle InlineView
    Set-PSReadLineOption -Colors @{
        Command          = 'Green'
        Keyword          = 'Yellow'
        Operator         = 'Magenta'
        Variable         = 'Blue'
        Parameter        = 'Cyan'
        InlinePrediction = 'DarkGray'
    }

    Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
}

if ($interactiveConsole) {
    $starshipInit = Get-CachedInitScript -Command starship -Generate {
        & starship init powershell --print-full-init
    }
    if ($starshipInit) { . $starshipInit }

    $zoxideInit = Get-CachedInitScript -Command zoxide -Generate {
        & zoxide init powershell
    }
    if ($zoxideInit) { . $zoxideInit }
}

function ll {
    Get-ChildItem @args | Format-Table -AutoSize
}

function la {
    Get-ChildItem -Force @args
}

function l {
    Get-ChildItem @args
}

function Set-LocationUp {
    Set-Location ..
}

function Set-LocationUpTwo {
    Set-Location ..\..
}

Set-Alias -Name .. -Value Set-LocationUp
Set-Alias -Name ... -Value Set-LocationUpTwo
Set-Alias -Name c -Value Clear-Host

function which {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Command
    )

    Get-Command $Command
}

function TreeG {
    [CmdletBinding()]
    param(
        [ValidateRange(1, 20)]
        [int]$Level = 3,

        [string]$Path = '.'
    )

    & eza --tree "--level=$Level" --git-ignore --group-directories-first -- $Path
    if ($LASTEXITCODE -ne 0) {
        throw "eza failed with code $LASTEXITCODE."
    }
}

function Merge-FilesByExtension {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9]+$')]
        [string]$Extension
    )

    $outputFile = Join-Path (Get-Location) "combined_$Extension.txt"
    $excludedDirectories = '\\(\.git|\.venv|node_modules|dist|build)\\'
    $files = @(
        Get-ChildItem -LiteralPath . -Recurse -File -Filter "*.$Extension" |
            Where-Object {
                $_.FullName -ne $outputFile -and
                $_.FullName -notmatch $excludedDirectories
            }
    )

    if ($files.Count -eq 0) {
        Write-Warning "No files found with extension .$Extension"
        return
    }

    $writer = [IO.StreamWriter]::new($outputFile, $false, $utf8NoBom)
    try {
        foreach ($file in $files) {
            $writer.WriteLine("===== $($file.FullName) =====")
            $writer.WriteLine([IO.File]::ReadAllText($file.FullName))
        }
    }
    finally {
        $writer.Dispose()
    }

    Write-Host "Merged $($files.Count) files into $outputFile"
}
