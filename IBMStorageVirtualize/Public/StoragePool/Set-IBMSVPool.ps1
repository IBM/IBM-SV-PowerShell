<#
.SYNOPSIS
Modifies an existing storage pool (MDisk Group) in an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVPool cmdlet updates properties of an existing storage pool (MDisk Group).

It maps to the chmdiskgrp command.

The cmdlet is idempotent:
- Only properties that differ from the current configuration are modified.
- If no changes are required, no operation is performed.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER Name
Specifies the name of the pool to modify.

.PARAMETER NewName
Specifies a new name for the pool.

If both Name and NewName exist, the operation fails.

If the specified Name does not exist but NewName exists, the cmdlet continues updating the NewName pool.

.PARAMETER Size
Specifies the new size of the pool.

If -Unit is specified, the value is interpreted accordingly.
Shrink operations are validated to ensure the size is not less than used capacity.

.PARAMETER Warning
Specifies the warning threshold for the pool.

Can be specified as:
- A percentage (for example, 80%), or
- An absolute value used with -Unit

.PARAMETER Unit
Specifies the unit for -Size or -Warning.
Valid values: b, kb, mb, gb, tb, pb.

.PARAMETER EasyTier
Specifies the Easy Tier setting.
Valid values: on, off, auto, measure.

.PARAMETER OwnershipGroup
Specifies the ownership group for the pool.

.PARAMETER NoOwnershipGroup
Specifies that the ownership group should be removed.

Mutually exclusive with -OwnershipGroup.

.PARAMETER ProvisioningPolicy
Specifies the provisioning policy for the pool.

.PARAMETER NoProvisioningPolicy
Specifies that the provisioning policy should be removed.

Mutually exclusive with -ProvisioningPolicy.

.PARAMETER EtfcmOverAllocationMax
Specifies the Easy Tier FCM over-allocation limit.

Accepts percentage values (for example, 20%) or 'off'.

.PARAMETER VdiskProtectionEnabled
Specifies whether VDisk protection is enabled.
Valid values: yes, no.

.PARAMETER ReplicationPoolLinkUid
Specifies the replication pool link UID.

.PARAMETER MovePoolLink
Specifies that the replication pool link should be moved.

Requires -ReplicationPoolLinkUid.

.PARAMETER ResetReplicationPoolLinkUid
Specifies that the replication pool link UID should be reset.

.PARAMETER ReplaceExistingLink
Specifies that any existing replication link should be replaced.

Requires -ReplicationPoolLinkUid or -ResetReplicationPoolLinkUid.

.PARAMETER ReplicationPartnerClusterid
Specifies the partner cluster ID for replication configuration.

Mutually exclusive with:
- -ReplicationPoolLinkUid
- -ResetReplicationPoolLinkUid

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Set-IBMSVPool -Name Pool1 -NewName Pool2 -Size 500 -Unit gb

Renames `Pool1` to `Pool2` and sets its size to 500 GB.

.EXAMPLE
PS> Set-IBMSVPool -Name Pool1 -ReplicationPoolLinkUid 12345 -MovePoolLink

Updates replication pool link configuration.

.INPUTS
System.String

You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- If the specified pool does not exist, a terminating error is thrown.
- If both Name and NewName exist, the operation fails.
- Only modified properties are sent to the backend.
- Performs validation of parameter combinations before execution.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chmdiskgrp
#>

