<#
.SYNOPSIS
Removes an existing snapshot policy from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVSnapshotPolicy cmdlet deletes a snapshot policy from the system.

.PARAMETER Name
Specifies the name of the snapshot policy to remove.

.PARAMETER RemoveFromVolumeGroups
Specifies that the volume group association from the snapshot policy is removed.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Remove-IBMSVSnapshotPolicy -Name policy0
Removes the snapshot policy.

.EXAMPLE
PS> Remove-IBMSVSnapshotPolicy -Name policy0 -RemoveFromVolumeGroups
Removes the snapshot policy and its volume group associations.

.EXAMPLE
PS> Remove-IBMSVSnapshotPolicy -Name policy0 -WhatIf
Shows what would happen if the snapshot policy were removed.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- This is a destructive operation and cannot be undone.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/rmsnapshotpolicy
#>

function Remove-IBMSVSnapshotPolicy {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [switch]$RemoveFromVolumeGroups,

        [string]$Cluster
    )

    process {
        # --- Remove Snapshot Policy ---
        if ($PSCmdlet.ShouldProcess("Snapshot Policy '$Name'", "Remove")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lssnapshotpolicy" -CmdArgs $Name
            if ($existing -and $existing.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
            }
            if (-not $existing) {
                Write-IBMSVLog -Level INFO -Message "Snapshot Policy '$Name' does not exist."
                return
            }

            $opts = @{}
            if ($RemoveFromVolumeGroups) {
                $opts['removefromvolumegroups'] = $true
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmsnapshotpolicy" -CmdOpts $opts -CmdArgs $Name
            if ($result -and $result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Snapshot Policy '$Name' removed successfully."
        }
    }
}
