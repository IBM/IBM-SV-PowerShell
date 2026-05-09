<#
.SYNOPSIS
Creates a new DNS server on an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVDNSServer cmdlet creates a DNS server entry.

It maps to the mkdnsserver command.

The cmdlet is idempotent:
- If a DNS server with the specified IP address or name already exists, the existing entry is returned.
- If the IP or name exists with conflicting values, the operation fails.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER IpAddress
Specifies the IP address of the DNS server.

.PARAMETER Name
Specifies the name of the DNS server.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> New-IBMSVDNSServer -IpAddress 8.8.8.8

Creates a DNS server entry.

.EXAMPLE
PS> New-IBMSVDNSServer -IpAddress 8.8.4.4 -Name dns-secondary

Creates a DNS server with a name.

.EXAMPLE
PS> New-IBMSVDNSServer -IpAddress 8.8.8.8 -WhatIf

Shows what would happen without creating the DNS server.

.INPUTS
System.String

You can pipe objects with an IpAddress property to this cmdlet.

.OUTPUTS
System.Object

Returns the created DNS server object.

If the DNS server already exists, the existing object is returned.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkdnsserver
#>

function New-IBMSVDNSServer {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$IpAddress,

        [string]$Name,

        [string]$Cluster
    )

    process {
        # --- Create DNS Server ---
        if ($PSCmdlet.ShouldProcess("DNS server", "Create with IP $($IpAddress)")) {

            # --- Existence check ---
            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsdnsserver"
            if ($current -and $current.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            if ($current) {
                if ($current.IP_address -contains $IpAddress) {
                    $found = $current | Where-Object { $_.IP_address -eq $IpAddress }
                    if ($Name -and ($found.name -ne $Name)) {
                        throw (Resolve-Error -ErrorInput "CMMVC8720E DNS server with the IP '$IpAddress' already exists with a different name." -Category ResourceExists)
                    }

                    Write-IBMSVLog -Level INFO -Message "DNS server '$IpAddress' already exists. Returning existing object."
                    return $found
                }

                if ($Name -and ($current.name -contains $Name)) {
                    $found = $current | Where-Object { $_.name -eq $Name }
                    if ($found.IP_address -ne $IpAddress) {
                        throw (Resolve-Error -ErrorInput "CMMVC6035E DNS server with the name '$Name' already exists with a different IP address." -Category ResourceExists)
                    }

                    Write-IBMSVLog -Level INFO -Message "DNS server '$Name' already exists. Returning existing object."
                    return $found
                }
            }


            $opts = @{ ip = $IpAddress }
            if ($Name) { $opts["name"] = $Name }
            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "mkdnsserver" -CmdOpts $opts
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "DNS server '$($Name)' with IP '$($IpAddress)' created successfully."

            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsdnsserver"
            if ($current -and $current.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            return $current | Where-Object { $_.IP_address -eq $IpAddress }
        }
    }
}
