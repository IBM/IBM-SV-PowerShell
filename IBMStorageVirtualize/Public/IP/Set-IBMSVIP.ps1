<#
.SYNOPSIS
Modifies an existing IP address on an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVIP cmdlet updates properties of an existing IP address.

.PARAMETER IPAddress
Specifies the current IP address to modify.

.PARAMETER NewIPAddress
Specifies a new IP address to replace the current one.
If both IPAddress and NewIPAddress exist, the operation fails.
If the specified IPAddress does not exist but NewIPAddress exists, the cmdlet continues updating the NewIPAddress.

.PARAMETER SubnetPrefix
Specifies the new prefix of the subnet mask.

.PARAMETER Gateway
Specifies the new gateway address.
Mutually exclusive with -ResetGateway.

.PARAMETER ResetGateway
Removes the gateway address.
Mutually exclusive with -Gateway.

.PARAMETER Vlan
Specifies a new VLAN ID ranging from 1-4096.
Mutually exclusive with -ResetVlan.

.PARAMETER ResetVlan
Removes the VLAN assignment.
Mutually exclusive with -Vlan.

.PARAMETER Portset
Specifies the portset name to identify the IP address.
Required when multiple IP addresses with the same address exist on different portsets.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Set-IBMSVIP -IPAddress "192.168.1.100" -NewIPAddress "192.168.1.101" -Portset portset_mgmt
Changes the IP address.

.EXAMPLE
PS> Set-IBMSVIP -IPAddress "192.168.1.100" -SubnetPrefix 24 -Gateway "192.168.1.1"
Updates subnet prefix and gateway.

.EXAMPLE
PS> Set-IBMSVIP -IPAddress "192.168.1.100" -Vlan 200 -Portset portset0
Updates the VLAN ID.

.EXAMPLE
PS> Set-IBMSVIP -IPAddress "192.168.1.100" -ResetGateway -ResetVlan
Removes gateway and VLAN assignments.

.EXAMPLE
PS> Set-IBMSVIP -IPAddress "192.168.1.100" -SubnetPrefix 20 -Portset portset0
Updates only the subnet prefix.

.EXAMPLE
PS> Set-IBMSVIP -IPAddress "192.168.1.100" -NewIPAddress "192.168.1.101" -SubnetPrefix 24 -Portset mgmt_portset
Updates the IP Address.

.INPUTS
System.String
You can pipe objects with an IPAddress property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Node and Port cannot be changed after IP creation.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chip
#>

