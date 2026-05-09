Describe "New-IBMSVVolumeGroup Tests" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsvolumegroup") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                return [pscustomobject]@{ name='pwsh_vg0'; id='0' }
            }

            if ($Cmd -eq "mkvolumegroup") {
                return [pscustomobject]@{ id = '0'; message = 'Volume group created successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when OwnershipGroup and SafeguardedPolicy are both specified" {
        { New-IBMSVVolumeGroup -Name "pwsh_vg0" -OwnershipGroup "pwsh_og" -SafeguardedPolicy "pwsh_sgp" } | Should -Throw "Parameters OwnershipGroup, SafeguardedPolicy are mutually exclusive."
    }

    It "Should throw error when OwnershipGroup and SnapshotPolicy are both specified" {
        { New-IBMSVVolumeGroup -Name "pwsh_vg0" -OwnershipGroup "pwsh_og" -SnapshotPolicy "pwsh_sp" } | Should -Throw "Parameters OwnershipGroup, SnapshotPolicy are mutually exclusive."
    }

    It "Should throw error when Safeguarded and SafeguardedPolicy are both specified" {
        { New-IBMSVVolumeGroup -Name "pwsh_vg0" -Safeguarded -SafeguardedPolicy "pwsh_sgp" } | Should -Throw "Parameters Safeguarded, SafeguardedPolicy are mutually exclusive."
    }

    It "Should throw error when Partition and DraftPartition are both specified" {
        { New-IBMSVVolumeGroup -Name "pwsh_vg0" -Partition "pwsh_ptn" -DraftPartition "ptn0" } | Should -Throw "Parameters Partition, DraftPartition are mutually exclusive."
    }

    It "Should throw error when ReplicationPolicy and DraftPartition are both specified" {
        { New-IBMSVVolumeGroup -Name "pwsh_vg0" -ReplicationPolicy "pwsh_rp" -DraftPartition "ptn0" } | Should -Throw "Parameters ReplicationPolicy, DraftPartition are mutually exclusive."
    }

    It "Should throw error when SafeguardedPolicy and SetPartitionDefault are both specified" {
        { New-IBMSVVolumeGroup -Name "pwsh_vg0" -SafeguardedPolicy "pwsh_sgp" -SetPartitionDefault } | Should -Throw "Parameters SafeguardedPolicy, SetPartitionDefault are mutually exclusive."
    }

    It "Should throw error when ReplicationPolicy and SetPartitionDefault are both specified" {
        { New-IBMSVVolumeGroup -Name "pwsh_vg0" -ReplicationPolicy "pwsh_rp" -SetPartitionDefault } | Should -Throw "Parameters ReplicationPolicy, SetPartitionDefault are mutually exclusive."
    }

    It "Should throw error when SnapshotPolicy and SetPartitionDefault are both specified" {
        { New-IBMSVVolumeGroup -Name "pwsh_vg0" -SnapshotPolicy "pwsh_sp" -SetPartitionDefault } | Should -Throw "Parameters SnapshotPolicy, SetPartitionDefault are mutually exclusive."
    }

    It "Should throw error when PolicyStartTime is provided without SafeguardedPolicy or SnapshotPolicy" {
        { New-IBMSVVolumeGroup -Name "pwsh_vg0" -PolicyStartTime "2203011800" } | Should -Throw "Parameter -PolicyStartTime is invalid without -SafeguardedPolicy or -SnapshotPolicy."
    }

    It "Should throw error when Safeguarded is set without SnapshotPolicy" {
        { New-IBMSVVolumeGroup -Name "pwsh_vg0" -Safeguarded } | Should -Throw "Parameter -Safeguarded is invalid without -SnapshotPolicy."
    }

    It "Should not call API to create volume group when -WhatIf is specified" {
        New-IBMSVVolumeGroup -Name "pwsh_vg0" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should create a volume group with required parameters" {
        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0"
        $result.name | Should -Be 'pwsh_vg0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumegroup" -and
                $CmdOpts.name -eq "pwsh_vg0"
            }
    }

    It "Should be idempotent when volume group already exists" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvolumegroup") {
                return [pscustomobject]@{ name='pwsh_vg0'; id='0' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0"
        $result.name | Should -Be 'pwsh_vg0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkvolumegroup" }
    }

    It "Should create a volume group with OwnershipGroup parameter" {
        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0" -OwnershipGroup "pwsh_og"
        $result.name | Should -Be 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumegroup" -and
                $CmdOpts.name -eq "pwsh_vg0" -and
                $CmdOpts.ownershipgroup -eq "pwsh_og"
            }
    }

    It "Should create a volume group with Partition parameter" {
        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0" -Partition "pwsh_ptn"
        $result.name | Should -Be 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumegroup" -and
                $CmdOpts.name -eq "pwsh_vg0" -and
                $CmdOpts.partition -eq "pwsh_ptn"
            }
    }

    It "Should create a volume group with IgnoreUserFCMaps parameter" {
        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0" -IgnoreUserFCMaps
        $result.name | Should -Be 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumegroup" -and
                $CmdOpts.name -eq "pwsh_vg0" -and
                $CmdOpts.ignoreuserfcmaps -eq $true
            }
    }

    It "Should create a volume group with SnapshotPolicy parameter" {
        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0" -SnapshotPolicy "pwsh_sp"
        $result.name | Should -Be 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumegroup" -and
                $CmdOpts.name -eq "pwsh_vg0" -and
                $CmdOpts.snapshotpolicy -eq "pwsh_sp"
            }
    }

    It "Should create a volume group with ReplicationPolicy parameter" {
        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0" -ReplicationPolicy "pwsh_rp"
        $result.name | Should -Be 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumegroup" -and
                $CmdOpts.name -eq "pwsh_vg0" -and
                $CmdOpts.replicationpolicy -eq "pwsh_rp"
            }
    }

    It "Should create a volume group with SafeguardedPolicy parameter" {
        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0" -SafeguardedPolicy "pwsh_sgp"
        $result.name | Should -Be 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumegroup" -and
                $CmdOpts.name -eq "pwsh_vg0" -and
                $CmdOpts.safeguardedpolicy -eq "pwsh_sgp"
            }
    }

    It "Should create a volume group with SafeguardedPolicy and PolicyStartTime parameters" {
        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0" -SafeguardedPolicy "pwsh_sgp" -PolicyStartTime "2203011800"
        $result.name | Should -Be 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumegroup" -and
                $CmdOpts.name -eq "pwsh_vg0" -and
                $CmdOpts.safeguardedpolicy -eq "pwsh_sgp" -and
                $CmdOpts.policystarttime -eq "2203011800"
            }
    }

    It "Should create a safeguarded volume group with SnapshotPolicy" {
        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0" -SnapshotPolicy "pwsh_sp" -Safeguarded
        $result.name | Should -Be 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumegroup" -and
                $CmdOpts.name -eq "pwsh_vg0" -and
                $CmdOpts.snapshotpolicy -eq "pwsh_sp" -and
                $CmdOpts.safeguarded -eq $true
            }
    }

    It "Should create a volume group with DraftPartition parameter" {
        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0" -DraftPartition "ptn0"
        $result.name | Should -Be 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumegroup" -and
                $CmdOpts.name -eq "pwsh_vg0" -and
                $CmdOpts.draftpartition -eq "ptn0"
            }
    }

    It "Should create a volume group with SetPartitionDefault parameter" {
        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0" -SetPartitionDefault
        $result.name | Should -Be 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumegroup" -and
                $CmdOpts.name -eq "pwsh_vg0" -and
                $CmdOpts.setpartitiondefault -eq $true
            }
    }

    It "Should create a volume group with SnapshotPolicy and ReplicationPolicy" {
        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0" -SnapshotPolicy "pwsh_sp" -ReplicationPolicy "pwsh_rp"
        $result.name | Should -Be 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumegroup" -and
                $CmdOpts.name -eq "pwsh_vg0" -and
                $CmdOpts.snapshotpolicy -eq "pwsh_sp" -and
                $CmdOpts.replicationpolicy -eq "pwsh_rp"
            }
    }

    It "Should create a volume group with multiple parameters" {
        $result = New-IBMSVVolumeGroup -Name "pwsh_vg0" -SnapshotPolicy "pwsh_sp" -Safeguarded -IgnoreUserFCMaps -ReplicationPolicy "pwsh_rp" -PolicyStartTime "2203011800"
        $result.name | Should -Be 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumegroup" -and
                $CmdOpts.name -eq "pwsh_vg0" -and
                $CmdOpts.snapshotpolicy -eq "pwsh_sp" -and
                $CmdOpts.safeguarded -eq $true -and
                $CmdOpts.ignoreuserfcmaps -eq $true -and
                $CmdOpts.replicationpolicy -eq "pwsh_rp" -and
                $CmdOpts.policystarttime -eq "2203011800"
            }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            return [pscustomobject]@{
                url  = "https://1.1.1.1:7443/rest/v1/mkvolumegroup"
                code = 500
                err  = "HTTPError failed"
                out  = @{}
                data = @{}
            }
        } -ModuleName IBMStorageVirtualize

        { New-IBMSVVolumeGroup -Name "pwsh_vg0" } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/mkvolumegroup"
    }
}
