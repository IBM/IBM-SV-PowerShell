<#
.SYNOPSIS
Removes an existing DNS server from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVDNSServer cmdlet deletes a DNS server entry.

.PARAMETER Name
Specifies the name of the DNS server to remove.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Remove-IBMSVDNSServer -Name dns1
Removes the DNS server.

.EXAMPLE
PS> Remove-IBMSVDNSServer -Name dns1 -WhatIf
Shows what would happen without removing the DNS server.

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
https://www.ibm.com/docs/en/search/rmdnsserver
#>

function Remove-IBMSVDNSServer {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$Cluster
    )

    process {
        # --- Remove DNS Server ---
        if ($PSCmdlet.ShouldProcess("DNS Server '$Name'", "Remove")) {

            # --- Existence check ---
            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsdnsserver" -CmdArgs $Name
            if ($current.err) {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            if (-not $current) {
                Write-IBMSVLog -Level INFO -Message "DNS Server '$Name' does not exist."
                return
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmdnsserver" -CmdArgs $Name
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "DNS Server '$Name' removed successfully."
        }
    }
}
