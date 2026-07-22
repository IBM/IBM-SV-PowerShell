<#
.SYNOPSIS
Removes an existing portset from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVPortset cmdlet deletes a portset from the system.

.PARAMETER Name
Specifies the name of the portset to remove.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Remove-IBMSVPortset -Name portset1
Removes the portset.

.EXAMPLE
PS> Remove-IBMSVPortset -Name portset1 -WhatIf
Shows what would happen if the portset were removed.

.EXAMPLE
PS> Remove-IBMSVPortset -Name portset1 -Confirm:$false
Removes the portset without confirmation.

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
https://www.ibm.com/docs/en/search/rmportset
#>

function Remove-IBMSVPortset {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$Cluster
    )

    process {
        # --- Remove Portset ---
        if ($PSCmdlet.ShouldProcess("Portset '$Name'", "Remove")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsportset" -CmdArgs $Name
            if ($existing -and $existing.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
            }
            if (-not $existing) {
                Write-IBMSVLog -Level INFO -Message "Portset '$Name' does not exist."
                return
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmportset" -CmdArgs $Name
            if ($result -and $result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Portset '$Name' removed successfully."
        }
    }
}
