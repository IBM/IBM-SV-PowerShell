<#
.SYNOPSIS
Removes an existing volumegroup from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVVolumeGroup cmdlet deletes a volumegroup from the system.

.PARAMETER Name
Specifies the name of the volume group to remove.

.PARAMETER EvictVolumes
Specifies that all volumes are removed from the volume group before deletion.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Remove-IBMSVVolumeGroup -Name vg1
Removes the volume group.

.EXAMPLE
PS> Remove-IBMSVVolumeGroup -Name vg1 -EvictVolumes
Removes the volume group after evicting all volumes.

.EXAMPLE
PS> Remove-IBMSVVolumeGroup -Name vg1 -WhatIf
Shows what would happen if the volume group were removed.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- This is a destructive operation and cannot be undone.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/rmvolumegroup
#>

function Remove-IBMSVVolumeGroup {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [switch]$EvictVolumes,

        [string]$Cluster
    )

    process {
        # --- Remove Volume Group---
        if ($PSCmdlet.ShouldProcess("Volume Group '$Name'", "Remove")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumegroup" -CmdArgs $Name
            if ($existing.err) {
                throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
            }
            if (-not $existing) {
                Write-IBMSVLog -Level INFO -Message "Volume Group '$Name' does not exist."
                return
            }

            $opts = @{}
            if ($EvictVolumes) { $opts.evictvolumes = $true }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmvolumegroup" -CmdOpts $opts -CmdArgs $Name
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Volume Group '$Name' removed successfully."
        }
    }
}
