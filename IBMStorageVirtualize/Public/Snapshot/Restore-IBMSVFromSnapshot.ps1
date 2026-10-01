<#
.SYNOPSIS
Restores from a snapshot on an IBM Storage Virtualize system.

.DESCRIPTION
The Restore-IBMSVFromSnapshot cmdlet restores from volume or volumegroup snapshot.
You can restore an entire volume group or a subset of volumes from the snapshot.

.PARAMETER Name
Specifies the name of the snapshot to be restored.

.PARAMETER VolumeGroup
Specifies the name of the volume group with the snapshot to be restored.

.PARAMETER Volumes
Specifies the names of parent volumes to restore from the snapshot.
Multiple volumes can be specified as an array or colon-separated string.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Restore-IBMSVFromSnapshot -Name snap1 -VolumeGroup vg1
Restores all volumes in the volume group from the snapshot.

.EXAMPLE
PS> Restore-IBMSVFromSnapshot -Name snap2 -VolumeGroup vg1 -Volumes vol1
Restores a single volume from the snapshot.

.EXAMPLE
PS> Restore-IBMSVFromSnapshot -Name snap3 -VolumeGroup vg1 -Volumes vol1,vol2,vol3
Restores multiple volumes from the snapshot.

.EXAMPLE
PS> Restore-IBMSVFromSnapshot -Name snap4
Restores from a snapshot by name.

.EXAMPLE
PS> Restore-IBMSVFromSnapshot -Name snap5 -Volumes vol1:vol2:vol3
Restores multiple volumes using colon-separated format.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/restorefromsnapshot
#>

function Restore-IBMSVFromSnapshot {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$VolumeGroup,

        [string[]]$Volumes,

        [string]$Cluster
    )

    process {
        # --- Normalize Volumes parameter ---
        $validated = @{}
        if ($Volumes) {
            $res = ConvertTo-NormalizedValue -Name 'Volume' -Value ($Volumes -join ":") -Separator ":"
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $validated.Volumes = $res.out
        }

        # --- Fetch snapshot details if needed ---
        $cmdOpts = @{
            filtervalue = if ($VolumeGroup) {
                "name=${Name}:volume_group_name=${VolumeGroup}"
            }
            else {
                "name=$Name"
            }
        }
        $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumegroupsnapshot" -CmdOpts $cmdOpts
        if ($existing -and $existing.PSObject.Properties.Name -contains "err") {
            throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
        }
        if (-not $VolumeGroup) {
            # Filter for independent snapshots (not part of a volume group)
            $existing = $existing | Where-Object { $_.volume_group_name -eq '' } | Select-Object -First 1
        }
        if (-not $existing) {
            if ($VolumeGroup) {
                throw (Resolve-Error -ErrorInput "Snapshot '$Name' does not exist in volume group '$VolumeGroup'." -Category ObjectNotFound)
            }
            else {
                throw (Resolve-Error -ErrorInput "Snapshot '$Name' does not exist." -Category ObjectNotFound)
            }
        }
        # --- Restore from Snapshot ---
        if ($PSCmdlet.ShouldProcess("Snapshot '$Name'", "Restore")) {

            $opts = @{ snapshot = $Name }

            if ($VolumeGroup) {
                $opts['volumegroup'] = $VolumeGroup
            }
            else {
                $opts['parentuid'] = $existing.parent_uid
            }

            if ($validated.ContainsKey('Volumes')) {
                $volumeList = $validated.Volumes

                if ($existing.ha_state -eq "highly_available") {
                    $volArray = $volumeList -split ":"
                    if ($volArray.Count -gt 1) {
                        throw (Resolve-Error -ErrorInput "CMMVC1301E The command failed because highly available snapshot restore is only permitted on the whole snapshot or specifying a single volume" -Category InvalidOperation)
                    }
                }

                $opts['volumes'] = $volumeList
            }

            # Enable resyncrestoredvolumes for local snapshots
            if ($existing.ha_state -eq "local") {
                $opts['resyncrestoredvolumes'] = $true
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "restorefromsnapshot" -CmdOpts $opts
            if ($result -and $result.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }

            if ($validated.ContainsKey('Volumes')) {
                Write-IBMSVLog -Level INFO -Message "Snapshot '$Name' restored successfully for specified volumes."
            }
            else {
                Write-IBMSVLog -Level INFO -Message "Snapshot '$Name' restored successfully."
            }
        }
    }
}
