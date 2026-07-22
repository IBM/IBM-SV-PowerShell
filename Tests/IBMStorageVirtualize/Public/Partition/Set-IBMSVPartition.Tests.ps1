Describe "Set-IBMSVPartition Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lspartition") {
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    id = '0'
                    draft = 'no'
                    replication_policy_name = 'pwsh_rp0'
                    preferred_management_system_name = 'system1'
                    active_management_system_name = 'system1'
                    dr_linked_partition_name = ''
                    dr_linked_partition_uuid = ''
                    management_portset_name = ''
                    migration_status = ''
                    ownership_group_name = ''
                    desired_location_system_name = ''
                }
            }

            return $null
        } -ModuleName IBMStorageVirtualize

        $script:count = 0
    }

    It "Should throw error when when mutually exclusive parameter specified" {
        { Set-IBMSVPartition -Name 'pwsh_partition0' -ReplicationPolicy 'pwsh_rp0' -NoReplicationPolicy } | Should -Throw "Parameters ReplicationPolicy, NoReplicationPolicy are mutually exclusive."
        { Set-IBMSVPartition -Name 'pwsh_partition0' -ReplicationPolicy 'pwsh_rp0' -PreferredManagementSystem 'system2' } | Should -Throw "Parameters ReplicationPolicy, PreferredManagementSystem are mutually exclusive."
        { Set-IBMSVPartition -Name 'pwsh_partition0' -DRLinkPartitionUUID '12A345B6-12A3-1234-1A23-A1B2C34567DE' -RemoteSystem "cluster2" -RemoveDRLink } | Should -Throw "Parameters DRLinkPartitionUUID, RemoveDRLink are mutually exclusive."
        { Set-IBMSVPartition -Name 'pwsh_partition0' -ManagementPortset 'pwsh_portset' -NoManagementPortset } | Should -Throw "Parameters ManagementPortset, NoManagementPortset are mutually exclusive."
        { Set-IBMSVPartition -Name 'pwsh_partition0' -OwnershipGroup 'pwsh_og' -NoOwnershipGroup } | Should -Throw "Parameters OwnershipGroup, NoOwnershipGroup are mutually exclusive."
    }

    It "Should throw error when DeletePreferredManagementCopy is used without NoReplicationPolicy" {
        { Set-IBMSVPartition -Name 'pwsh_partition0' -DeletePreferredManagementCopy } | Should -Throw "Parameter -DeletePreferredManagementCopy requires -NoReplicationPolicy."
    }

    It "Should throw error when required_together parameter not specified " {
        { Set-IBMSVPartition -Name 'pwsh_partition0' -DRLinkPartitionUUID "4D837492-8C69-5BEA-9147-F5C937D38028" } | Should -Throw "Parameters -DRLinkPartitionUUID and -RemoteSystem must be specified together."
        { Set-IBMSVPartition -Name 'pwsh_partition0' -RemoteSystem "remote_cluster" } | Should -Throw "Parameters -DRLinkPartitionUUID and -RemoteSystem must be specified together."
    }

    It "Should not call API to update partition when -WhatIf is specified" {
        Set-IBMSVPartition -Name 'pwsh_partition0' -ReplicationPolicy 'pwsh_rp0' -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chpartition" }
    }

    It "Should throw error when partition does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lspartition") { return $null }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPartition -Name 'pwsh_partition0' } | Should -Throw "Partition 'pwsh_partition0' does not exist."
    }

    It "Should throw error when both partition and new name not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lspartition") { return $null }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPartition -Name 'pwsh_partition0' -NewName 'pwsh_partition1' } | Should -Throw "Partition 'pwsh_partition0' does not exist."
    }

    It "Should rename the partition when NewName is different" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq "lspartition") {
                if ($script:count -eq 1) {
                    return [pscustomobject]@{ name = 'pwsh_partition0'; id = '0'; draft = 'no'; replication_policy_name = '' }
                }
                return $null
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPartition -Name 'pwsh_partition0' -NewName 'pwsh_partition1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.name -eq "pwsh_partition1" -and
                $CmdArgs -eq "pwsh_partition0"
            }
    }

    It "Should not throw error if -Name partition does not exist but -NewName partition exists and proceed to update other params on -NewName partition" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:count++
            if ($Cmd -eq "lspartition") {
                if ($script:count -eq 1) { return $null }
                return [pscustomobject]@{ name = 'pwsh_partition1'; id = '1'; draft = 'no'; replication_policy_name = '' }
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPartition -Name 'pwsh_partition0' -NewName 'pwsh_partition1' -ReplicationPolicy 'pwsh_rp0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.replicationpolicy -eq "pwsh_rp0" -and
                $CmdArgs -eq "pwsh_partition1"
            }
    }

    It "Should throw error if both -Name partition and -NewName partition exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:count++
            if ($Cmd -eq "lspartition") {
                if ($script:count -eq 1) {
                    return [pscustomobject]@{ name = 'pwsh_partition0'; id = '0'; draft = 'no' }
                }
                return [pscustomobject]@{ name = 'pwsh_partition1'; id = '1'; draft = 'no' }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPartition -Name 'pwsh_partition0' -NewName 'pwsh_partition1' } | Should -Throw "Both 'pwsh_partition0' and 'pwsh_partition1' exist. Cannot rename, cannot proceed with other updates."
    }

    It "Should remove replication policy from partition" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lspartition") {
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    replication_policy_name = 'pwsh_rp0'
                    preferred_management_system_name = 'system1'
                    active_management_system_name = ''
                }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPartition -Name 'pwsh_partition0' -NoReplicationPolicy -DeletePreferredManagementCopy

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.noreplicationpolicy -eq $true -and
                $CmdOpts.deletepreferredmanagementcopy -eq $true -and
                $CmdArgs -eq "pwsh_partition0"
            }
    }

    It "Should throw error when trying to remove replication policy with DeletePreferredManagementCopy when active and preferred management systems are same" {
        { Set-IBMSVPartition -Name 'pwsh_partition0' -NoReplicationPolicy -DeletePreferredManagementCopy } | Should -Throw "CMMVC1042E Cannot remove replication policy with -DeletePreferredManagementCopy because active management and preferred management system are the same."
    }

    It "Should set preferred management system" {
        Set-IBMSVPartition -Name 'pwsh_partition0' -PreferredManagementSystem 'system2'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.preferredmanagementsystem -eq "system2" -and
                $CmdArgs -eq "pwsh_partition0"
            }
    }

    It "Should publish a draft partition" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lspartition") {
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    draft = 'yes'
                }
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPartition -Name 'pwsh_partition0' -Publish

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.publish -eq $true -and
                $CmdArgs -eq "pwsh_partition0"
            }
    }

    It "Should create DR link to remote partition" {
        Set-IBMSVPartition -Name 'pwsh_partition0' -DRLinkPartitionUUID "12A345B6-12A3-1234-1A23-A1B2C34567DE" -RemoteSystem "remote_cluster"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.makedrlink -eq $true -and
                $CmdOpts.remotedrlinkedpartitionuuid -eq "12A345B6-12A3-1234-1A23-A1B2C34567DE" -and
                $CmdOpts.remotesystem -eq "remote_cluster"
                $CmdArgs -eq "pwsh_partition0"
            }
    }

    It "Should throw error when trying to create DR link on partition that already has one" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lspartition") {
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    dr_linked_partition_uuid = 'existing-uuid'
                    draft = 'no'
                }
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPartition -Name 'pwsh_partition0' -DRLinkPartitionUUID "12A345B6-12A3-1234-1A23-A1B2C34567DE" -RemoteSystem "remote_cluster" } | Should -Throw "CMMVC1245E Storage partition 'pwsh_partition0' already has a disaster recovery link configured."
    }

    It "Should remove DR link from partition" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lspartition") {
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    dr_linked_partition_name = 'remote_partition'
                    draft = 'no'
                }
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPartition -Name 'pwsh_partition0' -RemoveDRLink

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.removedrlink -eq $true -and
                $CmdArgs -eq "pwsh_partition0"
            }
    }

    It "Should assign management portset to partition" {
        Set-IBMSVPartition -Name 'pwsh_partition0' -ManagementPortset 'pwsh_portset0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.managementportset -eq "pwsh_portset0" -and
                $CmdArgs -eq "pwsh_partition0"
            }
    }

    It "Should throw error when trying to assign different management portset to partition that already has one" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lspartition") {
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    management_portset_name = 'pwsh_portset0'
                    draft = 'no'
                }
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPartition -Name 'pwsh_partition0' -ManagementPortset 'pwsh_portset1' } | Should -Throw "This partition is already mapped to a management portset: pwsh_portset0"
    }

    It "Should remove management portset from partition" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lspartition") {
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    management_portset_name = 'pwsh_portset0'
                    draft = 'no'
                }
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPartition -Name 'pwsh_partition0' -NoManagementPortset

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.nomanagementportset -eq $true -and
                $CmdArgs -eq "pwsh_partition0"
            }
    }

    It "Should update ownershipgroup of partition" {
        Set-IBMSVPartition -Name 'pwsh_partition0' -OwnershipGroup 'pwsh_og0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.ownershipgroup -eq "pwsh_og0" -and
                $CmdArgs -eq "pwsh_partition0"
            }
    }

    It "Should remove ownershipgroup from partition" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lspartition") {
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    ownership_group_name = 'pwsh_og0'
                }
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPartition -Name 'pwsh_partition0' -NoOwnershipGroup

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.noownershipgroup -eq $true -and
                $CmdArgs -eq "pwsh_partition0"
            }
    }

    It "Should initiate partition migration to target cluster" {
        Set-IBMSVPartition -Name 'pwsh_partition0' -Location 'target_cluster_fqdn'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.location -eq "target_cluster_fqdn" -and
                $CmdArgs -eq "pwsh_partition0"
            }
    }

    It "Should not initiate migration when already in progress to same target" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lspartition") {
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    migration_status = 'in_progress'
                    desired_location_system_name = 'target_cluster_fqdn'
                    draft = 'no'
                }
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPartition -Name 'pwsh_partition0' -Location 'target_cluster_fqdn'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chpartition" }
    }

    It "Should complete partition migration on target cluster" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lspartition") {
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    migration_status = 'awaiting_user_input'
                    draft = 'no'
                }
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPartition -Name 'pwsh_partition0' -MigrationAction 'fixeventwithchecks'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.migrationaction -eq "fixeventwithchecks" -and
                $CmdArgs -eq "pwsh_partition0"
            }
    }

    It "Should update multiple parameters at once" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:count++
            if ($Cmd -eq "lspartition") {
                if ($script:count -eq 1) {
                    return [pscustomobject]@{
                        name = 'pwsh_partition0'
                        ownership_group_name = ''
                    }
                }
            }
            return $null
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPartition -Name 'pwsh_partition0' -NewName 'pwsh_partition1' -OwnershipGroup 'pwsh_og'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chpartition" -and
                $CmdOpts.name -eq "pwsh_partition1" -and
                $CmdOpts.ownershipgroup -eq "pwsh_og" -and
                $CmdArgs -eq "pwsh_partition0"
            }
    }

    It "Should not make changes when no updates are required" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:count++
            if ($Cmd -eq "lspartition") {
                if ($script:count -eq 1) {
                    return [pscustomobject]@{
                        name = 'pwsh_partition0'
                        replication_policy_name = 'pwsh_rp'
                        management_portset_name = 'pwsh_portset'
                        ownership_group_name = 'pwsh_og'
                        draft = 'no'
                    }
                }
            }
            return $null
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPartition -Name 'pwsh_partition0' -ReplicationPolicy 'pwsh_rp' -ManagementPortset 'pwsh_portset' -OwnershipGroup 'pwsh_og' -Publish

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chpartition" }
    }
}
