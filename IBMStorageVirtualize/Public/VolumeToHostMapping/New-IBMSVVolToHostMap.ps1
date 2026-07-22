<#
.SYNOPSIS
Creates a new volume-to-host or host cluster mapping on an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVVolToHostMap cmdlet creates a volume-to-host mapping on an IBM Storage Virtualize system.

.PARAMETER Volume
Specifies the name or UID of the volume to map.

.PARAMETER HostName
Specifies the host name for the mapping.
Mutually exclusive with -HostCluster.

.PARAMETER HostCluster
Specifies the host cluster name for the mapping.
Mutually exclusive with -HostName.

.PARAMETER SCSI
Specifies the SCSI logical unit number (LUN) ID.
Mutually exclusive with -AllowMismatchedScsiIds.

.PARAMETER AllowMismatchedScsiIds
Specifies that non-identical SCSI LUN IDs are allowed across I/O groups.
Mutually exclusive with -SCSI.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> New-IBMSVVolToHostMap -Volume volume0 -HostName host4test -SCSI 1
Creates a mapping to a host.

.EXAMPLE
PS> New-IBMSVVolToHostMap -Volume volume0 -HostCluster cluster01
Creates a mapping to a host cluster.

.EXAMPLE
PS> New-IBMSVVolToHostMap -Volume volume1 -HostName hostA -AllowMismatchedScsiIds
Creates a mapping allowing mismatched SCSI IDs.

.INPUTS
System.String
You can pipe objects with Volume, HostName, or HostCluster properties to this cmdlet.

.OUTPUTS
System.Object
Returns the created mapping object, or the existing mapping object if it already exists.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkvdiskhostmap

.LINK
https://www.ibm.com/docs/en/search/mkvolumehostclustermap
#>

function New-IBMSVVolToHostMap {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Volume,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$HostName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$HostCluster,

        [int]$SCSI,

        [switch]$AllowMismatchedScsiIds,

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
        if ($SCSI -and $AllowMismatchedScsiIds) {
            throw (Resolve-Error -ErrorInput "Parameters -SCSI and -AllowMismatchedScsiIds are mutually exclusive." -Category InvalidArgument)
        }

        # --- Create VDiskHost Mapping ---
        if ($PSCmdlet.ShouldProcess("Mapping '$Volume'", "Create")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvdiskhostmap" -CmdArgs $Volume
            if ($existing -and $existing.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
            }
            if ($existing) {
                if ($HostName -and ($existing.host_name -contains $HostName)) {
                    Write-IBMSVLog -Level INFO -Message "Volume '$Volume' already mapped to host '$HostName'."
                    return $existing | Where-Object { $_.host_name -eq $HostName }
                }

                if ($HostCluster -and ($existing.host_cluster_name -contains $HostCluster)) {
                    Write-IBMSVLog -Level INFO -Message "Volume '$Volume' already mapped to host cluster '$HostCluster'."
                    return $existing | Where-Object { $_.host_cluster_name -eq $HostCluster }
                }
            }

            $opts = @{ force = $true }
            $cmd = ""
            if ($PSBoundParameters.ContainsKey('HostName')) {
                $cmd = 'mkvdiskhostmap'
                $opts['host'] = $HostName
                $msg = "Volume '$Volume' mapped to Host '$HostName'."
            }
            elseif ($PSBoundParameters.ContainsKey('HostCluster')) {
                $cmd = 'mkvolumehostclustermap'
                $opts['hostcluster'] = $HostCluster
                $msg = "Volume '$Volume' mapped to Hostcluster '$HostCluster'."
            }

            if ($PSBoundParameters.ContainsKey('SCSI')) {
                $opts['scsi'] = $SCSI
            }
            elseif ($PSBoundParameters.ContainsKey('AllowMismatchedScsiIds')) {
                $opts['allowmismatchedscsiids'] = $true
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd $cmd -CmdOpts $opts -CmdArgs $Volume
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message $msg

            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvdiskhostmap" -CmdArgs $Volume
            if ($current -and $current.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            if ($current) {
                if ($HostName -and ($current.host_name -contains $HostName)) {
                    return $current | Where-Object { $_.host_name -eq $HostName }
                }

                if ($HostCluster -and ($current.host_cluster_name -contains $HostCluster)) {
                    return $current | Where-Object { $_.host_cluster_name -eq $HostCluster }
                }
            }
        }
    }
}
