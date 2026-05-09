<#
.SYNOPSIS
Removes an existing volume-to-host or host cluster mapping in an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVVolToHostMap cmdlet deletes a mapping between a volume and a host or host cluster.

It maps to rmvdiskhostmap, rmvolumehostclustermap, and related commands based on the target.

The cmdlet is idempotent:
- If the specified mapping does not exist, no action is performed.

Supports -WhatIf and -Confirm for safe execution.
Due to the destructive nature, confirmation is required by default.

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

If not provided, the primary session is used.

.EXAMPLE
PS> Remove-IBMSVVolToHostMap -Volume volume0 -HostName host4test

Removes the mapping to a host.

.EXAMPLE
PS> Remove-IBMSVVolToHostMap -Volume volume0 -HostCluster clusterA

Removes the mapping to a host cluster.

.EXAMPLE
PS> Remove-IBMSVVolToHostMap -Volume volume1 -HostName hostB -WhatIf

Shows what would happen without removing the mapping.

.INPUTS
System.String

You can pipe objects with Volume, HostName, or HostCluster properties to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- This is a destructive operation and cannot be undone.
- If the mapping does not exist, the operation completes silently.
- Fully supports -WhatIf and -Confirm.

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
