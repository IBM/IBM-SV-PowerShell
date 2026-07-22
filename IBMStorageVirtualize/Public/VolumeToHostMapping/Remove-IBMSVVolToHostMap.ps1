<#
.SYNOPSIS
Removes an existing volume-to-host mapping from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVVolToHostMap cmdlet deletes a volume-to-host mapping from the system.

.PARAMETER Volume
Specifies the name or UID of the volume to unmap.

.PARAMETER HostName
Specifies the host name for the mapping.
Mutually exclusive with -HostCluster.

.PARAMETER HostCluster
Specifies the host cluster name for the mapping.
Mutually exclusive with -HostName.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Remove-IBMSVVolToHostMap -Volume volume0 -HostName host4test
Removes the mapping to a host.

.EXAMPLE
PS> Remove-IBMSVVolToHostMap -Volume volume0 -HostCluster clusterA
Removes the mapping to a host cluster.

.EXAMPLE
PS> Remove-IBMSVVolToHostMap -Volume volume1 -HostName hostB -WhatIf
Shows what would happen if the mapping were removed.

.INPUTS
System.String
You can pipe objects with Volume, HostName, or HostCluster properties to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- This is a destructive operation and cannot be undone.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/rmvdiskhostmap

.LINK
https://www.ibm.com/docs/en/search/rmvolumehostclustermap
#>

function Remove-IBMSVVolToHostMap {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Volume,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$HostName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$HostCluster,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        if ($HostName -and $HostCluster) {
            throw (Resolve-Error -ErrorInput "Parameters -HostName and -HostCluster are mutually exclusive." -Category InvalidArgument)
        }
        if (-not $HostName -and -not $HostCluster) {
            throw (Resolve-Error -ErrorInput "One of -HostName or -HostCluster parameter is required." -Category InvalidArgument)
        }

        # --- Remove Mapping ---
        if ($PSCmdlet.ShouldProcess("VolumeHostMap '$Volume'", "Remove")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvdiskhostmap" -CmdArgs $Volume
            if ($existing -and $existing.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
            }
            if (-not $existing) {
                Write-IBMSVLog -Level INFO -Message "VDiskHostMap '$Volume' does not exist."
                return
            }

            if ($HostName) {
                $match = $existing | Where-Object { $_.host_name -eq $HostName }
                $obj = $HostName
            }
            elseif ($HostCluster) {
                $match = $existing | Where-Object { $_.host_cluster_name -eq $HostCluster }
                $obj = $HostCluster
            }
            if (-not $match) {
                Write-IBMSVLog -Level INFO -Message "No mapping found for '$Volume' -> '$obj'. Nothing to remove."
                return
            }

            $cmd = ""
            $opts = @{}
            if ($PSBoundParameters.ContainsKey('HostName')) {
                $cmd = 'rmvdiskhostmap'
                $opts['host'] = $HostName
                $msg = "Volume '$Volume' unmapped from Host '$HostName'."
            }
            elseif ($PSBoundParameters.ContainsKey('HostCluster')) {
                $cmd = 'rmvolumehostclustermap'
                $opts['hostcluster'] = $HostCluster
                $msg = "Volume '$Volume' unmapped from Hostcluster '$HostCluster'."
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd $cmd -CmdOpts $opts -CmdArgs $Volume
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message $msg
        }
    }
}
