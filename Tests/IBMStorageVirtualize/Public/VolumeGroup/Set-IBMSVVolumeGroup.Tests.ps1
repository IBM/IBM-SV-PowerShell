Describe "Set-IBMSVVolumeGroup Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {} -ModuleName IBMStorageVirtualize
        Mock Get-IBMSVVersion { return "9.1.0.0" } -ModuleName IBMStorageVirtualize
        $script:count=0
    }

    It "Should throw error when OwnershipGroup and NoOwnershipGroup are both specified" {
        { Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -OwnershipGroup 'pwsh_og' -NoOwnershipGroup } | Should -Throw "Parameters OwnershipGroup, NoOwnershipGroup are mutually exclusive."
    }

    It "Should throw error when OwnershipGroup and SafeguardedPolicy are both specified" {
        { Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -OwnershipGroup 'pwsh_og' -SafeguardedPolicy 'pwsh_sgp' } | Should -Throw "Parameters OwnershipGroup, SafeguardedPolicy are mutually exclusive."
    }

    It "Should throw error when SafeguardedPolicy and NoSafeguardedPolicy are both specified" {
        { Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -SafeguardedPolicy 'pwsh_sgp' -NoSafeguardedPolicy } | Should -Throw "Parameters SafeguardedPolicy, NoSafeguardedPolicy are mutually exclusive."
    }

    It "Should throw error when SnapshotPolicy and NoSnapshotPolicy are both specified" {
        { Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -SnapshotPolicy 'pwsh_sp' -NoSnapshotPolicy } | Should -Throw "Parameters SnapshotPolicy, NoSnapshotPolicy are mutually exclusive."
    }

    It "Should throw error when SnapshotPolicy and SafeguardedPolicy are both specified" {
        { Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -SnapshotPolicy 'pwsh_sp' -SafeguardedPolicy 'pwsh_sgp' } | Should -Throw "Parameters SafeguardedPolicy, SnapshotPolicy are mutually exclusive."
    }

    It "Should throw error when ReplicationPolicy and NoDRReplication are both specified" {
        { Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -ReplicationPolicy 'pwsh_rp' -NoDRReplication } | Should -Throw "Parameters ReplicationPolicy, NoDRReplication are mutually exclusive."
    }

    It "Should throw error when PolicyStartTime is specified without SafeguardedPolicy or SnapshotPolicy" {
        { Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -PolicyStartTime '2203011800' } | Should -Throw "Parameter -PolicyStartTime is invalid without -SafeguardedPolicy or -SnapshotPolicy."
    }

    It "Should throw error when Safeguarded is specified without SnapshotPolicy" {
        { Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -Safeguarded } | Should -Throw "Parameter -Safeguarded is invalid without -SnapshotPolicy."
    }

    It "Should throw error when volume group does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') { return $null }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVVolumeGroup -Name 'pwsh_vg0' } | Should -Throw "VolumeGroup 'pwsh_vg0' does not exist."
    }

    It "Should throw error when both volume group and new name not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') { return $null }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NewName 'pwsh_vg1' } | Should -Throw "VolumeGroup 'pwsh_vg0' does not exist."
    }

    It "Should not call API to update volume group when -WhatIf is specified" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name='pwsh_vg0'; id='1'; owner_name='' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -OwnershipGroup 'pwsh_og' -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chvolumegroup' }
    }

    It "Should rename the volume group when NewName is different" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 1) {
                return @{ name = 'pwsh_vg0'; id = '0'; owner_name = '' }
            }
            elseif ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 2) {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NewName 'pwsh_vg1' -OwnershipGroup 'pwsh_og'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.name -eq 'pwsh_vg1' -and
                $CmdOpts.ownershipgroup -eq 'pwsh_og' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should not throw error if -Name volume group does not exist but -NewName volume group exists and proceed to update other params on -NewName volume group" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 1) {
                return $null
            }
            elseif ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 2) {
                return @{ name = 'pwsh_vg1'; id = '1'; owner_name = '' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NewName 'pwsh_vg1' -OwnershipGroup 'pwsh_og'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.ownershipgroup -eq 'pwsh_og' -and
                $CmdArgs -eq 'pwsh_vg1'
            }
    }

    It "Should throw error if both -Name volume group and -NewName volume group exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 1) {
                return @{ name = 'pwsh_vg0'; id = '0' }
            }
            elseif ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 2) {
                return @{ name = 'pwsh_vg1'; id = '1' }
            }

            return $null
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NewName 'pwsh_vg1' -OwnershipGroup 'pwsh_og' } | Should -Throw "Both 'pwsh_vg0' and 'pwsh_vg1' exist. Cannot rename, cannot proceed with other updates."
    }

    It "Should update volume group with OwnershipGroup" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; owner_name = 'pwsh_og0' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -OwnershipGroup 'pwsh_og1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.ownershipgroup -eq 'pwsh_og1' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with NoOwnershipGroup" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; owner_name = 'pwsh_og' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NoOwnershipGroup

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.noownershipgroup -eq $true -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with SafeguardedPolicy" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; safeguarded_policy_name = 'pwsh_sgp0' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -SafeguardedPolicy 'pwsh_sgp1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.safeguardedpolicy -eq 'pwsh_sgp1' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with SafeguardedPolicy and PolicyStartTime" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; safeguarded_policy_name = 'pwsh_sgp0'; safeguarded_policy_start_time = '' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -SafeguardedPolicy 'pwsh_sgp1' -PolicyStartTime '2203011800'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.safeguardedpolicy -eq 'pwsh_sgp1' -and
                $CmdOpts.policystarttime -eq '2203011800' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with NoSafeguardedPolicy" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; safeguarded_policy_name = 'pwsh_sgp' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NoSafeguardedPolicy

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.nosafeguardedpolicy -eq $true -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with SnapshotPolicy" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; snapshot_policy_name = 'pwsh_sp0' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -SnapshotPolicy 'pwsh_sp1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.snapshotpolicy -eq 'pwsh_sp1' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with SnapshotPolicy and PolicyStartTime" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; snapshot_policy_name = 'pwsh_sp0' }
            }
            elseif ($Cmd -eq 'lsvolumegroupsnapshotpolicy') {
                return @{ name = 'pwsh_vg0'; snapshot_policy_name = 'pwsh_sp0'; snapshot_policy_start_time = '220301180000' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -SnapshotPolicy 'pwsh_sp1' -PolicyStartTime '2203011800'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.snapshotpolicy -eq 'pwsh_sp1' -and
                $CmdOpts.policystarttime -eq '2203011800' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with PolicyStartTime only (same SnapshotPolicy, different start time)" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; snapshot_policy_name = 'pwsh_sp0' }
            }
            elseif ($Cmd -eq 'lsvolumegroupsnapshotpolicy') {
                return @{ name = 'pwsh_vg0'; snapshot_policy_name = 'pwsh_sp0'; snapshot_policy_start_time = '220301180000' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -SnapshotPolicy 'pwsh_sp0' -PolicyStartTime '2203011200'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.policystarttime -eq '2203011200' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with SnapshotPolicy and Safeguarded" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; snapshot_policy_name = 'pwsh_sp0'; snapshot_policy_safeguarded = 'no' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -SnapshotPolicy 'pwsh_sp1' -Safeguarded

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.snapshotpolicy -eq 'pwsh_sp1' -and
                $CmdOpts.safeguarded -eq $true -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with NoSnapshotPolicy" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; snapshot_policy_name = 'pwsh_sp0' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NoSnapshotPolicy

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.nosnapshotpolicy -eq $true -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with NoSnapshotPolicy and RetainBackupEnabled" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; snapshot_policy_name = 'pwsh_sp0' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NoSnapshotPolicy -RetainBackupEnabled

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.nosnapshotpolicy -eq $true -and
                $CmdOpts.retainbackupenabled -eq $true -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with ReplicationPolicy" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; replication_policy_name = 'pwsh_rp0' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -ReplicationPolicy 'pwsh_rp1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.replicationpolicy -eq 'pwsh_rp1' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with NoDRReplication (version >= 8.7.1.0)" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; replication_policy_name = 'pwsh_rp0' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NoDRReplication

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.nodrreplication -eq $true -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with NoDRReplication (version < 8.7.1.0)" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; replication_policy_name = 'pwsh_rp0' }
            }
        } -ModuleName IBMStorageVirtualize
        Mock Get-IBMSVVersion { return "8.6.0.0" } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NoDRReplication

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.noreplicationpolicy -eq $true -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with IgnoreUserFCMaps" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; ignore_user_flash_copy_maps = 'no' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -IgnoreUserFCMaps 'yes'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.ignoreuserfcmaps -eq 'yes' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with DraftPartition" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; draft_partition_name = ''; partition_name = '' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -DraftPartition 'pwsh_draft_ptn'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.draftpartition -eq 'pwsh_draft_ptn' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should update volume group with SnapshotPolicySuspended" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{ name = 'pwsh_vg0'; snapshot_policy_name = 'pwsh_sp' }
            }
            if ($Cmd -eq 'lsvolumegroupsnapshotpolicy') {
                return @{ name = 'pwsh_vg0'; snapshot_policy_name = 'pwsh_sp'; snapshot_policy_start_time = '220301180000'; snapshot_policy_suspended = 'no' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -SnapshotPolicySuspended 'yes'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroupsnapshotpolicy' -and
                $CmdOpts.snapshotpolicysuspended -eq 'yes' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should handle OwnershipGroup and SnapshotPolicy in separate batches" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{
                    name = 'pwsh_vg0'
                    owner_name = 'pwsh_og0'
                    snapshot_policy_name = 'pwsh_sp0'
                }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -OwnershipGroup 'pwsh_og1' -SnapshotPolicy 'pwsh_sp1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.ownershipgroup -eq 'pwsh_og1' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.snapshotpolicy -eq 'pwsh_sp1' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should handle NoOwnershipGroup and SnapshotPolicy in separate batches" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{
                    name = 'pwsh_vg0'
                    owner_name = 'pwsh_og0'
                    snapshot_policy_name = ''
                }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NoOwnershipGroup -SnapshotPolicy 'pwsh_sp0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.noownershipgroup -eq $true -and
                $CmdArgs -eq 'pwsh_vg0'
            }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.snapshotpolicy -eq 'pwsh_sp0' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should handle NewName and DraftPartition in separate batches" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 1) {
                return @{name = 'pwsh_vg0'; draft_partition_name = ''; partition_name = ''}
            }
            elseif ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 2) {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NewName 'pwsh_vg1' -DraftPartition 'pwsh_draft_ptn'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.name -eq 'pwsh_vg1' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.draftpartition -eq 'pwsh_draft_ptn' -and
                $CmdArgs -eq 'pwsh_vg1'
            }
    }

    It "Should handle NewName and ReplicationPolicy in separate batches" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 1) {
                return @{ name = 'pwsh_vg0'; replication_policy_name = 'pwsh_rp0' }
            }
            elseif ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 2) {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NewName 'pwsh_vg1' -ReplicationPolicy 'pwsh_rp1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.name -eq 'pwsh_vg1' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.replicationpolicy -eq 'pwsh_rp1' -and
                $CmdArgs -eq 'pwsh_vg1'
            }
    }

    It "Should handle NewName and NoDRReplication in separate batches" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 1) {
                return @{ name = 'pwsh_vg0'; replication_policy_name = 'pwsh_rp0' }
            }
            elseif ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 2) {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NewName 'pwsh_vg1' -NoDRReplication

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.name -eq 'pwsh_vg1' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.nodrreplication -eq $true -and
                $CmdArgs -eq 'pwsh_vg1'
            }
    }

    It "Should handle NewName+OwnershipGroup and SnapshotPolicy+DraftPartition in separate batches" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 1) {
                return @{name = 'pwsh_vg0'; draft_partition_name = ''; partition_name = ''; owner_name = 'pwsh_og0'; snapshot_policy_name = 'pwsh_sp0'}
            }
            elseif ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 2) {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NewName 'pwsh_vg1' -OwnershipGroup 'pwsh_og1' -SnapshotPolicy 'pwsh_sp1' -DraftPartition 'pwsh_draft_ptn'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.name -eq 'pwsh_vg1' -and
                $CmdOpts.snapshotpolicy -eq 'pwsh_sp1' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.ownershipgroup -eq 'pwsh_og1' -and
                $CmdOpts.draftpartition -eq 'pwsh_draft_ptn' -and
                $CmdArgs -eq 'pwsh_vg1'
            }
    }

    It "Should update volume group with multiple parameters (NewName+OwnershipGroup+SnapshotPolicy+Safeguarded+IgnoreUserFCMaps+PolicyStartTime+DraftPartition)" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 1) {
                return @{
                    name = 'pwsh_vg0'
                    owner_name = 'pwsh_og0'
                    snapshot_policy_name = 'pwsh_sp0'
                    replication_policy_name = 'pwsh_rp0'
                    ignore_user_flash_copy_maps = 'no'
                    draft_partition_name = ''
                    partition_name = ''
                }
            }
            elseif ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 2) {
                return $null
            }
            if ($Cmd -eq 'lsvolumegroupsnapshotpolicy') {
                return @{
                    name = 'pwsh_vg0'
                    snapshot_policy_name = 'pwsh_sp0'
                    snapshot_policy_start_time = '220301120000'
                }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NewName 'pwsh_vg1' -OwnershipGroup 'pwsh_og1' -SnapshotPolicy 'pwsh_sp1' -Safeguarded -IgnoreUserFCMaps 'yes' -PolicyStartTime '2203011200' -DraftPartition 'pwsh_draft_ptn'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.name -eq 'pwsh_vg1' -and
                $CmdOpts.snapshotpolicy -eq 'pwsh_sp1' -and
                $CmdOpts.safeguarded -eq $true -and
                $CmdOpts.policystarttime -eq '2203011200' -and
                $CmdOpts.ignoreuserfcmaps -eq 'yes' -and
                $CmdArgs -eq 'pwsh_vg0'
            }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.ownershipgroup -eq 'pwsh_og1' -and
                $CmdOpts.draftpartition -eq 'pwsh_draft_ptn' -and
                $CmdArgs -eq 'pwsh_vg1'
            }
    }

    It "Should update volume group with multiple parameters (NoOwnershipGroup+NoSnapshotPolicy+NoDRReplication+RetainBackupEnabled)" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{
                    name = 'pwsh_vg0'
                    owner_name = 'pwsh_og0'
                    snapshot_policy_name = 'pwsh_sp0'
                    replication_policy_name = 'pwsh_rp0'
                }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NoOwnershipGroup -NoSnapshotPolicy -NoDRReplication -RetainBackupEnabled

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chvolumegroup' -and
                $CmdOpts.nosnapshotpolicy -eq $true -and
                $CmdOpts.noownershipgroup -eq $true -and
                $CmdOpts.nodrreplication -eq $true -and
                $CmdOpts.retainbackupenabled -eq $true -and
                $CmdArgs -eq 'pwsh_vg0'
            }
    }

    It "Should be idempotent when updating volume group with same values" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 1) {
                return $null
            }
            elseif ($Cmd -eq 'lsvolumegroup' -and $script:count -eq 2) {
                return @{
                    name = 'pwsh_vg1'
                    owner_name = 'pwsh_og0'
                    snapshot_policy_name = 'pwsh_sp0'
                    replication_policy_name = 'pwsh_rp0'
                    snapshot_policy_safeguarded = 'yes'
                    ignore_user_flash_copy_maps = 'yes'
                    draft_partition_name = 'pwsh_draft_ptn'
                }
            }
            if ($Cmd -eq 'lsvolumegroupsnapshotpolicy') {
                return @{
                    name = 'pwsh_vg0'
                    snapshot_policy_name = 'pwsh_sp0'
                    snapshot_policy_start_time = '220301180000'
                }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolumeGroup -Name 'pwsh_vg0' -NewName 'pwsh_vg1' -OwnershipGroup 'pwsh_og0' -SnapshotPolicy 'pwsh_sp0' -Safeguarded -IgnoreUserFCMaps 'yes' -PolicyStartTime '2203011800' -DraftPartition 'pwsh_draft_ptn'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chvolumegroup' }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return @{
                    name = 'pwsh_vg0'
                    owner_name = 'pwsh_og0'
                }
            }
            if ($Cmd -eq 'chvolumegroup') {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/chvolumegroup/pwsh_vg"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVVolumeGroup -Name "pwsh_vg0" -OwnershipGroup 'pwsh_og1' } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/chvolumegroup/pwsh_vg"
    }
}
