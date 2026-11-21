<#
    Pester tests for DesktopPolicy-Guard.

    Run:
        Invoke-Pester .\Tests\DesktopPolicy-Guard.Tests.ps1
#>

BeforeAll {
    $script:ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:Scripts = @(
        'Install-DesktopPolicyGuard.ps1'
        'Install-DesktopPolicyGuardService.ps1'
        'Start-DesktopPolicyGuard.ps1'
        'Remove-DesktopPolicyGuardService.ps1'
        'Test-DesktopPolicyGuard.ps1'
        'Install-AppUpdateMaintenance.ps1'
        'Start-AppUpdateMaintenance.ps1'
        'Remove-AppUpdateMaintenance.ps1'
        'Test-AppUpdateMaintenance.ps1'
    )
    $script:ConfigPath = Join-Path $script:ProjectRoot 'Config\config.example.json'
}

Describe 'DesktopPolicy-Guard static validation' {
    foreach ($scriptName in $script:Scripts) {
        Context $scriptName {
            $scriptPath = Join-Path $script:ProjectRoot $scriptName

            It 'exists' {
                Test-Path -LiteralPath $scriptPath | Should -BeTrue
            }

            It 'parses without syntax errors' {
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile(
                    $scriptPath,
                    [ref]$null,
                    [ref]$errors
                ) | Out-Null
                $errors.Count | Should -Be 0
            }

            It 'contains only ASCII characters' {
                $content = [System.IO.File]::ReadAllText($scriptPath)
                $content | Should -Not -Match '[^\x00-\x7F]'
            }

            It 'contains no hardcoded GUIDs' {
                $content = [System.IO.File]::ReadAllText($scriptPath)
                $content | Should -Not -Match '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
            }
        }
    }

    Context 'Configuration' {
        It 'contains valid JSON' {
            {
                Get-Content -LiteralPath $script:ConfigPath -Raw |
                    ConvertFrom-Json |
                    Out-Null
            } | Should -Not -Throw
        }

        It 'ships with shortcut removal disabled' {
            $config = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json
            $config.RemoveShortcuts | Should -BeFalse
        }

        It 'ships with app updates disabled' {
            $config = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json
            $config.AppUpdates.Enabled | Should -BeFalse
        }

        It 'excludes PowerShell from automated updates by default' {
            $config = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json
            @($config.AppUpdates.ExcludedPackages) | Should -Contain 'Microsoft.PowerShell'
        }

        It 'uses a supported app update mode' {
            $config = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json
            $config.AppUpdates.Mode | Should -BeIn @('All', 'AllowList')
        }
    }
}
