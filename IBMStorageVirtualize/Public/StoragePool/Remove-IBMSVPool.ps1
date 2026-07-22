<#
.SYNOPSIS
Removes an existing storage pool from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVPool cmdlet deletes a storage pool from the system.

.PARAMETER Name
Specifies the name of the pool to remove.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Remove-IBMSVPool -Name Pool1
Removes the specified pool.

.EXAMPLE
PS> Remove-IBMSVPool -Name Pool1 -WhatIf
Shows what would happen if the pool were removed.

.EXAMPLE
PS> Remove-IBMSVPool -Name Pool1 -Confirm:$false
Removes the pool without confirmation.

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
https://www.ibm.com/docs/en/search/rmmdiskgrp
#>

function Remove-IBMSVPool {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$Cluster
    )

    process {
        # --- Remove Pool ---
        if ($PSCmdlet.ShouldProcess("Pool '$Name'", "Remove")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsmdiskgrp" -CmdArgs $Name
            if ($existing.err) {
                throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
            }
            if (-not $existing) {
                Write-IBMSVLog -Level INFO -Message "Pool '$Name' does not exist."
                return
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmmdiskgrp" -CmdArgs $Name
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Pool '$Name' removed successfully."
        }
    }
}
