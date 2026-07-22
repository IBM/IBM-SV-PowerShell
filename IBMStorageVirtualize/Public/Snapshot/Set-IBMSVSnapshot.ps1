<#
.SYNOPSIS
Modifies an existing snapshot on an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVSnapshot cmdlet updates properties of an existing snapshot.

.PARAMETER Name
Specifies the name of the snapshot to modify.

.PARAMETER NewName
Specifies a new name for the snapshot.
If both Name and NewName exist, the operation fails.
If the specified Name does not exist but NewName exists, the cmdlet continues updating the NewName snapshot.

.PARAMETER OwnershipGroup
Specifies the ownership group for the snapshot.

.PARAMETER VolumeGroup
Specifies the name of the volumegroup associated with the snapshot.
This parameter is used for volumegroup-based snapshots.
Mutually exclusive with ParentUID.

.PARAMETER ParentUID
Specifies the parent UID for volume-based snapshots.
This parameter is used for volume-based snapshots (independent volumes).
Mutually exclusive with VolumeGroup.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Set-IBMSVSnapshot -Name snap1 -NewName snap1_renamed -VolumeGroup vg1
Renames a volumegroup-based snapshot.

.EXAMPLE
PS> Set-IBMSVSnapshot -Name snap2 -OwnershipGroup group1
Updates ownership group for a volume-based snapshot.

.EXAMPLE
PS> Set-IBMSVSnapshot -Name snap3 -NewName snap3_new -OwnershipGroup group2
Renames and updates ownership group.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Multiple parameter update is non-atomic.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chsnapshot
#>

function Get-SnapshotInfo {
    param(
        [string]$Cluster,
        [string]$SnapshotName,
        [string]$VolumeGroup
    )

    $cmdOpts = @{
        filtervalue = if ($VolumeGroup) {
            "name=${SnapshotName}:volume_group_name=${VolumeGroup}"
        }
        else {
            "name=$SnapshotName"
        }
    }

    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumegroupsnapshot" -CmdOpts $cmdOpts
    if ($result -and $result.PSObject.Properties.Name -contains 'err') {
        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
    }

    if (-not $VolumeGroup) {
        $result = $result | Where-Object { $_.volume_group_name -eq '' } | Select-Object -First 1
    }

    return $result
}

function Set-IBMSVSnapshot {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$NewName,

        [string]$OwnershipGroup,

        [string]$VolumeGroup,

        [string]$Cluster
    )

    process {
        # --- Initial check ---
        if ($NewName -and $NewName -eq $Name) { $NewName = $null }

        $parentuid = $null
        $data = Get-SnapshotInfo -Cluster $Cluster -SnapshotName $Name -VolumeGroup $VolumeGroup
        if ($data) {
            $parentuid = $data.parent_uid
        }

        if ($NewName) {
            $newData = Get-SnapshotInfo -Cluster $Cluster -SnapshotName $NewName -VolumeGroup $VolumeGroup
            if ($newData) {
                $parentuid = $newData.parent_uid
            }
        }

        if ($data -and $newData) {
            throw (Resolve-Error -ErrorInput "Both '$Name' and '$NewName' exist. Cannot rename, cannot proceed with other updates." -Category ResourceExists)
        }

        if (-not $data) {
            if (-not $newData) {
                $errorMsg = if ($VolumeGroup) {
                    "Snapshot '$Name' does not exist in volume group '$VolumeGroup'."
                }
                else {
                    "Snapshot '$Name' does not exist."
                }
                throw (Resolve-Error -ErrorInput $errorMsg -Category ObjectNotFound)
            }
            Write-IBMSVLog -Level WARN -Message "Snapshot '$NewName' already exists. Continuing other updates on '$NewName' snapshot."
            $data = $newData
            $Name = $NewName
            $NewName = $null
        }

        # --- Update Snapshot ---
        if ($PSCmdlet.ShouldProcess("Snapshot '$Name'", "Modify")) {

            # --- Probe logic ---
            $props = @{}

            if ($NewName -and ($NewName -ne $data.name)) {
                $props['name'] = $NewName
            }

            if ($OwnershipGroup -and $OwnershipGroup -ne $data.owner_name) {
                $props['ownershipgroup'] = $OwnershipGroup
            }

            if ($props.Count -eq 0) {
                Write-IBMSVLog -Level INFO -Message "No changes required for Snapshot '$Name'."
                return
            }

            # --- Apply changes ---
            $props['snapshot'] = $Name
            if ($VolumeGroup) {
                $props['volumegroup'] = $VolumeGroup
            }
            else {
                $props['parentuid'] = $parentuid
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chsnapshot" -CmdOpts $props
            if ($result -and $result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }

            if ($props.ContainsKey('name')) {
                if ($props.Count -gt 3) {
                    Write-IBMSVLog -Level INFO -Message "Snapshot '$Name' renamed to '$NewName' and updated successfully."
                }
                else {
                    Write-IBMSVLog -Level INFO -Message "Snapshot '$Name' renamed to '$NewName'."
                }
            }
            else {
                Write-IBMSVLog -Level INFO -Message "Snapshot '$Name' updated successfully."
            }
        }
    }
}
