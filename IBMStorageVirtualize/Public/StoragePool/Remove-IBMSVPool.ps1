<#
.SYNOPSIS
Removes an existing storage pool (MDisk Group) from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVPool cmdlet deletes a storage pool (MDisk Group) from the system.

It maps to the rmmdiskgrp command.

The cmdlet is idempotent:
- If the pool does not exist, no action is performed.

Supports -WhatIf and -Confirm for safe execution.
Due to the destructive nature, confirmation is required by default.

.PARAMETER Name
Specifies the name of the pool to remove.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Remove-IBMSVPool -Name Pool1

Removes the specified pool.
Prompts for confirmation before deletion.

.EXAMPLE
PS> Remove-IBMSVPool -Name Pool1 -Confirm:$false

Removes the pool without prompting for confirmation.

.EXAMPLE
PS> Remove-IBMSVPool -Name Pool1 -WhatIf

Shows what would happen if the pool were removed.

.INPUTS
System.String

You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- This is a destructive operation and cannot be undone.
- If the pool does not exist, the operation completes silently.
- Fully supports -WhatIf and -Confirm.

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
