Describe "Set-IBMSVPortset Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:callCount++
            if ($Cmd -eq 'lsportset') {
                if ($script:callCount -eq 1) {
                    return @{
                        name = 'portset0'
                        id = '0'
                        type = 'host'
                        port_type = 'ethernet'
                        owner_name = 'pwsh_og'
                        replication_portset_link_uid = 'F8C5C02FC24F019154B57B59DD753BFE'
                    }
                } else {
                    return $null
                }
            }
            if ($Cmd -eq 'chportset') {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        $script:callCount = 0
    }

    It "Should throw error when both OwnershipGroup and NoOwnershipGroup are specified" {
        { Set-IBMSVPortset -Name 'portset0' -OwnershipGroup 'pwsh_og' -NoOwnershipGroup } | Should -Throw "Parameters -OwnershipGroup, -NoOwnershipGroup are mutually exclusive."
    }

    It "Should throw error when both ReplicationPortsetLinkUID and ResetReplicationPortsetLinkUID are specified" {
        { Set-IBMSVPortset -Name 'portset0' -ReplicationPortsetLinkUID 'F8C5C02FC24F019154B57B59DD753BFF' -ResetReplicationPortsetLinkUID } | Should -Throw "Parameters -ReplicationPortsetLinkUID, -ResetReplicationPortsetLinkUID are mutually exclusive."
    }

    It "Should not call API to update portset group when -WhatIf is specified" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsportset') {
                return @{ name='portset0'; id='0'; owner_name='' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPortset -Name 'portset0' -OwnershipGroup 'pwsh_og' -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chportset' }
    }

    It "Should throw error when portset does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsportset') { return $null }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPortset -Name 'portset0' } | Should -Throw "Portset 'portset0' does not exist."
    }

    It "Should throw error when both portset does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsportset') { return $null }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPortset -Name 'portset0' -NewName 'portset1' } | Should -Throw "Portset 'portset0' does not exist."
    }

    It "Should rename the portset when NewName is different" {
        Set-IBMSVPortset -Name 'portset0' -NewName 'portset1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chportset' -and
                $CmdOpts.name -eq 'portset1' -and
                $CmdArgs -eq 'portset0'
            }
    }

    It "Should not throw error if -Name portset does not exist but -NewName portset exists and proceed to update other params on -NewName portset" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++
            if ($Cmd -eq 'lsportset' -and $script:callCount -eq 1) {
                return $null
            }
            elseif ($Cmd -eq 'lsportset' -and $script:callCount -eq 2) {
                return @{ name = 'portset1'; id = '1'; owner_name = '' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPortset -Name 'portset0' -NewName 'portset1' -OwnershipGroup 'pwsh_og'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chportset' -and
                $CmdOpts.ownershipgroup -eq 'pwsh_og' -and
                $CmdArgs -eq 'portset1'
            }
    }

    It "Should throw error if both -Name portset and -NewName portset exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++
            if ($Cmd -eq 'lsportset' -and $script:callCount -eq 1) {
                return @{ name = 'portset0'; id = '0' }
            }
            elseif ($Cmd -eq 'lsportset' -and $script:callCount -eq 2) {
                return @{ name = 'portset1'; id = '1' }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPortset -Name 'portset0' -NewName 'portset1' } | Should -Throw "Both 'portset0' and 'portset1' exist. Cannot rename, cannot proceed with other updates."
    }

    It "Should rename and update ownership group" {
        Set-IBMSVPortset -Name 'portset0' -NewName 'portset1' -OwnershipGroup 'pwsh_og1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chportset' -and
                $CmdOpts.name -eq 'portset1' -and
                $CmdOpts.ownershipgroup -eq 'pwsh_og1' -and
                $CmdArgs -eq 'portset0'
            }
    }

    It "Should update ownership group" {
        Set-IBMSVPortset -Name 'portset0' -OwnershipGroup 'pwsh_og1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chportset'
                $CmdOpts.ownershipgroup -eq 'pwsh_og1' -and
                $CmdArgs -eq 'portset0'
            }
    }

    It "Should remove ownership group" {
        Set-IBMSVPortset -Name 'portset0' -NoOwnershipGroup

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chportset' -and
                $CmdOpts.noownershipgroup -eq $true -and
                $CmdArgs -eq 'portset0'
            }
    }

    It "Should update replication portset link UID" {
        Set-IBMSVPortset -Name 'portset0' -ReplicationPortsetLinkUID 'F8C5C02FC24F019154B57B59DD753BFF'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chportset' -and
                $CmdOpts.replicationportsetlinkuid -eq 'F8C5C02FC24F019154B57B59DD753BFF' -and
                $CmdArgs -eq 'portset0'
            }
    }

    It "Should reset replication portset link UID" {
        Set-IBMSVPortset -Name 'portset0' -ResetReplicationPortsetLinkUID

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chportset' -and
                $CmdOpts.resetreplicationportsetlinkuid -eq $true -and
                $CmdArgs -eq 'portset0'
            }
    }

    It "Should update multiple properties at once" {
        Set-IBMSVPortset -Name 'portset0' -NewName 'portset1' -OwnershipGroup 'pwsh_og1' -ReplicationPortsetLinkUID 'F8C5C02FC24F019154B57B59DD753BFF'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chportset' -and
                $CmdOpts.name -eq 'portset1' -and
                $CmdOpts.ownershipgroup -eq 'pwsh_og1' -and
                $CmdOpts.replicationportsetlinkuid -eq 'F8C5C02FC24F019154B57B59DD753BFF' -and
                $CmdArgs -eq 'portset0'
            }
    }

    It "Should be idempotent when no changes are required" {
        Set-IBMSVPortset -Name 'portset0' -OwnershipGroup 'pwsh_og' -ReplicationPortsetLinkUID 'F8C5C02FC24F019154B57B59DD753BFE'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chportset' }
    }
}
