<#
.SYNOPSIS
Creates a new IP address on an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVIP cmdlet creates an IP address on an IBM Storage Virtualize system.

.PARAMETER IPAddress
Specifies the IP address to create (IPv4 or IPv6).

.PARAMETER SubnetPrefix
Specifies the prefix of the subnet mask.
Required when creating an IP address.

.PARAMETER Node
Specifies the name of the node.
Mutually exclusive with -Portset when creating management IPs.

.PARAMETER Port
Specifies a port ranging from 1-16 to which the IP shall be assigned.
Valid only when -Node is specified.

.PARAMETER Portset
Specifies the name of the portset object.
Mutually exclusive with -Node and -Port for data IPs.

.PARAMETER Gateway
Specifies the gateway address.

.PARAMETER Vlan
Specifies a VLAN ID ranging from 1-4096.

.PARAMETER ShareIP
Specifies that the IP is shared between multiple portsets.
Valid only when -Portset is specified.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> New-IBMSVIP -IPAddress "192.168.1.100" -SubnetPrefix 24 -Node node1 -Port 1 -Gateway "192.168.1.1"
Creates an IP address on a specific node and port (default portset).

.EXAMPLE
PS> New-IBMSVIP -IPAddress "192.168.1.101" -SubnetPrefix 24 -Portset portset0 -Gateway "192.168.1.1" -Vlan 100
Creates an IP address on a portset with VLAN.

.EXAMPLE
PS> New-IBMSVIP -IPAddress "192.168.1.102" -SubnetPrefix 24 -Portset portset0 -ShareIP
Creates a shared IP address on a portset.

.EXAMPLE
PS> New-IBMSVIP -IPAddress "2001:db8::1" -SubnetPrefix 64 -Portset portset0 -Gateway "2001:db8::ffff"
Creates an IPv6 address on a portset.

.EXAMPLE
PS> New-IBMSVIP -IPAddress "192.168.1.103" -SubnetPrefix 24 -Node node1 -Portset mgmt_portset -Gateway "192.168.1.1"
Creates an IP address for a management portset.

.INPUTS
System.String
You can pipe objects with an IPAddress property to this cmdlet.

.OUTPUTS
System.Object
Returns the created IP address, or the existing IP address if it already exists.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkip
#>

function New-IBMSVIP {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('IP')]
        [string]$IPAddress,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Prefix')]
        [int]$SubnetPrefix,

        [string]$Node,

        [int]$Port,

        [string]$Portset,

        [Alias('GW')]
        [string]$Gateway,

        [int]$Vlan,

        [switch]$ShareIP,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        if ($Port -and -not $Node) {
            throw (Resolve-Error -ErrorInput "Parameter -Port requires -Node to be specified." -Category InvalidArgument)
        }

        if ($ShareIP -and -not $Portset) {
            throw (Resolve-Error -ErrorInput "Parameter -ShareIP requires -Portset to be specified." -Category InvalidArgument)
        }

        if (-not (($Node -and $Port) -or $Portset)) {
            throw (Resolve-Error -ErrorInput "Specify -Portset for creating management IP, or specify atleast one of -Node or -Port." -Category InvalidArgument)
        }

        # --- Create IP ---
        if ($PSCmdlet.ShouldProcess("IP Address '$IPAddress'", "Create")) {

            # --- Existence check ---
            $allIPs = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsip"

            if ($allIPs -and $allIPs.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $allIPs -Category InvalidOperation)
            }
            $existingIP = $null

            $matchingIPs = $allIPs | Where-Object { $_.IP_address -eq $IPAddress }

            if ($matchingIPs) {
                if ($Portset) {
                    $existingIP = $matchingIPs | Where-Object { $_.portset_name -eq $Portset } | Select-Object -First 1

                    if (-not $existingIP -and -not $ShareIP) {
                        # IP exists but on different portset and ShareIP not specified
                        throw (Resolve-Error -ErrorInput "IP address '$IPAddress' already exists on a different portset. To create a shared data IP, use -ShareIP parameter." -Category InvalidOperation)
                    }
                }
                else {
                    # No portset specified, check if there's only one match
                    if (($matchingIPs | Measure-Object).Count -gt 1) {
                        throw (Resolve-Error -ErrorInput "Multiple IP addresses found with '$IPAddress'. Please specify -Portset and -ShareIP to create a shared IP." -Category InvalidOperation)
                    }
                    $existingIP = $matchingIPs | Select-Object -First 1
                }
            }

            if ($existingIP) {
                Write-IBMSVLog -Level INFO -Message "IP address '$IPAddress' already exists. Returning existing object."
                return $existingIP
            }

            $opts = @{
                ip     = $IPAddress
                prefix = $SubnetPrefix
            }

            if ($Gateway) {
                $opts['gw'] = $Gateway
            }

            foreach ($field in @('Node', 'Port', 'Portset', 'Vlan', 'ShareIP')) {
                if ($PSBoundParameters.ContainsKey($field)) {
                    $value = $PSBoundParameters[$field]
                    if ($null -ne $value -and ($value -isnot [string] -or $value -ne '')) {
                        if ($value -is [System.Management.Automation.SwitchParameter]) {
                            $opts[$field.ToLower()] = $value.IsPresent
                        }
                        else {
                            $opts[$field.ToLower()] = $value
                        }
                    }
                }
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "mkip" -CmdOpts $opts
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "IP address [$($result.id)] '$IPAddress' created successfully."

            $allIPs = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsip"
            if ($allIPs -and $allIPs.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $allIPs -Category InvalidOperation)
            }

            $matchingIPs = $allIPs | Where-Object { $_.IP_address -eq $IPAddress }
            if ($Portset) {
                $current = $matchingIPs | Where-Object { $_.portset_name -eq $Portset } | Select-Object -First 1
            }
            else {
                $current = $matchingIPs | Select-Object -First 1
            }

            return $current
        }
    }
}
