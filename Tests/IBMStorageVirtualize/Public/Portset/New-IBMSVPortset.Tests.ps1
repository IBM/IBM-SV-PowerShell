Describe "New-IBMSVPortset Tests" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd, $CmdArgs)

            $script:callCount++

            if ($Cmd -eq "lsportset") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                return [pscustomobject]@{
                    name = $CmdArgs
                    id = '0'
                    type = 'host'
                    port_type = 'fc'
                    owner_name = ''
                }
            }

            if ($Cmd -eq "mkportset") {
                return [pscustomobject]@{ id = '0'; message = 'Portset created successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when ReplicationPortsetLinkUid format is invalid" {
        { New-IBMSVPortset -Name "portset0" -ReplicationPortsetLinkUid "INVALID" } | Should -Throw "Parameter -ReplicationPortsetLinkUid must be a 32-character hexadecimal string."
    }

    It "Should not call API to create portset when -WhatIf is specified" {
        New-IBMSVPortset -Name "portset0" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should create a portset with required parameters only (default to host type and ethernet)" {
        $result = New-IBMSVPortset -Name "portset0"
        $result.name | Should -Be 'portset0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsportset" -and $CmdArgs -contains "portset0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkportset" -and
                $CmdOpts.name -eq "portset0"
            }
    }

    It "Should be idempotent when portset already exists" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsportset") {
                return [pscustomobject]@{
                    name = 'portset0'
                    id = '0'
                    type = 'host'
                    port_type = 'ethernet'
                }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVPortset -Name "portset0"
        $result.name | Should -Be 'portset0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsportset" -and $CmdArgs -contains "portset0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkportset" }
    }

    It "Should create a FC portset with -PortType" {
        $result = New-IBMSVPortset -Name "portset0" -PortType "fc"
        $result.name | Should -Be 'portset0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsportset" -and $CmdArgs -contains "portset0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkportset" -and
                $CmdOpts.name -eq "portset0" -and
                $CmdOpts.porttype -eq "fc"
            }
    }

    It "Should create a portset with all suppported optional parameters" {
        $result = New-IBMSVPortset -Name "portset0" -PortType "fc" -Type "host" -OwnershipGroup "pwsh_og" -ReplicationPortsetLinkUid "F8C5C02FC24F019154B57B59DD753BFF"
        $result.name | Should -Be 'portset0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsportset" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkportset" -and
                $CmdOpts.name -eq "portset0" -and
                $CmdOpts.type -eq "host" -and
                $CmdOpts.porttype -eq "fc" -and
                $CmdOpts.ownershipgroup -eq "pwsh_og" -and
                $CmdOpts.replicationportsetlinkuid -eq "F8C5C02FC24F019154B57B59DD753BFF"
            }
    }
}
