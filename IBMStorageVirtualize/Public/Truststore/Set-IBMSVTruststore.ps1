<#
.SYNOPSIS
Modifies an existing truststore on IBM Storage Virtualize systems.

.DESCRIPTION
The Set-IBMSVTruststore cmdlet modifies properties of an existing truststore on IBM Storage Virtualize systems.

.PARAMETER Name
Specifies the current name of the truststore to modify on the local cluster.

.PARAMETER RemoteTruststoreName
Specifies the name of the truststore if it is not the same as Name on the remote cluster.
If not provided, defaults to the same name as Name.
Only applicable when -RemoteCluster is specified.

.PARAMETER Vasa
Enables or disables the truststore for VASA provider.
Valid values: on, off

.PARAMETER RestAPI
Enables or disables the truststore for REST API usage.
Valid values: on, off

.PARAMETER IpSec
Enables or disables the truststore for IPSec usage.
Valid values: on, off

.PARAMETER Email
Enables or disables the truststore for email servers.
Valid values: on, off

.PARAMETER Export
Exports the truststore certificate.
This parameter is mutually exclusive with all other modification parameters.

.PARAMETER SNMP
Enables or disables the truststore for SNMP servers.
Valid values: on, off

.PARAMETER Syslog
Specifies the certificates to be bundled and provided to rsyslog client for making TLS connections.
Valid values: on, off

.PARAMETER Cluster
Specifies the local IBM Storage Virtualize cluster on which the truststore is created.
If not provided, the primary cluster is used.

.PARAMETER RemoteCluster
Specifies the remote cluster on which to modify the truststore.
When specified, truststores are modified on both local and remote clusters.

.EXAMPLE
PS> Set-IBMSVTruststore -Name "pwsh_truststore" -RestAPI "on"
Enables the truststore for REST API usage.

.EXAMPLE
PS> Set-IBMSVTruststore -Name "pwsh_truststore" -Vasa "on" -Email "on"
Enables the truststore for VASA and email usage.

.EXAMPLE
PS> Set-IBMSVTruststore -Name "pwsh_truststore" -Export
Exports the truststore certificate.

.EXAMPLE
PS> Set-IBMSVTruststore -Name "trust_local" -RemoteTruststoreName "trust_remote" -RemoteCluster "10.10.10.20" -RestAPI "on"
Enables REST API usage for truststores on both local and remote clusters.

.EXAMPLE
PS> Set-IBMSVTruststore -Name "pwsh_truststore" -RestAPI "off" -SNMP "on" -Syslog "on"
Disables REST API usage and enables SNMP and Syslog usage for the truststore.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chtruststore
#>

function Set-IBMSVTruststore {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$RemoteTruststoreName,

        [ValidateSet("on", "off")]
        [string]$Vasa,

        [ValidateSet("on", "off")]
        [string]$RestAPI,

        [ValidateSet("on", "off")]
        [string]$IpSec,

        [ValidateSet("on", "off")]
        [string]$Email,

        [switch]$Export,

        [ValidateSet("on", "off")]
        [string]$SNMP,

        [ValidateSet("on", "off")]
        [string]$Syslog,

        [string]$Cluster,

        [string]$RemoteCluster
    )

    process {
        if (-not $Cluster) {
            $Cluster = $script:primarysession
        }

        # --- Parameter-level validation ---
        if ($Export -and ($Vasa -or $RestAPI -or $IpSec -or $Email -or $SNMP -or $Syslog)) {
            throw (Resolve-Error -ErrorInput "-Export is mutually exclusive with other parameters." -Category InvalidArgument)
        }

        $clustersToUpdate = @()
        if (-not $RemoteCluster) {
            if ($RemoteTruststoreName) {
                throw (Resolve-Error -ErrorInput "-RemoteTruststoreName is not applicable when -RemoteCluster is not specified." -Category InvalidArgument)
            }
            $primaryData = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lstruststore" -CmdArgs $Name
            if ($primaryData -and $primaryData.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $primaryData -Category InvalidOperation)
            }
            if (-not $primaryData) {
                throw (Resolve-Error -ErrorInput "Truststore '$Name' does not exist on cluster '$Cluster'." -Category ObjectNotFound)
            }

            $clustersToUpdate += [pscustomobject]@{
                Cluster     = $Cluster
                Data        = $primaryData
                Description = "cluster '$Cluster'"
            }
        }
        else {
            $primaryData = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lstruststore" -CmdArgs $Name
            if ($primaryData -and $primaryData.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $primaryData -Category InvalidOperation)
            }
            if (-not $primaryData) {
                throw (Resolve-Error -ErrorInput "Truststore '$Name' does not exist on primary cluster '$Cluster'." -Category ObjectNotFound)
            }

            if (-not $RemoteTruststoreName) {
                $RemoteTruststoreName = $Name
            }
            $secondaryData = Invoke-IBMSVRestRequest -Cluster $RemoteCluster -Cmd "lstruststore" -CmdArgs $RemoteTruststoreName
            if ($secondaryData -and $secondaryData.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $secondaryData -Category InvalidOperation)
            }
            if (-not $secondaryData) {
                throw (Resolve-Error -ErrorInput "Truststore '$RemoteTruststoreName' does not exist on secondary cluster '$RemoteCluster'." -Category ObjectNotFound)
            }

            $clustersToUpdate += [pscustomobject]@{
                Cluster     = $Cluster
                Data        = $primaryData
                Description = "primary cluster '$Cluster'"
            }
            $clustersToUpdate += [pscustomobject]@{
                Cluster     = $RemoteCluster
                Data        = $secondaryData
                Description = "secondary cluster '$RemoteCluster'"
            }
        }

        # --- Update Truststore ---
        foreach ($target in $clustersToUpdate) {
            if ($PSCmdlet.ShouldProcess("Truststore '$($target.Data.name)'", "Modify")) {
                if ($Export) {
                    $result = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "chtruststore" -CmdOpts @{ export = $true } -CmdArgs $target.Data.name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                    Write-IBMSVLog -Level INFO -Message "Truststore '$($target.Data.name)' exported successfully from $($target.Description)."
                    continue
                }

                $props = @{}
                $data = $target.Data

                # --- Probe logic ---
                $paramsMapping = @(
                    @{ Key = 'Vasa'; Existing = $data.vasa }
                    @{ Key = 'RestAPI'; Existing = $data.restapi }
                    @{ Key = 'IpSec'; Existing = $data.ipsec }
                    @{ Key = 'Email'; Existing = $data.email }
                    @{ Key = 'SNMP'; Existing = $data.snmp }
                    @{ Key = 'Syslog'; Existing = $data.syslog }
                )
                foreach ($item in $paramsMapping) {
                    if ($PSBoundParameters.ContainsKey($item.Key)) {
                        $inputValue = Get-Variable -Name $item.Key -ValueOnly
                        $paramName = if ($item.paramName) { $item.paramName } else { $item.Key.ToLower() }
                        if ($inputValue -is [System.Management.Automation.SwitchParameter]) {
                            $inputValue = $true
                        }

                        if ($inputValue -ne $item.Existing) {
                            $props[$paramName] = $inputValue
                        }
                    }
                }

                if ($props.Count -eq 0) {
                    Write-IBMSVLog -Level INFO -Message "No changes required for Truststore '$($target.Data.name)' on $($target.Description)."
                }
                else {
                    # --- Apply changes ---
                    $result = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "chtruststore" -CmdOpts $props -CmdArgs $target.Data.name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                    Write-IBMSVLog -Level INFO -Message "Truststore '$($target.Data.name)' updated successfully on $($target.Description)."
                }
            }
        }
    }
}
