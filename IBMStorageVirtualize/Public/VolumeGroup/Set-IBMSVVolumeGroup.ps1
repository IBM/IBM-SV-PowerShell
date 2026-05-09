<#
.SYNOPSIS
Modifies an existing volumegroup in an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVVolumeGroup cmdlet updates properties of an existing volumegroup.

It maps to chvolumegroup and related commands based on system capabilities and requested changes.

Some parameter updates are applied in multiple operations when required to satisfy
mutual exclusivity constraints.

The cmdlet is idempotent:
- Only properties that differ from the current configuration are modified.
- If no changes are required, no operation is performed.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER Name
Specifies the name of the volumegroup to modify.

.PARAMETER NewName
Specifies a new name for the volumegroup.

If both Name and NewName exist, the operation fails.

If the specified Name does not exist but NewName exists, the cmdlet continues updating the NewName volumegroup.

.PARAMETER OwnershipGroup
Specifies the ownership group for the volumegroup.

Mutually exclusive with -NoOwnershipGroup, -SafeguardedPolicy, and -SnapshotPolicy.

.PARAMETER NoOwnershipGroup
Specifies that the ownership group is removed.

Mutually exclusive with -OwnershipGroup.

.PARAMETER SafeguardedPolicy
Specifies the safeguarded policy for the volumegroup.

Mutually exclusive with -NoSafeguardedPolicy, -SnapshotPolicy, and -NoSnapshotPolicy.

.PARAMETER PolicyStartTime
Specifies the policy start time.

Requires -SafeguardedPolicy or -SnapshotPolicy.

.PARAMETER NoSafeguardedPolicy
Specifies that the safeguarded policy is removed.

Mutually exclusive with -SafeguardedPolicy, -SnapshotPolicy, and -NoSnapshotPolicy.

.PARAMETER SnapshotPolicy
Specifies the snapshot policy for the volumegroup.

Mutually exclusive with -NoSnapshotPolicy and -SafeguardedPolicy.

.PARAMETER Safeguarded
Specifies that the volumegroup is safeguarded.

Valid only when -SnapshotPolicy is specified.

.PARAMETER NoSnapshotPolicy
Specifies that the snapshot policy is removed.

Mutually exclusive with -SnapshotPolicy and -SafeguardedPolicy.

.PARAMETER ReplicationPolicy
Specifies the replication policy for the volumegroup.

Mutually exclusive with -NoReplicationPolicy and -NoDRReplication.

.PARAMETER NoDRReplication
Specifies that DR replication is disabled.

On systems running version 8.7.1.0 or later, this maps to the nodrreplication option of the chvolumegroup command.
On earlier versions, the cmdlet uses the noreplicationpolicy option to achieve the same behavior.

Mutually exclusive with -ReplicationPolicy.

.PARAMETER IgnoreUserFCMaps
Specifies whether user-defined FlashCopy mappings are ignored.
Valid values: yes, no.

.PARAMETER RetainBackupEnabled
Specifies that backup retention is preserved when removing snapshot policy.

.PARAMETER DraftPartition
Specifies the draft partition for the volumegroup.

Mutually exclusive with -ReplicationPolicy.

.PARAMETER SnapshotPolicySuspended
Specifies whether the snapshot policy is suspended.
Valid values: yes, no.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Set-IBMSVVolumeGroup -Name VG1 -NewName VG1_New -OwnershipGroup Group1

Renames the volumegroup and updates ownership.

.EXAMPLE
PS> Set-IBMSVVolumeGroup -Name VG2 -SnapshotPolicy Snap1 -PolicyStartTime "22:00"

Applies a snapshot policy.

.EXAMPLE
PS> Set-IBMSVVolumeGroup -Name VG3 -NoSafeguardedPolicy -RetainBackupEnabled

Removes safeguarded policy while retaining backup.

.EXAMPLE
PS> Set-IBMSVVolumeGroup -Name VG4 -DraftPartition PartA -ReplicationPolicy Rep1

Updates partition and replication policy.

.INPUTS
System.String

You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- If the specified volumegroup does not exist, a terminating error is thrown.
- If both Name and NewName exist, the operation fails.
- Only modified properties are sent to the backend.
- Performs validation of parameter combinations before execution.
- Some updates are applied in multiple steps to satisfy mutual exclusivity constraints.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chvolumegroup

.LINK
https://www.ibm.com/docs/en/search/chvolumegroupsnapshotpolicy
#>

