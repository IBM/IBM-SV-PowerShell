<#
.SYNOPSIS
Modifies an existing DNS server.

.DESCRIPTION
The Set-IBMSVDNSServer cmdlet updates an existing DNS server.

It maps to the chdnsserver command.

The cmdlet is idempotent:
- Only properties that differ from the current configuration are modified.
- If no changes are required, no operation is performed.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER Name
Specifies the name of the DNS server to update.

.PARAMETER NewName
Specifies a new name for the DNS server.

If both Name and NewName exist, the operation fails.

If the specified Name does not exist but NewName exists, the cmdlet continues updating the NewName DNS server.

.PARAMETER IpAddress
Specifies the IP address for the DNS server.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Set-IBMSVDNSServer -Name dns1 -NewName dns_primary

Renames the DNS server.

.EXAMPLE
PS> Set-IBMSVDNSServer -Name dns1 -IpAddress 1.1.1.1

Updates the IP address.

.EXAMPLE
PS> Set-IBMSVDNSServer -Name dns1 -NewName dns1_new -IpAddress 8.8.8.8

Updates both name and IP address.

.EXAMPLE
PS> Set-IBMSVDNSServer -Name dns1 -WhatIf

Shows what would happen without modifying the DNS server.

.INPUTS
System.String

You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- If the specified DNS server does not exist, a terminating error is thrown.
- If both Name and NewName exist, the operation fails.
- Only modified properties are sent to the backend.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chdnsserver
#>

function Set-IBMSVDNSServer {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$NewName,

        [string]$IpAddress,

        [string]$Cluster
    )

    process {
        # --- Initial check ---
        if ($NewName -and $NewName -eq $Name) { $NewName = $null }
        $data = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsdnsserver" -CmdArgs ("-gui", $Name)
        if ($data.err) {
            throw (Resolve-Error -ErrorInput $data -Category InvalidOperation)
        }

        $newData = if ($NewName) { Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsdnsserver" -CmdArgs ("-gui", $NewName) } else { $null }
        if ($newData.err) {
            throw (Resolve-Error -ErrorInput $newData -Category InvalidOperation)
        }

        if ($data -and $newData) {
            throw (Resolve-Error -ErrorInput "Both '$Name' and '$NewName' exist. Cannot rename, cannot proceed with other updates." -Category ResourceExists)
        }
        if (-not $data) {
            if (-not $newData) {
                throw (Resolve-Error -ErrorInput "DNS Server '$Name' does not exist." -Category ObjectNotFound)
            }
            Write-IBMSVLog -Level WARN -Message "DNS Server '$NewName' already exists. Continuing other updates on '$NewName' DNSServer."
            $data = $newData
            $Name = $NewName
        }

        # --- Update DNS Server ---
        if ($PSCmdlet.ShouldProcess("DNS Server '$Name'", "Modify")) {

            # --- Probe logic ---
            $props = @{}
            if ($NewName -and $NewName -ne $data.name) { $props["name"] = $NewName }
            if ($IpAddress -and $IpAddress -ne $data.IP_address) { $props["ip"] = $IpAddress }
            if ($props.Count -eq 0) { Write-IBMSVLog -Level INFO -Message "No changes required for DNS Server '$Name'."; return }

            # --- Apply changes ---
            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chdnsserver" -CmdOpts $props -CmdArgs $Name
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "DNS Server '$Name' updated successfully."
        }
    }
}
