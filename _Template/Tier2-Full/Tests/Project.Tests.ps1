<#
    Pester tests for <Project-Name>.

    Run:  Invoke-Pester .\Tests\Project.Tests.ps1

    Pester keeps the .Tests.ps1 suffix by convention; it is discovered by name,
    so this file is exempt from the Verb-Noun rule.
#>

BeforeAll {
    $script:ScriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Verb-Noun.ps1'
}

Describe 'Verb-Noun.ps1' {

    Context 'Static analysis' {

        It 'exists' {
            Test-Path -LiteralPath $script:ScriptPath | Should -BeTrue
        }

        It 'parses without syntax errors' {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $script:ScriptPath, [ref]$null, [ref]$errors) | Out-Null
            $errors.Count | Should -Be 0
        }

        It 'contains only ASCII characters' {
            $content = [System.IO.File]::ReadAllText($script:ScriptPath)
            $content | Should -Not -Match '[^\x00-\x7F]'
        }

        It 'has comment-based help with a synopsis' {
            $help = Get-Help $script:ScriptPath -ErrorAction SilentlyContinue
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It 'hardcodes no GUIDs that could be tenant identifiers' {
            $content = [System.IO.File]::ReadAllText($script:ScriptPath)
            $content | Should -Not -Match '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
        }
    }

    Context 'Behaviour' {

        It 'supports -WhatIf' -Skip {
            # Replace with real coverage for this project.
        }
    }
}
