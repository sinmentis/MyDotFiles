BeforeAll {
    . (Join-Path $PSScriptRoot '..\configure-user.ps1') -TestFunctionsOnly
}

Describe 'Merge-Hashtable' {
    It 'keeps a single overlay entry as an array' {
        $target = [ordered]@{ actions = @() }
        $overlay = [ordered]@{
            actions = @(
                [ordered]@{ keys = 'ctrl+`'; command = 'quakeMode' }
            )
        }

        Merge-Hashtable -Target $target -Overlay $overlay

        $target.actions.GetType().FullName | Should -Be 'System.Object[]'
        $target.actions.Count | Should -Be 1
    }

    It 'preserves unrelated Terminal actions and replaces matching bindings' {
        $target = [ordered]@{
            actions = @(
                [ordered]@{ keys = 'ctrl+c'; command = 'copy' }
            )
            keybindings = @(
                [ordered]@{ id = 'existing'; keys = 'ctrl+x' }
            )
        }
        $overlay = [ordered]@{
            actions = @(
                [ordered]@{
                    keys = 'ctrl+`'
                    command = [ordered]@{ action = 'quakeMode' }
                }
            )
            keybindings = @(
                [ordered]@{ id = 'existing'; keys = 'alt+x' },
                [ordered]@{ id = 'new'; keys = 'alt+n' }
            )
        }

        Merge-Hashtable -Target $target -Overlay $overlay

        $target.actions.Count | Should -Be 2
        $target.keybindings.Count | Should -Be 2
        $target.keybindings[0].keys | Should -Be 'alt+x'
    }

    It 'is idempotent when the same overlay is applied twice' {
        $target = [ordered]@{ actions = @() }
        $overlay = [ordered]@{
            actions = @(
                [ordered]@{ keys = 'ctrl+`'; command = 'quakeMode' }
            )
        }

        Merge-Hashtable -Target $target -Overlay $overlay
        Merge-Hashtable -Target $target -Overlay $overlay

        $target.actions.Count | Should -Be 1
    }
}

Describe 'Copy-ManagedFile' {
    It 'does not overwrite a seeded local file' {
        $source = Join-Path $TestDrive 'example'
        $destination = Join-Path $TestDrive 'local'
        Set-Content -LiteralPath $source -Value 'example'
        Set-Content -LiteralPath $destination -Value 'private'

        Copy-ManagedFile -Source $source -Destination $destination -SeedOnly

        Get-Content -LiteralPath $destination -Raw | Should -Match '^private'
    }
}
