<#
.SYNOPSIS
Modifies an existing storage partition on an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVPartition cmdlet updates properties of an existing storage partition.

.PARAMETER Name
Specifies the name of the storage partition to modify.

.PARAMETER NewName
Specifies a new name for the storage partition.
If both Name and NewName exist, the operation fails.
If the specified Name does not exist but NewName exists, the cmdlet continues updating the NewName partition.

.PARAMETER ReplicationPolicy
Specifies the replication policy for the storage partition.
Mutually exclusive with -NoReplicationPolicy and -PreferredManagementSystem.

.PARAMETER NoReplicationPolicy
Specifies that the replication policy is removed from the partition.
Mutually exclusive with -ReplicationPolicy.

.PARAMETER DeletePreferredManagementCopy
Specifies that the preferred management copy is deleted when removing the replication policy.
Requires -NoReplicationPolicy.
Only permitted when active management system is NOT the same as preferred management system.

.PARAMETER PreferredManagementSystem
Specifies the preferred management system for the storage partition.
Mutually exclusive with -ReplicationPolicy.
Permitted only from the system which is the active management system.

.PARAMETER Publish
Specifies that a draft partition should be published.

.PARAMETER DRLinkPartitionUUID
Specifies the UUID of the disaster-recovery system's partition to create a DR link.
Requires -RemoteSystem.
Mutually exclusive with -RemoveDRLink.

.PARAMETER RemoteSystem
Specifies the disaster-recovery system name.
Required when -DRLinkPartitionUUID is specified.

.PARAMETER RemoveDRLink
Specifies that the disaster recovery link is removed from this partition.
Mutually exclusive with -DRLinkPartitionUUID.

.PARAMETER ManagementPortset
Specifies the management portset to be assigned to the partition.
Mutually exclusive with -NoManagementPortset.

.PARAMETER NoManagementPortset
Specifies that the management portset is removed from the partition.
Mutually exclusive with -ManagementPortset.

.PARAMETER Location
Specifies the target system location to migrate the partition.
Used at source cluster to initiate partition migration.

.PARAMETER MigrationAction
Specifies how partition migration should continue on target system.
Valid values: fixeventwithchecks
Used at target cluster to complete partition migration.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Set-IBMSVPartition -Name partition1 -NewName partition1_new
Renames a storage partition.

.EXAMPLE
PS> Set-IBMSVPartition -Name partition1 -ReplicationPolicy ha_policy_1
Assigns a replication policy to the partition.

.EXAMPLE
PS> Set-IBMSVPartition -Name partition1 -Publish
Publishes a draft partition.

.EXAMPLE
PS> Set-IBMSVPartition -Name partition1 -DRLinkPartitionUUID "4D837492-8C69-5BEA-9147-F5C937D38028" -RemoteSystem remote_cluster
Creates a DR link to a remote partition.

.EXAMPLE
PS> Set-IBMSVPartition -Name partition1 -RemoveDRLink
Removes the DR link from the partition.

.EXAMPLE
PS> Set-IBMSVPartition -Name partition1 -ManagementPortset portset1
Assigns a management portset to the partition.

.EXAMPLE
PS> Set-IBMSVPartition -Name partition1 -NoManagementPortset
Removes the management portset from the partition.

.EXAMPLE
PS> Set-IBMSVPartition -Name partition1 -Location target_cluster_fqdn
Initiates partition migration to target cluster (run on source).

.EXAMPLE
PS> Set-IBMSVPartition -Name partition1 -MigrationAction fixeventwithchecks
Completes partition migration (run on target cluster).

.EXAMPLE
PS> Set-IBMSVPartition -Name partition1 -NoReplicationPolicy -DeletePreferredManagementCopy
Removes replication policy and deletes preferred management copy.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Multiple parameter update is non-atomic.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chpartition
#>

