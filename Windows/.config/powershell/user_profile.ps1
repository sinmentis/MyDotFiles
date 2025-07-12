# ------------------------------------------------------------------
#  PowerShell 7 profile – minimal zsh-like experience
# ------------------------------------------------------------------

# ---------- Modules ----------
Import-Module -Name Terminal-Icons
Import-Module -Name PSReadLine
Import-Module -Name PSFzf
Import-Module -Name posh-git

# ---------- Prompt ----------
Invoke-Expression (&starship init powershell)
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# ---------- PSReadLine ----------
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

# Keybindings
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineKeyHandler -Key   Tab      -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo

# ---------- zsh-style partial suggestion (Ctrl+→ / Ctrl+←) ----------
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler    -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler    -Chord 'Ctrl+LeftArrow'  -Function BackwardWord

# ---------- Aliases ----------
New-Alias -Name ll -Value Get-ChildItem -Description "List items with details"
New-Alias -Name la -Value Get-ChildItem -Force -Description "List all items including hidden"
New-Alias -Name l  -Value Get-ChildItem -Description "Alias for ls"
New-Alias -Name .. -Value "Set-Location .."
New-Alias -Name ... -Value "Set-Location ../.."
New-Alias -Name c -Value Clear-Host
New-Alias -Name grep -Value "Select-String"
New-Alias -Name which -Value "Get-Command"

# ---------- Lightweight helpers ----------
function which($command) {
    Get-Command $command | Select-Object -ExpandProperty Source
}

filter xcall { param($exe) & $exe @args }

# ---------- Heavy functions moved to module ----------
function TreeG {
    [CmdletBinding()]
    param(
        [int]    $Level = 3,
        [string] $Path  = "."
    )

    # ROOT directory
    $root = (Resolve-Path $Path).ProviderPath

    # Retrieve all ignored items (including directories) at once
    $raw = & git ls-files --others --ignored --exclude-standard --directory -z
    if (-not $raw) {
        Write-Warning "git ls-files returned nothing. Is this a Git repo?"
        return
    }
    $ignoredSet = ($raw -split "`0" | Where-Object { $_ -ne "" }) | ForEach-Object { Join-Path $root $_ }
    $ignored = [System.Collections.Generic.HashSet[string]]::new(
        $ignoredSet, [System.StringComparer]::InvariantCultureIgnoreCase
    )

    $script:PrefixStack = @()

    function Recurse {
        param([string] $Dir, [int] $Depth)

        $items = Get-ChildItem -LiteralPath $Dir |
                 Sort-Object @{Expression={$_.PSIsContainer};Descending=$true}, Name

        for ($i=0; $i -lt $items.Count; $i++) {
            $item   = $items[$i]
            $isLast = ($i -eq $items.Count - 1)
            $prefix = $PrefixStack -join ""

            # Skip ignored items
            if ($ignored.Contains($item.FullName)) { continue }

            if ($isLast) { "$prefix+-- $($item.Name)" }
            else         { "$prefix|-- $($item.Name)" }

            if ($item.PSIsContainer -and $Depth -gt 1) {
                if ($isLast) { $PrefixStack += "   " }
                else          { $PrefixStack += "|   " }

                Recurse $item.FullName ($Depth - 1)

                # Pop
                $PrefixStack = $PrefixStack[0..($PrefixStack.Count - 2)]
            }
        }
    }

    Write-Host $root
    Recurse $root $Level
}

function Merge-FilesByExtension {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Extension
    )
    # 递归查找，先拿到所有目标文件
    $files = Get-ChildItem -Path . -Recurse -Filter "*.$Extension" -File |
        Where-Object { $_.FullName -notmatch '\\.venv\\' }

    if ($files.Count -eq 0) {
        Write-Host "No files found with extension .$Extension" -ForegroundColor Yellow
        return
    }

    Write-Host "Found files:" -ForegroundColor Cyan
    foreach ($file in $files) {
        $indentLevel = ($file.FullName -Split '\\').Count - 2
        $indent = ' ' * ($indentLevel * 3)
        Write-Host "$indent$file"
    }

    $outputFile = "combined_$Extension.txt"
    if (Test-Path $outputFile) { Remove-Item $outputFile }
    foreach ($file in $files) {
        Add-Content -Path $outputFile -Value ("===== " + $file.FullName + " =====")
        Get-Content -Path $file.FullName | Add-Content -Path $outputFile
    }
    Write-Host "Merged into $outputFile" -ForegroundColor Green
}

