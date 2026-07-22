<#
.SYNOPSIS
Removes an existing snapshot from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVSnapshot cmdlet deletes a snapshot from the system.

.PARAMETER Name
Specifies the name of the snapshot to remove.

.PARAMETER VolumeGroup
Specifies the name of the volumegroup associated with the snapshot.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Remove-IBMSVSnapshot -Name snapshot1 -VolumeGroup vg1
Removes a volumegroup-based snapshot.

.EXAMPLE
PS> Remove-IBMSVSnapshot -Name snapshot1 -VolumeGroup vg1 -WhatIf
Shows what would happen if the snapshot were removed.

.EXAMPLE
PS> Remove-IBMSVSnapshot -Name snapshot1 -VolumeGroup vg1 -Confirm:$false
Removes snapshot without confirmation.

.INPUTS
System.String
You can pipe objects with Name and VolumeGroup properties to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- This is a destructive operation and cannot be undone.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/rmsnapshot
#>

function Remove-IBMSVSnapshot {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)][string]$Name,

        [string]$VolumeGroup,

        [string]$Cluster
    )

    process {
        # --- Remove Snapshot ---
        if ($PSCmdlet.ShouldProcess("Snapshot '$Name'", "Remove")) {

            # --- Existence check ---
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
                Write-IBMSVLog -Level INFO -Message "Snapshot '$Name' does not exist."
                return
            }

            $opts = @{ snapshot = $Name }

            if ($VolumeGroup) {
                $opts.volumegroup = $VolumeGroup
            }
            else {
                $opts.parentuid = $existing.parent_uid
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmsnapshot" -CmdOpts $opts
            if ($result -and $result.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }

            # --- Check if snapshot entered dependent_delete state ---
            Start-Sleep -Milliseconds 500  # Brief pause to allow state update (dependent_deleting state)

            $stillExists = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumegroupsnapshot" -CmdOpts $cmdOpts
            if ($stillExists -and $stillExists.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $stillExists -Category InvalidOperation)
            }
            if (-not $VolumeGroup) {
                # Filter for independent snapshots (not part of a volume group)
                $stillExists = $stillExists | Where-Object { $_.volume_group_name -eq '' } | Select-Object -First 1
            }

            if ($stillExists) {
                Write-IBMSVLog -Level WARN -Message "Snapshot '$Name' is in '$($stillExists.state)' state. It will be removed automatically after all dependencies are removed."
            }
            else {
                Write-IBMSVLog -Level INFO -Message "Snapshot '$Name' removed successfully."
            }
        }
    }
}