function Set-IBMSVIP {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('IP_address')]
        [string]$IPAddress,

        [string]$NewIPAddress,

        [Alias('Prefix')]
        [int]$SubnetPrefix,

        [Alias('GW')]
        [string]$Gateway,

        [switch]$ResetGateway,

        [int]$Vlan,

        [switch]$ResetVlan,

        [string]$Portset,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        if ($Gateway -and $ResetGateway) {
            throw (Resolve-Error -ErrorInput "Parameters -Gateway and -ResetGateway are mutually exclusive." -Category InvalidArgument)
        }

        if ($PSBoundParameters.ContainsKey("Vlan") -and $ResetVlan) {
            throw (Resolve-Error -ErrorInput "Parameters -Vlan and -ResetVlan are mutually exclusive." -Category InvalidArgument)
        }

        # --- Initial check ---
        if ($NewIPAddress -and $NewIPAddress -eq $IPAddress) { $NewIPAddress = $null }

        $allIPs = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsip"
        if ($allIPs -and $allIPs.PSObject.Properties.Name -contains "err") {
            throw (Resolve-Error -ErrorInput $allIPs -Category InvalidOperation)
        }

        $data = $null
        if ($allIPs) {
            $matchingIPs = $allIPs | Where-Object { $_.IP_address -eq $IPAddress }

            if ($matchingIPs) {
                if ($Portset) {
                    $data = $matchingIPs | Where-Object { $_.portset_name -eq $Portset } | Select-Object -First 1
                }
                else {
                    if (($matchingIPs | Measure-Object).Count -gt 1) {
                        throw (Resolve-Error -ErrorInput "Multiple IP addresses found with '$IPAddress'. Please specify -Portset to identify the target." -Category InvalidOperation)
                    }
                    $data = $matchingIPs | Select-Object -First 1
                }
            }
        }

        $newData = $null
        if ($NewIPAddress) {
            $matchingNewIPs = $allIPs | Where-Object { $_.IP_address -eq $NewIPAddress }

            if ($matchingNewIPs) {
                if ($Portset) {
                    $newData = $matchingNewIPs | Where-Object { $_.portset_name -eq $Portset } | Select-Object -First 1
                }
                else {
                    if (($matchingNewIPs | Measure-Object).Count -gt 1) {
                        throw (Resolve-Error -ErrorInput "Multiple IP addresses found with '$NewIPAddress'. Please specify -Portset to identify the target." -Category InvalidOperation)
                    }
                    $newData = $matchingNewIPs | Select-Object -First 1
                }
            }
        }

        if ($data -and $newData) {
            throw (Resolve-Error -ErrorInput "Both IP '$IPAddress' and '$NewIPAddress' exist. Cannot update IP address." -Category ResourceExists)
        }

        if (-not $data) {
            if (-not $newData) {
                $errorMsg = if ($Portset) {
                    "IP address '$IPAddress' with portset '$Portset' does not exist."
                }
                else {
                    "IP address '$IPAddress' does not exist."
                }
                throw (Resolve-Error -ErrorInput $errorMsg -Category ObjectNotFound)
            }
            Write-IBMSVLog -Level WARN -Message "IP address '$NewIPAddress' already exists. Continuing other updates on '$NewIPAddress'."
            $data = $newData
            $IPAddress = $NewIPAddress
            $NewIPAddress = $null
        }

        # --- Update IP ---
        if ($PSCmdlet.ShouldProcess("IP Address '$IPAddress'", "Modify")) {

            # --- Probe logic ---
            $props = @{}

            $paramsMapping = @(
                @{ Key = 'NewIPAddress'; Existing = $data.IP_address; ParamName = 'ip' }
                @{ Key = 'SubnetPrefix'; Existing = [int]$data.prefix; ParamName = 'prefix' }
                @{ Key = 'Gateway'; Existing = $data.gateway; ParamName = 'gw' }
                @{ Key = 'Vlan'; Existing = if ($data.vlan) { [int]$data.vlan } else { 0 }; ParamName = 'vlan' }
                @{ Key = 'ResetGateway'; Existing = -not [bool]$data.gateway; ParamName = 'gw' }
                @{ Key = 'ResetVlan'; Existing = -not [bool]$data.vlan; ParamName = 'vlan' }
            )

            foreach ($item in $paramsMapping) {
                if ($PSBoundParameters.ContainsKey($item.Key)) {
                    $inputValue = Get-Variable -Name $item.Key -ValueOnly
                    if ($inputValue -and $inputValue -ne $item.Existing) {
                        if ($inputValue -is [System.Management.Automation.SwitchParameter]) { $inputValue = "" }
                        $paramName = if ($item.paramName) { $item.paramName } else { $item.Key.ToLower() }
                        $props[$paramName] = $inputValue
                    }
                }
            }

            if ($props.Count -eq 0) {
                Write-IBMSVLog -Level INFO -Message "No changes required for IP address '$IPAddress'."
                return
            }

            # --- Apply changes ---
            $opts = @{
                ip     = if ($props.ContainsKey('ip')) { $props['ip'] } else { $data.IP_address }
                prefix = if ($props.ContainsKey('prefix')) { $props['prefix'] } else { $data.prefix }
            }

            # Add gateway if specified or if it exists and not being reset
            if ($props.ContainsKey('gw')) {
                if ($props['gw'] -ne "") {
                    $opts['gw'] = $props['gw']
                }
                # If empty string, we're resetting - don't include gw parameter
            }
            elseif (-not $ResetGateway -and $data.gateway) {
                $opts['gw'] = $data.gateway
            }

            # Add vlan if specified or if it exists and not being reset
            if ($props.ContainsKey('vlan')) {
                if ($props['vlan'] -ne "") {
                    $opts['vlan'] = $props['vlan']
                }
                # If empty string, we're resetting - don't include vlan parameter
            }
            elseif (-not $ResetVlan -and $data.vlan) {
                $opts['vlan'] = $data.vlan
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chip" -CmdOpts $opts -CmdArgs $data.id
            if ($result -and $result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }

            if ($props.ContainsKey('ip')) {
                if ($props.Count -gt 2) {
                    Write-IBMSVLog -Level INFO -Message "IP address '$IPAddress' changed to '$NewIPAddress' and updated successfully."
                }
                else {
                    Write-IBMSVLog -Level INFO -Message "IP address '$IPAddress' changed to '$NewIPAddress'."
                }
            }
            else {
                Write-IBMSVLog -Level INFO -Message "IP address '$IPAddress' updated successfully."
            }
        }
    }
}
