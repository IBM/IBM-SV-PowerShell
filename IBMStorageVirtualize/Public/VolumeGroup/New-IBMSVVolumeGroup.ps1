<#
.SYNOPSIS
Creates a new volumegroup in an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVVolumeGroup cmdlet creates a volumegroup.

It maps to the mkvolumegroup command.

The cmdlet is idempotent:
- If the specified volumegroup already exists, the existing object is returned.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER Name
Specifies the name of the volumegroup.

.PARAMETER OwnershipGroup
Specifies the ownership group for the volumegroup.

Mutually exclusive with -SafeguardedPolicy and -SnapshotPolicy.

.PARAMETER Partition
Specifies the partition for the volumegroup.

Mutually exclusive with -DraftPartition.

.PARAMETER IgnoreUserFCMaps
Specifies that user-created FlashCopy mappings are ignored.

.PARAMETER SnapshotPolicy
Specifies the snapshot policy for the volumegroup.

Mutually exclusive with -OwnershipGroup and -SetPartitionDefault.

.PARAMETER ReplicationPolicy
Specifies the replication policy for the volumegroup.

Mutually exclusive with -DraftPartition and -SetPartitionDefault.

.PARAMETER SafeguardedPolicy
Specifies the safeguarded policy for the volumegroup.

Mutually exclusive with -OwnershipGroup, -Safeguarded, and -SetPartitionDefault.

.PARAMETER PolicyStartTime
Specifies the policy start time in ISO 8601 format.

Requires -SafeguardedPolicy or -SnapshotPolicy.

.PARAMETER Safeguarded
Specifies that the volumegroup is safeguarded.

Requires -SnapshotPolicy.
Mutually exclusive with -SafeguardedPolicy.

.PARAMETER DraftPartition
Specifies the draft partition for the volumegroup.

Mutually exclusive with -Partition and -ReplicationPolicy.

.PARAMETER SetPartitionDefault
Specifies that the partition is set as default.

Mutually exclusive with -SafeguardedPolicy, -ReplicationPolicy, and -SnapshotPolicy.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> New-IBMSVVolumeGroup -Name vg1

Creates a volumegroup.

.EXAMPLE
PS> New-IBMSVVolumeGroup -Name vg1 -SnapshotPolicy snap_policy1

Creates a volumegroup with a snapshot policy.

.EXAMPLE
PS> New-IBMSVVolumeGroup -Name vg1 -SnapshotPolicy snap_policy1 -Safeguarded -IgnoreUserFCMaps

Creates a safeguarded volumegroup.

.EXAMPLE
PS> New-IBMSVVolumeGroup -Name vg1 -SnapshotPolicy snap_policy1 -ReplicationPolicy rep_policy1

Creates a volumegroup with snapshot and replication policies.

.INPUTS
System.String

You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
System.Object

Returns the created volumegroup object.

If the volumegroup already exists, the existing object is returned.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Performs validation of parameter combinations before execution.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkvolumegroup
#>

function New-IBMSVVolumeGroup {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$OwnershipGroup,

        [string]$Partition,

        [switch]$IgnoreUserFCMaps,

        [string]$SnapshotPolicy,

        [string]$ReplicationPolicy,

        [string]$SafeguardedPolicy,

        [string]$PolicyStartTime,

        [switch]$Safeguarded,

        [string]$DraftPartition,

        [switch]$SetPartitionDefault,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        $mutexrules = @{
            mutex1  = @('OwnershipGroup', 'SafeguardedPolicy', 'SnapshotPolicy')
            mutex2  = @('Safeguarded', 'SafeguardedPolicy')
            mutex6  = @('Partition', 'DraftPartition')
            mutex7  = @('ReplicationPolicy', 'DraftPartition')
            mutex11 = @('SafeguardedPolicy', 'SetPartitionDefault')
            mutex12 = @('ReplicationPolicy', 'SetPartitionDefault')
            mutex15 = @('SnapshotPolicy', 'SetPartitionDefault')
        }
        foreach ($rule in $mutexrules.Values) {
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

        # --- Create Volume Group ---
        if ($PSCmdlet.ShouldProcess("Volume Group $Name", "Create")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumegroup" -CmdArgs ($Name)
            if ($existing) {
                if ($existing.err) {
                    throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
                }
                Write-IBMSVLog -Level INFO -Message "Volume Group '$Name' already exists. Returning existing object."
                return $existing
            }

            $opts = @{ name = $Name }
            foreach ($field in @('OwnershipGroup', 'Partition', 'DraftPartition', 'SetPartitionDefault', 'IgnoreUserFCMaps', 'ReplicationPolicy', 'SafeguardedPolicy', 'SnapshotPolicy', 'PolicyStartTime', 'Safeguarded')) {
                if ($PSBoundParameters.ContainsKey($field)) {
                    $value = $PSBoundParameters[$field]
                    if ($null -ne $value -and $value -ne '') {
                        if ($value -is [System.Management.Automation.SwitchParameter]) {
                            $opts[$field.ToLower()] = if ($value.IsPresent) { $true } else { $false }
                        }
                        else {
                            $opts[$field.ToLower()] = $value
                        }
                    }
                }
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "mkvolumegroup" -CmdOpts $opts
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Volume Group [$($result.id)] '$Name' created successfully."

            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumegroup" -CmdArgs ($Name)
            if ($current.err) {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            return $current
        }
    }
}