function Set-IBMSVPool {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]

    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$NewName,

        [int64]$Size,

        [string]$Warning,

        [ValidateSet("b", "kb", "mb", "gb", "tb", "pb")]
        [string]$Unit,

        [ValidateSet("on", "off", "auto", "measure")]
        [string]$EasyTier,

        [string]$OwnershipGroup,

        [switch]$NoOwnershipGroup,

        [string]$ProvisioningPolicy,

        [switch]$NoProvisioningPolicy,

        [string]$EtfcmOverAllocationMax,

        [ValidateSet("yes", "no")]
        [string]$VdiskProtectionEnabled,

        [string]$ReplicationPoolLinkUid,

        [switch]$MovePoolLink,

        [switch]$ResetReplicationPoolLinkUid,

        [switch]$ReplaceExistingLink,

        [string]$ReplicationPartnerClusterid,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        if ($Unit -and (-not $Size -and -not $Warning )) {
            throw (Resolve-Error -ErrorInput "CMMVC5731E Parameter -Unit is invalid without -Size and -Warning." -Category InvalidArgument)
        }
        if ($MovePoolLink -and -not $ReplicationPoolLinkUid) {
            throw (Resolve-Error -ErrorInput "Parameter -MovePoolLink is invalid without -ReplicationPoolLinkUid." -Category InvalidArgument)
        }
        if ($ReplaceExistingLink -and (-not $ReplicationPoolLinkUid -and -not $ResetReplicationPoolLinkUid)) {
            throw (Resolve-Error -ErrorInput "Parameter -ReplaceExistingLink is invalid without -ReplicationPoolLinkUid or -ResetReplicationPoolLinkUid." -Category InvalidArgument)
        }
        if ($OwnershipGroup -and $NoOwnershipGroup) {
            throw (Resolve-Error -ErrorInput "Parameters -OwnershipGroup and -NoOwnershipGroup are mutually exclusive." -Category InvalidArgument)
        }
        if ($ProvisioningPolicy -and $NoProvisioningPolicy) {
            throw (Resolve-Error -ErrorInput "Parameters -ProvisioningPolicy and -NoProvisioningPolicy are mutually exclusive." -Category InvalidArgument)
        }

        $MutexParams = @()
        if ($ReplicationPoolLinkUid) { $MutexParams += '-ReplicationPoolLinkUid' }
        if ($ResetReplicationPoolLinkUid) { $MutexParams += '-ResetReplicationPoolLinkUid' }
        if ($ReplicationPartnerClusterid) { $MutexParams += '-ReplicationPartnerClusterid' }
        if ($MutexParams.Count -gt 1) {
            throw (Resolve-Error -ErrorInput "Parameters $($MutexParams -join ', ') are mutually exclusive." -Category InvalidArgument)
        }

        # --- Initial check ---
        if ($NewName -and $NewName -eq $Name) { $NewName = $null }
        $data = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsmdiskgrp" -CmdArgs ("-gui", "-bytes", $Name)
        if ($data.err) {
            throw (Resolve-Error -ErrorInput $data -Category InvalidOperation)
        }

        $newData = if ($NewName) { Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsmdiskgrp" -CmdArgs ("-gui", "-bytes", $NewName) } else { $null }
        if ($newData.err) {
            throw (Resolve-Error -ErrorInput $newData -Category InvalidOperation)
        }

        if ($data -and $newData) {
            throw (Resolve-Error -ErrorInput "Both '$Name' and '$NewName' exist. Cannot rename, cannot proceed with other updates." -Category ResourceExists)
        }
        if (-not $data) {
            if (-not $newData) {
                throw (Resolve-Error -ErrorInput "Pool '$Name' does not exist." -Category ObjectNotFound)
            }
            Write-IBMSVLog -Level WARN -Message "Pool '$NewName' already exists. Continuing other updates on '$NewName' Pool."
            $data = $newData
            $Name = $NewName
        }

        # --- Update Pool ---
        if ($PSCmdlet.ShouldProcess("Pool '$Name'", "Modify")) {

            # --- Probe logic ---
            $props = @{}
            $paramsMapping = @(
                @{ Key = 'NewName'; Existing = $data.name; paramName = 'name' }
                @{ Key = 'EasyTier'; Existing = $data.easy_tier }
                @{ Key = 'OwnershipGroup'; Existing = $data.owner_name }
                @{ Key = 'NoOwnershipGroup'; Existing = -not [bool]$data.owner_name }
                @{ Key = 'ProvisioningPolicy'; Existing = $data.provisioning_policy_name }
                @{ Key = 'NoProvisioningPolicy'; Existing = -not [bool]$data.provisioning_policy_name }
                @{ Key = 'VdiskProtectionEnabled'; Existing = $data.vdisk_protection_enabled }
                @{ Key = 'ReplicationPoolLinkUid'; Existing = $data.replication_pool_link_uid }
                @{ Key = 'ResetReplicationPoolLinkUid'; Existing = -not [bool]$data.replication_pool_link_uid }
            )
            foreach ($item in $paramsMapping) {
                if ($PSBoundParameters.ContainsKey($item.Key)) {
                    $inputValue = Get-Variable -Name $item.Key -ValueOnly
                    $paramName = if ($item.paramName) { $item.paramName } else { $item.Key.ToLower() }
                    if ($inputValue -and $inputValue -ne $item.Existing) {
                        if ($inputValue -is [System.Management.Automation.SwitchParameter]) { $inputValue = $true }
                        $props[$paramName] = $inputValue

                        if ($paramName -eq 'resetreplicationpoollinkuid' -and $PSBoundParameters.ContainsKey('ReplaceExistingLink')) {
                            $props['replaceexistinglink'] = $true
                        }
                    }
                }
            }

            if ($Size) {
                $unitUsed = if ($Unit) { $Unit } else { 'mb' }
                $inputSize = ConvertTo-Byte -Size $Size -Unit $unitUsed
                $existingSize = [int64]($data.capacity)
                if ($inputSize -ne $existingSize) {
                    if ($inputSize -lt $existingSize) {
                        $usedCapacity = if ($data.used_capacity) { [int64]$data.used_capacity } else { 0 }
                        if ($inputSize -lt $usedCapacity) {
                            throw (Resolve-Error -ErrorInput "CMMVC8427E Requested size is smaller than used capacity. Shrink denied." -Category InvalidOperation)
                        }
                    }
                    $props['size'] = $Size
                    if ($Unit) { $props['unit'] = $Unit }
                }
            }
            if ($Warning) {
                $inputPercent = [int]($Warning.TrimEnd('%'))
                $existingPercent = [int]($data.warning)
                if ($Warning -match '^\d+%$') {
                    if ($inputPercent -ne $existingPercent) {
                        $props["warning"] = $Warning
                    }
                }
                else {
                    $existingPercent = [int]$data.warning
                    $capacityBytes = [int64]$data.capacity

                    $unitUsed = if ($Unit) { $Unit } else { 'mb' }
                    $inputBytes = ConvertTo-Byte -Size $Warning -Unit $unitUsed
                    $inputBytes = [math]::Ceiling($inputBytes / 512) * 512

                    $inputPercent = ($inputBytes / $capacityBytes) * 100
                    $inputPercentRounded = [math]::Round($inputPercent, 0, [MidpointRounding]::AwayFromZero)

                    if ($inputPercentRounded -ne $existingPercent) {
                        $props["warning"] = $Warning
                        if ($Unit) { $props['unit'] = $Unit }
                    }
                }
            }
            if ($EtfcmOverAllocationMax) {
                $value = $EtfcmOverAllocationMax
                if ($value -notmatch '^\d+%$' -and $value -ne 'off') { $value = "$value%" }
                if ($value -ne $data.easy_tier_fcm_over_allocation_max) { $props['etfcmoverallocationmax'] = $value }
            }
            if ($MovePoolLink) { $props["movepoollink"] = $true }
            if ($ReplaceExistingLink) { $props["replaceexistinglink"] = $true }
            if ($ReplicationPartnerClusterid) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lspartnership" -CmdArgs ("-gui", $ReplicationPartnerClusterid)
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                if ($result) {
                    $bitMask = "1".PadRight([int]$result.partnership_index + 1, "0")
                    $bitMask64 = $bitMask.PadLeft(64, "0")
                    if ($bitMask64 -ne $data.replication_pool_linked_systems_mask) {
                        $props['replicationpoollinkedsystemsmask'] = $bitMask
                    }
                }
                else {
                    throw (Resolve-Error -ErrorInput "Partnership does not exist for the given cluster '$($ReplicationPartnerClusterid)'." -Category ObjectNotFound)
                }
            }
            if ($props.Count -eq 0) { Write-IBMSVLog -Level INFO -Message "No changes required for Pool '$Name'."; return }

            # --- Apply changes ---
            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chmdiskgrp" -CmdOpts $props -CmdArgs $Name
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Pool '$Name' updated successfully."
        }
    }
}
