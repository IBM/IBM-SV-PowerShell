<#
.SYNOPSIS
Creates a new storage partition on an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVPartition cmdlet creates a storage partition on an IBM Storage Virtualize system.

.PARAMETER Name
Specifies the name of the storage partition to create.

.PARAMETER Draft
Specifies that the partition is created in draft state.
If not specified or set to false, the partition is created in published state.

.PARAMETER ReplicationPolicy
Specifies the replication policy for the storage partition.

.PARAMETER ManagementPortset
Specifies the management portset to be assigned to the partition.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> New-IBMSVPartition -Name partition1
Creates a storage partition in published state.

.EXAMPLE
PS> New-IBMSVPartition -Name partition1 -Draft
Creates a storage partition in draft state.

.EXAMPLE
PS> New-IBMSVPartition -Name partition1 -ReplicationPolicy ha_policy_1
Creates a storage partition with a replication policy.

.EXAMPLE
PS> New-IBMSVPartition -Name partition1 -ManagementPortset portset1
Creates a storage partition with a management portset.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
System.Object
Returns the created partition object, or the existing partition object if it already exists.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkpartition
#>

function New-IBMSVPartition {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [switch]$Draft,

        [string]$ReplicationPolicy,

        [string]$ManagementPortset,

        [string]$OwnershipGroup,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        $validationMutexRules = @{
            mutex1 = @('ReplicationPolicy', 'ManagementPortset')
            mutex2 = @('OwnershipGroup', 'ReplicationPolicy')
        }
        foreach ($rule in $validationMutexRules.Values) {
            $present = $rule | Where-Object { $PSBoundParameters.ContainsKey($_) }
            if ($present.Count -gt 1) {
                throw (Resolve-Error -ErrorInput "Parameters $($present -join ', ') are mutually exclusive." -Category InvalidArgument)
            }
        }

        # --- Create Partition ---
        if ($PSCmdlet.ShouldProcess("Partition '$Name'", "Create")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lspartition" -CmdArgs ($Name)
            if ($existing) {
                if ($existing.err) {
                    throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
                }
                Write-IBMSVLog -Level INFO -Message "Partition '$Name' already exists. Returning existing object."
                return $existing
            }

            $opts = @{ name = $Name }
            foreach ($field in @('Draft', 'ReplicationPolicy', 'ManagementPortset', 'OwnershipGroup')) {
                if ($PSBoundParameters.ContainsKey($field)) {
                    $value = $PSBoundParameters[$field]

                    if ($null -ne $value -and $value -ne '') {
                        if ($value -is [System.Management.Automation.SwitchParameter]) {
                            $opts[$field.ToLower()] = $value.IsPresent
                        }
                        else {
                            $opts[$field.ToLower()] = $value
                        }
                    }
                }
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "mkpartition" -CmdOpts $opts
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Partition [$($result.id)] '$Name' created successfully."

            $maxRetries = 3
            for ($attempt = 1; ; $attempt++) {
                $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lspartition" -CmdArgs $Name
                if (-not $current.err) {
                    break
                }

                $retry = $attempt -lt $maxRetries -and ($current.out -match '(?i)connection refused' -or $current.err -match '(?i)connection refused')
                if (-not $retry) {
                    throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
                }

                Start-Sleep -Milliseconds 1500
            }
            return $current
        }
    }
}
