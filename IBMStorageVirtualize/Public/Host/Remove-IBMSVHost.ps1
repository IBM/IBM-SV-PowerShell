<#
.SYNOPSIS
Removes an existing host from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVHost cmdlet deletes a host from the system.

It maps to the rmhost command.

The cmdlet is idempotent:
- If the specified host does not exist, no action is performed.

Supports -WhatIf and -Confirm for safe execution.
Due to the destructive nature, confirmation is required by default.

.PARAMETER Name
Specifies the name of the host to remove.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Remove-IBMSVHost -Name Host1

Removes the host.

.EXAMPLE
PS> Remove-IBMSVHost -Name Host2 -WhatIf

Shows what would happen without removing the host.

.EXAMPLE
PS> Remove-IBMSVHost -Name Host3 -Confirm:$false

Removes the host without confirmation.

.EXAMPLE
PS> Get-IBMSVHost | Where-Object { $_.name -like "test*" } | Remove-IBMSVHost

Removes hosts using pipeline input.

.INPUTS
System.String

You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- This is a destructive operation and cannot be undone.
- If the host does not exist, the operation completes silently.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/rmhost
#>

function Remove-IBMSVHost {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$Cluster
    )

    process {
        # --- Remove host ---
        if ($PSCmdlet.ShouldProcess("Host $Name", "Remove")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lshost" -CmdArgs $Name
            if ($existing.err) {
                throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
            }
            if (-not $existing) {
                Write-IBMSVLog -Level INFO -Message "Host '$Name' does not exist."
                return
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmhost" -CmdArgs $Name
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Host '$Name' removed successfully."
        }
    }
}
