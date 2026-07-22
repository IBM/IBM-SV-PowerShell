<#
.SYNOPSIS
Removes an existing IP address from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVIP cmdlet deletes an IP address from the IBM Storage Virtualize system.

.PARAMETER IPAddress
Specifies the IP address to remove.

.PARAMETER Portset
Specifies the portset name to identify the IP address.
Required when multiple IP addresses with the same address exist on different portsets.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Remove-IBMSVIP -IPAddress "192.168.1.100"
Removes the IP address.

.EXAMPLE
PS> Remove-IBMSVIP -IPAddress "192.168.1.100" -Portset portset0
Removes the IP address from a specific portset.

.EXAMPLE
PS> Remove-IBMSVIP -IPAddress "192.168.1.100" -WhatIf
Shows what would happen if the IP address were removed.

.INPUTS
System.String
You can pipe objects with an IPAddress property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- This is a destructive operation and cannot be undone.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/rmip
#>

function Remove-IBMSVIP {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('IP_address')]
        [string]$IPAddress,

        [string]$Portset,

        [string]$Cluster
    )

    process {
        # --- Remove IP ---
        if ($PSCmdlet.ShouldProcess("IP Address '$IPAddress'", "Remove")) {

            # --- Existence check ---
            $allIPs = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsip"
            if ($allIPs -and $allIPs.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $allIPs -Category InvalidOperation)
            }

            if ($allIPs) {
                $existing = $null
                $matchingIPs = $allIPs | Where-Object { $_.IP_address -eq $IPAddress }

                Write-IBMSVLog -Level DEBUG -Message "Found $($matchingIPs.Count) matching IPs for address $IPAddress"

                if ($matchingIPs) {
                    if ($Portset) {
                        $existing = $matchingIPs | Where-Object { $_.portset_name -eq $Portset } | Select-Object -First 1

                        if (-not $existing) {
                            Write-IBMSVLog -Level INFO -Message "IP address '$IPAddress' with portset '$Portset' does not exist."
                            return
                        }
                    }
                    else {
                        if (($matchingIPs | Measure-Object).Count -gt 1) {
                            throw (Resolve-Error -ErrorInput "Multiple IP addresses found with '$IPAddress'. Please specify -Portset to identify the target." -Category InvalidOperation)
                        }
                        $existing = $matchingIPs | Select-Object -First 1
                    }
                }

                if (-not $existing) {
                    Write-IBMSVLog -Level INFO -Message "IP address '$IPAddress' does not exist."
                    return
                }

                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmip" -CmdArgs $existing.id
                if ($result -and $result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }

                Write-IBMSVLog -Level INFO -Message "IP address '$IPAddress' removed successfully."
            }
        }
    }
}
