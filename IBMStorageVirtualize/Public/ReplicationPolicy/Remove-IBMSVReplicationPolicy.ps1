<#
.SYNOPSIS
Removes an existing replication policy from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVReplicationPolicy cmdlet deletes a replication policy from the system.

.PARAMETER Name
Specifies the name of the replication policy to remove.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Remove-IBMSVReplicationPolicy -Name replication_policy0
Removes the replication policy.

.EXAMPLE
PS> Remove-IBMSVReplicationPolicy -Name replication_policy0 -WhatIf
Shows what would happen if the replication policy was removed.

.EXAMPLE
PS> Remove-IBMSVReplicationPolicy -Name replication_policy0 -Confirm:$false
Removes the replication policy without confirmation.

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
https://www.ibm.com/docs/en/search/rmreplicationpolicy
#>

function Remove-IBMSVReplicationPolicy {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$Cluster
    )

    process {
        # --- Remove Replication Policy ---
        if ($PSCmdlet.ShouldProcess("Replication Policy '$Name'", "Remove")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsreplicationpolicy" -CmdArgs $Name
            if ($existing -and $existing.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
            }
            if (-not $existing) {
                Write-IBMSVLog -Level INFO -Message "Replication Policy '$Name' does not exist."
                return
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmreplicationpolicy" -CmdArgs $Name
            if ($result -and $result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Replication Policy '$Name' removed successfully."
        }
    }
}
