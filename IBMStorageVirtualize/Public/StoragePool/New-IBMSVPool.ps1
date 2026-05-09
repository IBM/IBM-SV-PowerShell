<#
.SYNOPSIS
Creates a new storage pool (MDisk Group) in an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVPool cmdlet creates a storage pool (MDisk Group) with specified attributes.

It maps to the mkmdiskgrp command.

The cmdlet is idempotent:
- If a pool with the specified name already exists, the existing object is returned.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER Name
Specifies the name of the pool to create.

.PARAMETER Mdisk
Specifies one or more MDisks to include in the pool.

.PARAMETER Tier
Specifies the storage tier for the pool.
Valid values: tier0_flash, tier1_flash, tier_enterprise, tier_nearline, tier_scm.

.PARAMETER Ext
Specifies the extent size (in MB) for the pool.

Required when creating a standard pool (without -ParentMdiskGrp).

.PARAMETER ParentMdiskGrp
Specifies the parent pool for creating a child pool.

When specified:
- Parameters -Ext, -Tier, and -EasyTier cannot be used.
- Additional constraints apply based on parent pool type.

.PARAMETER Size
Specifies the size of the child pool.

Must be used with -Unit.
Mutually exclusive with -NoQuota.

.PARAMETER NoQuota
Specifies that the child pool has no quota.

Mutually exclusive with -Size.

.PARAMETER Safeguarded
Specifies that the pool is safeguarded.

Mutually exclusive with -Owner and -OwnershipGroup.

.PARAMETER Warning
Specifies the warning threshold for pool capacity.

.PARAMETER Unit
Specifies the unit for -Size or -Warning.
Valid values: b, kb, mb, gb, tb, pb.

.PARAMETER EasyTier
Specifies the Easy Tier setting for the pool.
Valid values: on, off, auto, measure.

Cannot be used with -ParentMdiskGrp.

.PARAMETER Owner
Specifies the owner of the pool.

Mutually exclusive with -Safeguarded.

.PARAMETER OwnershipGroup
Specifies the ownership group of the pool.

Mutually exclusive with -Safeguarded.

.PARAMETER Encrypt
Specifies whether encryption is enabled for the pool.
Valid values: yes, no.

.PARAMETER DataReduction
Specifies whether data reduction is enabled.
Valid values: yes, no.

Required when creating a child pool from a data reduction parent.

.PARAMETER ProvisioningPolicy
Specifies the provisioning policy for the pool.

.PARAMETER EtfcmOverAllocationMax
Specifies the maximum over-allocation for thin provisioning.

.PARAMETER VdiskProtectionEnabled
Specifies whether VDisk protection is enabled.
Valid values: yes, no.

.PARAMETER ReplicationPoolLinkUid
Specifies the replication pool link UID.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> New-IBMSVPool -Name Pool1 -Mdisk Mdisk1,Mdisk2 -Tier tier_enterprise -Ext 1024

Creates a standard pool using specified MDisks and extent size.

.EXAMPLE
PS> New-IBMSVPool -Name Pool1 -Mdisk Mdisk1,Mdisk2 -Tier tier_enterprise -Ext 1024 -Encrypt yes

Creates an encrypted pool.

.EXAMPLE
PS> New-IBMSVPool -Name ChildPool -ParentMdiskGrp ParentPool -Size 500 -Unit gb

Creates a child pool with a defined quota.

.EXAMPLE
PS> New-IBMSVPool -Name DRChildPool -ParentMdiskGrp ParentPool -DataReduction yes -NoQuota

Creates a data reduction child pool without quota.

.INPUTS
System.String

You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
System.Object

Returns the created pool object.

If the pool already exists, the existing object is returned.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Performs validation of parameter combinations before execution.
- Supports both standard and child pool creation.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkmdiskgrp
#>