function Set-IBMSVVolumeGroup {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$NewName,

        [string]$OwnershipGroup,

        [switch]$NoOwnershipGroup,

        [string]$SafeguardedPolicy,

        [string]$PolicyStartTime,

        [switch]$NoSafeguardedPolicy,

        [string]$SnapshotPolicy,

        [switch]$Safeguarded,

        [switch]$NoSnapshotPolicy,

        [string]$ReplicationPolicy,

        [switch]$NoDRReplication,

        [ValidateSet("yes", "no")]
        [string]$IgnoreUserFCMaps,

        [switch]$RetainBackupEnabled,

        [string]$DraftPartition,

        [ValidateSet("yes", "no")]
        [string]$SnapshotPolicySuspended,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        $validationMutexRules = @{
            mutex1 = @('OwnershipGroup', 'NoOwnershipGroup', 'SafeguardedPolicy', 'NoSafeguardedPolicy')
            mutex2 = @('SafeguardedPolicy', 'NoSafeguardedPolicy', 'SnapshotPolicy', 'NoSnapshotPolicy')
            mutex3 = @('ReplicationPolicy', 'NoDRReplication')
        }
        foreach ($rule in $validationMutexRules.Values) {
            $present = $rule | Where-Object { $PSBoundParameters.ContainsKey($_) }
            if ($present.Count -gt 1) {
                throw (Resolve-Error -ErrorInput "Parameters $($present -join ', ') are mutually exclusive." -Category InvalidArgument)
            }
        }
        if ($PolicyStartTime -and (-not $SafeguardedPolicy -and -not $SnapshotPolicy)) {
            throw (Resolve-Error -ErrorInput "Parameter -PolicyStartTime is invalid without -SafeguardedPolicy or -SnapshotPolicy." -Category InvalidArgument)
        }
        if ($Safeguarded -and -not $SnapshotPolicy) {
            throw (Resolve-Error -ErrorInput "Parameter -Safeguarded is invalid without -SnapshotPolicy." -Category InvalidArgument)
        }
        $batchMutexRules = @{
            mutex1 = @('NoOwnershipGroup', 'SnapshotPolicy')
            mutex2 = @('Name', 'DraftPartition')
            mutex3 = @('OwnershipGroup', 'SnapshotPolicy', 'NoSnapshotPolicy')
            mutex4 = @('Name', 'ReplicationPolicy', 'NoDRReplication')
        }
        $dependencies = @{
            PolicyStartTime = @('SnapshotPolicy', 'SafeguardedPolicy')
            Safeguarded     = @('SnapshotPolicy')
        }

        # --- Initial check ---
        if ($NewName -and $NewName -eq $Name) { $NewName = $null }
        $data = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumegroup" -CmdArgs ("-gui", $Name)
        if ($data.err) {
            throw (Resolve-Error -ErrorInput $data -Category InvalidOperation)
        }

        $newData = if ($NewName) { Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumegroup" -CmdArgs ("-gui", $NewName) } else { $null }
        if ($newData.err) {
            throw (Resolve-Error -ErrorInput $newData -Category InvalidOperation)
        }

        if ($data -and $newData) {
            throw (Resolve-Error -ErrorInput "Both '$Name' and '$NewName' exist. Cannot rename, cannot proceed with other updates." -Category ResourceExists)
        }
        if (-not $data) {
            if (-not $newData) {
                throw (Resolve-Error -ErrorInput "VolumeGroup '$Name' does not exist." -Category ObjectNotFound)
            }
            Write-IBMSVLog -Level WARN -Message "VolumeGroup '$NewName' already exists. Continuing other updates on '$NewName' VolumeGroup."
            $data = $newData
            $Name = $NewName
        }

        # --- Update Volume Group ---
        if ($PSCmdlet.ShouldProcess("Volume Group '$Name'", 'Modify')) {

            if (($PSBoundParameters.ContainsKey('SnapshotPolicy') -and $PSBoundParameters.ContainsKey('PolicyStartTime')) -or $PSBoundParameters.ContainsKey('SnapshotPolicySuspended')) {
                $spData = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumegroupsnapshotpolicy" -CmdArgs $Name
                if ($spData.err) {
                    throw (Resolve-Error -ErrorInput $spData -Category InvalidOperation)
                }
                if ($spData) {
                    $data | Add-Member -NotePropertyName snapshot_policy_start_time -NotePropertyValue $spData.snapshot_policy_start_time -Force
                    $data | Add-Member -NotePropertyName snapshot_policy_suspended -NotePropertyValue $spData.snapshot_policy_suspended -Force
                }
            }

            # --- Probe logic ---
            $props = @{}
            $paramsMapping = @(
                @{ Key = 'NewName'; Existing = $data.name; paramName = 'name' }
                @{ Key = 'OwnershipGroup'; Existing = $data.owner_name }
                @{ Key = 'NoOwnershipGroup'; Existing = -not [bool]$data.owner_name }
                @{ Key = 'NoSafeguardedPolicy'; Existing = -not [bool]$data.safeguarded_policy_name }
                @{ Key = 'NoSnapshotPolicy'; Existing = -not [bool]$data.snapshot_policy_name }
                @{ Key = 'ReplicationPolicy'; Existing = $data.replication_policy_name }
                @{ Key = 'NoDRReplication'; Existing = -not [bool]$data.replication_policy_name }
                @{ Key = 'IgnoreUserFCMaps'; Existing = $data.ignore_user_flash_copy_maps }
                @{ Key = 'DraftPartition'; Existing = $data.draft_partition_name }
                @{ Key = 'SnapshotPolicySuspended'; Existing = $data.snapshot_policy_suspended }
            )
            foreach ($item in $paramsMapping) {
                if ($PSBoundParameters.ContainsKey($item.Key)) {
                    $inputValue = Get-Variable -Name $item.Key -ValueOnly
                    $paramName = if ($item.paramName) { $item.paramName } else { $item.Key.ToLower() }
                    if ($inputValue -and $inputValue -ne $item.Existing) {
                        if ($inputValue -is [System.Management.Automation.SwitchParameter]) { $inputValue = $true }
                        $props[$paramName] = $inputValue

                        if ($paramName -eq 'nosnapshotpolicy' -and $PSBoundParameters.ContainsKey('RetainBackupEnabled')) {
                            $props['retainbackupenabled'] = $true
                        }
                    }
                }
            }
            if ($NoDRReplication -and $data.replication_policy_name) {
                $version = Get-IBMSVVersion -Cluster $Cluster
                if ($version.err) {
                    throw (Resolve-Error -ErrorInput $version.err -Category InvalidOperation)
                }
                if ($version -lt "8.7.1.0") { $props['noreplicationpolicy'] = $true }
                else { $props['nodrreplication'] = $true }
            }
            if ($SafeguardedPolicy) {
                if ($SafeguardedPolicy -ne $data.safeguarded_policy_name) {
                    $props['safeguardedpolicy'] = $SafeguardedPolicy
                    if ($PolicyStartTime) {
                        $props['policystarttime'] = $PolicyStartTime
                    }
                }
                elseif ($PolicyStartTime -and (($PolicyStartTime + '00') -ne $data.safeguarded_policy_start_time)) {
                    # Adds '00' for seconds to match backend timestamp format (YYMMDDHHMMSS)
                    $props['safeguardedpolicy'] = $SafeguardedPolicy
                    $props['policystarttime'] = $PolicyStartTime
                }
            }
            elseif ($SnapshotPolicy) {
                if ($SnapshotPolicy -ne $data.snapshot_policy_name) {
                    $props['snapshotpolicy'] = $SnapshotPolicy
                    if ($Safeguarded) {
                        $props['safeguarded'] = $true
                    }
                    if ($PolicyStartTime) {
                        $props['policystarttime'] = $PolicyStartTime
                    }
                }
                else {
                    if ($PolicyStartTime -and (($PolicyStartTime + '00') -ne $data.snapshot_policy_start_time)) {
                        # Adds '00' for seconds to match backend timestamp format (YYMMDDHHMMSS)
                        $props['snapshotpolicy'] = $SnapshotPolicy
                        $props['policystarttime'] = $PolicyStartTime
                    }
                    if ($Safeguarded -and ($Safeguarded -ne [bool]($data.snapshot_policy_safeguarded -eq 'yes'))) {
                        $props['snapshotpolicy'] = $SnapshotPolicy
                        $props['safeguarded'] = $true
                    }
                }
            }
            if ($DraftPartition -and $DraftPartition -eq $data.partition_name) {
                Write-IBMSVLog -Level INFO -Message "Partition '$DraftPartition' containing Volume Group '$Name' is already published."
                $props.remove('draftpartition')
            }
            if ($props.Count -eq 0) { Write-IBMSVLog -Level INFO -Message "No changes required for Volume Group '$Name'."; return }

            # --- Apply changes ---
            if ($props.ContainsKey('snapshotpolicysuspended')) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chvolumegroupsnapshotpolicy" -CmdOpts @{ snapshotpolicysuspended = $props['snapshotpolicysuspended'] } -CmdArgs $Name
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                $props.remove('snapshotpolicysuspended')
            }

            $groups = Resolve-MutexGroup -Props $props -Rules $batchMutexRules -Dependencies $dependencies
            foreach ($g in $groups) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chvolumegroup" -CmdOpts $g -CmdArgs $Name
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                if ($g.ContainsKey('name')) { $Name = $g['name'] }
            }
            Write-IBMSVLog -Level INFO -Message "Volume Group '$Name' updated successfully."
        }
    }
}