function Set-IBMSVPartition {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$NewName,

        [string]$ReplicationPolicy,

        [switch]$NoReplicationPolicy,

        [switch]$DeletePreferredManagementCopy,

        [string]$PreferredManagementSystem,

        [switch]$Publish,

        [string]$DRLinkPartitionUUID,

        [string]$RemoteSystem,

        [switch]$RemoveDRLink,

        [string]$OwnershipGroup,

        [switch]$NoOwnershipGroup,

        [string]$ManagementPortset,

        [switch]$NoManagementPortset,

        [string]$Location,

        [ValidateSet("fixeventwithchecks")]
        [string]$MigrationAction,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        if ($DeletePreferredManagementCopy -and -not $NoReplicationPolicy) {
            throw (Resolve-Error -ErrorInput "Parameter -DeletePreferredManagementCopy requires -NoReplicationPolicy." -Category InvalidArgument)
        }

        if (($DRLinkPartitionUUID -and -not $RemoteSystem) -or (-not $DRLinkPartitionUUID -and $RemoteSystem)) {
            throw (Resolve-Error -ErrorInput "Parameters -DRLinkPartitionUUID and -RemoteSystem must be specified together." -Category InvalidArgument)
        }

        $validationMutexRules = @{
            mutex1 = @('ReplicationPolicy', 'NoReplicationPolicy')
            mutex2 = @('ReplicationPolicy', 'PreferredManagementSystem')
            mutex3 = @('DRLinkPartitionUUID', 'RemoveDRLink')
            mutex4 = @('ManagementPortset', 'NoManagementPortset')
            mutex5 = @('OwnershipGroup', 'NoOwnershipGroup')
        }
        foreach ($rule in $validationMutexRules.Values) {
            $present = $rule | Where-Object { $PSBoundParameters.ContainsKey($_) }
            if ($present.Count -gt 1) {
                throw (Resolve-Error -ErrorInput "Parameters $($present -join ', ') are mutually exclusive." -Category InvalidArgument)
            }
        }

        # --- Initial check ---
        if ($NewName -and $NewName -eq $Name) { $NewName = $null }

        $data = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lspartition" -CmdArgs ($Name)
        if ($data -and $data.err) {
            throw (Resolve-Error -ErrorInput $data -Category InvalidOperation)
        }

        $newData = $null
        if ($NewName) {
            $newData = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lspartition" -CmdArgs ($NewName)
            if ($newData -and $newData.err) {
                throw (Resolve-Error -ErrorInput $newData -Category InvalidOperation)
            }
        }

        if ($data -and $newData) {
            throw (Resolve-Error -ErrorInput "Both '$Name' and '$NewName' exist. Cannot rename, cannot proceed with other updates." -Category ResourceExists)
        }

        if (-not $data) {
            if (-not $newData) {
                throw (Resolve-Error -ErrorInput "Partition '$Name' does not exist." -Category ObjectNotFound)
            }
            Write-IBMSVLog -Level WARN -Message "Partition '$NewName' already exists. Continuing other updates on '$NewName' partition."
            $data = $newData
            $Name = $NewName
            $NewName = $null
        }

        # --- Update Partition ---
        if ($PSCmdlet.ShouldProcess("Partition '$Name'", "Modify")) {

            # --- Probe logic ---
            $props = @{}

            if ($NewName -and ($NewName -ne $data.name)) {
                $props['name'] = $NewName
            }

            if ($ReplicationPolicy -and ($ReplicationPolicy -ne $data.replication_policy_name)) {
                $props['replicationpolicy'] = $ReplicationPolicy
            }

            if ($NoReplicationPolicy -and $data.replication_policy_name) {
                $props['noreplicationpolicy'] = $true
                if ($DeletePreferredManagementCopy) {
                    if ($data.preferred_management_system_name -eq $data.active_management_system_name) {
                        throw (Resolve-Error -ErrorInput "CMMVC1042E Cannot remove replication policy with -DeletePreferredManagementCopy because active management and preferred management system are the same." -Category InvalidOperation)
                    }
                    $props['deletepreferredmanagementcopy'] = $true
                }
            }

            if ($PreferredManagementSystem -and ($PreferredManagementSystem -ne $data.preferred_management_system_name)) {
                $props['preferredmanagementsystem'] = $PreferredManagementSystem
            }

            if ($Publish -and ($data.draft -eq 'yes')) {
                $props['publish'] = $true
            }

            if ($DRLinkPartitionUUID) {
                if ($data.dr_linked_partition_uuid) {
                    throw (Resolve-Error -ErrorInput "CMMVC1245E Storage partition '$Name' already has a disaster recovery link configured." -Category InvalidOperation)
                }
                $props['makedrlink'] = $true
                $props['remotedrlinkedpartitionuuid'] = $DRLinkPartitionUUID
                $props['remotesystem'] = $RemoteSystem
            }

            if ($RemoveDRLink -and $data.dr_linked_partition_name) {
                $props['removedrlink'] = $true
            }

            if ($ManagementPortset) {
                if ($data.management_portset_name -and $data.management_portset_name -ne $ManagementPortset) {
                    throw (Resolve-Error -ErrorInput "This partition is already mapped to a management portset: $($data.management_portset_name)" -Category InvalidOperation)
                }
                if ($ManagementPortset -ne $data.management_portset_name) {
                    $props['managementportset'] = $ManagementPortset
                }
            }

            if ($NoManagementPortset -and $data.management_portset_name) {
                $props['nomanagementportset'] = $true
            }

            if ($OwnershipGroup -and $OwnershipGroup -ne $data.ownership_group_name) {
                $props['ownershipgroup'] = $OwnershipGroup
            }

            if ($NoOwnershipGroup -and $data.ownership_group_name) {
                $props['noownershipgroup'] = $true
            }

            # Handle partition migration
            $currentMigrationStatus = $data.migration_status
            if ($Location) {
                if (-not ($currentMigrationStatus -eq 'in_progress' -and $Location -eq $data.desired_location_system_name)) {
                    $props['location'] = $Location
                }
                else {
                    Write-IBMSVLog -Level INFO -Message "A partition migration is already in progress with target cluster '$Location'."
                    return
                }
            }

            if ($MigrationAction -and ($currentMigrationStatus -notin @('', 'in_progress'))) {
                $props['migrationaction'] = $MigrationAction
            }

            if ($props.Count -eq 0) {
                Write-IBMSVLog -Level INFO -Message "No changes required for Partition '$Name'."
                return
            }

            # --- Apply changes ---

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chpartition" -CmdOpts $props -CmdArgs $Name
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            if ($props.ContainsKey('managementportset') -or $props.ContainsKey('nomanagementportset')) {
                Start-Sleep -Milliseconds 3000
            }

            if ($props.ContainsKey('name')) {
                if ($props.Count -gt 1) {
                    Write-IBMSVLog -Level INFO -Message "Partition '$Name' renamed to '$NewName' and updated successfully."
                }
                else {
                    Write-IBMSVLog -Level INFO -Message "Partition '$Name' renamed to '$NewName'."
                }
            }
            else {
                Write-IBMSVLog -Level INFO -Message "Partition '$Name' updated successfully."
            }
        }
    }
}