function New-IBMSVPool {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string[]]$Mdisk,

        [ValidateSet("tier0_flash", "tier1_flash", "tier_enterprise", "tier_nearline", "tier_scm")]
        [string] $Tier,

        [int]$Ext,

        [string]$ParentMdiskGrp,

        [int]$Size,

        [switch]$NoQuota,

        [switch]$Safeguarded,

        [string]$Owner,

        [string]$OwnershipGroup,

        [string]$Warning,

        [ValidateSet("b", "kb", "mb", "gb", "tb", "pb")]
        [string]$Unit,

        [ValidateSet("on", "off", "auto", "measure")]
        [string]$EasyTier,

        [ValidateSet("yes", "no")]
        [string]$Encrypt,

        [ValidateSet("yes", "no")]
        [string]$DataReduction,

        [string]$ProvisioningPolicy,

        [string]$EtfcmOverAllocationMax,

        [ValidateSet("yes", "no")]
        [string]$VdiskProtectionEnabled,

        [string]$ReplicationPoolLinkUid,

        [string]$Cluster
    )

    process {
        # --- Create Pool ---
        if ($PSCmdlet.ShouldProcess("Pool '$Name'", "Create")) {

            # --- Parameter-level validation ---
            if ($Unit -and (-not $Size -and -not $Warning )) {
                throw (Resolve-Error -ErrorInput "CMMVC5731E Parameter -Unit is invalid without -Size and -Warning." -Category InvalidArgument)
            }
            if ($warning -and $NoQuota) {
                throw (Resolve-Error -ErrorInput "Parameters -warning and -NoQuota are mutually exclusive." -Category InvalidArgument)
            }
            if ($Size -and $NoQuota) {
                throw (Resolve-Error -ErrorInput "Parameters -Size and -NoQuota are mutually exclusive." -Category InvalidArgument)
            }
            if ($Owner -and $Safeguarded) {
                throw (Resolve-Error -ErrorInput "Parameters -Owner and -Safeguarded are mutually exclusive." -Category InvalidArgument)
            }
            if ($OwnershipGroup -and $Safeguarded) {
                throw (Resolve-Error -ErrorInput "Parameters -OwnershipGroup and -Safeguarded are mutually exclusive." -Category InvalidArgument)
            }
            if ($ParentMdiskGrp) {
                if ($Ext) {
                    throw (Resolve-Error -ErrorInput "Parameters -Ext and -ParentMdiskGrp are mutually exclusive." -Category InvalidArgument)
                }
                if ($EasyTier) {
                    throw (Resolve-Error -ErrorInput "Parameters -EasyTier and -ParentMdiskGrp are mutually exclusive." -Category InvalidArgument)
                }
                if ($Tier) {
                    throw (Resolve-Error -ErrorInput "Parameters -Tier and -ParentMdiskGrp are mutually exclusive." -Category InvalidArgument)
                }
                $parentPoolData = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsmdiskgrp" -CmdArgs ($ParentMdiskGrp)
                if ($parentPoolData.err) {
                    throw (Resolve-Error -ErrorInput $parentPoolData -Category InvalidOperation)
                }
                if ($parentPoolData) {
                    if ($parentPoolData.data_reduction -eq "yes") {
                        if ($DataReduction -ne "yes") {
                            throw (Resolve-Error -ErrorInput "CMMVC9576E Specified ParentMdiskGrp is Data Reduction Pool, to create Data Reduction child pool -DataReduction yes is required." -Category InvalidArgument)
                        }
                        if ($Size) {
                            throw (Resolve-Error -ErrorInput "CMMVC9578E Specified ParentMdiskGrp is Data Reduction Pool, to create Data Reduction child pool -Size is not applicable." -Category InvalidArgument)
                        }
                        if ($Encrypt) {
                            throw (Resolve-Error -ErrorInput "CMMVC9575E Specified ParentMdiskGrp is Data Reduction Pool, to create Data Reduction child pool -Encrypt is not applicable." -Category InvalidArgument)
                        }
                        if (-not $NoQuota) {
                            throw (Resolve-Error -ErrorInput "CMMVC5707E Specified ParentMdiskGrp is Data Reduction Pool, to create Data Reduction child pool -NoQuota yes is required." -Category InvalidArgument)
                        }
                    }
                    else {
                        if (-not $Size -and -not $NoQuota) {
                            throw (Resolve-Error -ErrorInput "CMMVC5707E To create Standard Child pool -Size or -NoQuota is required" -Category InvalidArgument)
                        }
                    }
                }
                else {
                    throw (Resolve-Error -ErrorInput "ParentMdiskGrp '$ParentMdiskGrp' does not exist." -Category InvalidArgument)
                }
            }
            else {
                $invalidParams = @()
                if ($Size) { $invalidParams += '-Size' }
                if ($NoQuota) { $invalidParams += '-NoQuota' }
                if ($Safeguarded) { $invalidParams += '-Safeguarded' }
                if ($Owner) { $invalidParams += '-Owner' }
                if ($OwnershipGroup) { $invalidParams += '-OwnershipGroup' }
                if ($invalidParams.Count -gt 0) {
                    throw (Resolve-Error -ErrorInput "CMMVC5731E The parameter(s) $($invalidParams -join ', ') can only be used when -ParentMdiskGrp is specified." -Category InvalidArgument)
                }
                if (-not $Ext) {
                    throw (Resolve-Error -ErrorInput "One of -Ext or -ParentMdiskGrp parameter is required." -Category InvalidArgument)
                }
            }

            $validated = @{}
            if ($Mdisk) {
                $res = ConvertTo-NormalizedValue -Name 'Mdisk' -Value ($Mdisk -join ":") -Separator ":"
                if ($res.err) {
                    throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
                }
                $validated.Mdisk = $res.out
            }

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsmdiskgrp" -CmdArgs ($Name)
            if ($existing) {
                if ($existing.err) {
                    throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
                }
                Write-IBMSVLog -Level INFO -Message "Pool '$Name' already exists. Returning existing object."
                return $existing
            }

            $opts = @{ name = $Name }
            foreach ($param in $validated.keys) {
                $opts[$param.ToLower()] = $validated[$param]
            }
            foreach ($field in @('Tier', 'Ext', 'ParentMdiskGrp', 'Size', 'NoQuota', 'Safeguarded', 'Warning', 'Unit', 'EasyTier', 'Owner', 'Encrypt', 'DataReduction', 'OwnershipGroup', 'ProvisioningPolicy', 'EtfcmOverAllocationMax', 'VdiskProtectionEnabled', 'ReplicationPoolLinkUid')) {
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

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "mkmdiskgrp" -CmdOpts $opts
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "MDiskGrp [$($result.id)] '$Name' created successfully."

            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsmdiskgrp" -CmdArgs ($Name)
            if ($current.err) {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            return $current
        }
    }
}
