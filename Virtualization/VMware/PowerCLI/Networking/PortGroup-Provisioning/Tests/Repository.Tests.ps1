BeforeAll {
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
    $ConfigPath  = Join-Path -Path $ProjectRoot -ChildPath 'Config'

    $StandardScript    = Join-Path -Path $ProjectRoot -ChildPath 'New-StandardSwitchPortGroups.ps1'
    $DistributedScript = Join-Path -Path $ProjectRoot -ChildPath 'New-DistributedPortGroups.ps1'
}

Describe 'Repository structure' {
    It 'contains both PowerCLI scripts in the project root' {
        $StandardScript | Should -Exist
        $DistributedScript | Should -Exist
    }

    It 'contains both example CSV templates' {
        (Join-Path $ConfigPath 'portgroups.example.csv') | Should -Exist
        (Join-Path $ConfigPath 'vdsportgroups.example.csv') | Should -Exist
    }
}

Describe 'CSV templates' {
    It 'has the expected standard networking headers' {
        $Headers = (Get-Content (Join-Path $ConfigPath 'portgroups.example.csv') -First 1).Trim()
        $Headers | Should -Be 'vSwitchName,PortGroup,VlanID'
    }

    It 'has the expected distributed networking headers' {
        $Headers = (Get-Content (Join-Path $ConfigPath 'vdsportgroups.example.csv') -First 1).Trim()
        $Headers | Should -Be 'vdsName,PortGroup,VlanID'
    }
}

Describe 'PowerShell script standards' {
    foreach ($ScriptPath in @($StandardScript, $DistributedScript)) {
        It "uses relative paths in $(Split-Path $ScriptPath -Leaf)" {
            (Get-Content $ScriptPath -Raw) | Should -Match '\$PSScriptRoot'
        }

        It "supports WhatIf in $(Split-Path $ScriptPath -Leaf)" {
            (Get-Content $ScriptPath -Raw) | Should -Match 'SupportsShouldProcess\s*=\s*\$true'
        }

        It "does not contain a hardcoded user profile path in $(Split-Path $ScriptPath -Leaf)" {
            (Get-Content $ScriptPath -Raw) | Should -Not -Match '(?i)C:\\\\Users\\\\'
        }

        It "identifies Joel Cottrell as the author in $(Split-Path $ScriptPath -Leaf)" {
            (Get-Content $ScriptPath -Raw) | Should -Match 'Author\s*:\s*Joel Cottrell'
        }

    }
}
