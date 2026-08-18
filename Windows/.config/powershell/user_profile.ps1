# PowerShell 7 profile managed by MyDotFiles.

$utf8NoBom = [Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$modules = @('PSReadLine', 'PSFzf', 'Terminal-Icons', 'posh-git')
foreach ($module in $modules) {
    if (Get-Module -ListAvailable -Name $module) {
        Import-Module -Name $module
    }
    else {
        Write-Warning "PowerShell module is not installed: $module"
    }
}

$interactiveConsole = (
    $Host.Name -eq 'ConsoleHost' -and
    $Host.UI.SupportsVirtualTerminal -and
    -not [Console]::IsInputRedirected -and
    -not [Console]::IsOutputRedirected
)

if ($interactiveConsole -and (Get-Module -Name PSReadLine)) {
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

if ($interactiveConsole -and (Get-Command Set-PsFzfOption -ErrorAction SilentlyContinue)) {
    Set-PsFzfOption `
        -PSReadlineChordProvider 'Ctrl+f' `
        -PSReadlineChordReverseHistory 'Ctrl+r'
}

if ($interactiveConsole) {
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        Invoke-Expression (& starship init powershell)
    }
    else {
        Write-Warning 'starship is not installed.'
    }

    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        Invoke-Expression (& { zoxide init powershell | Out-String })
    }
    else {
        Write-Warning 'zoxide is not installed.'
    }
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
