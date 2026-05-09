<#
.SYNOPSIS
Removes an existing volumegroup from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVVolumeGroup cmdlet deletes a volumegroup from the system.

It maps to the rmvolumegroup command.

The cmdlet is idempotent:
- If the volumegroup does not exist, no action is performed.

Supports -WhatIf and -Confirm for safe execution.
Due to the destructive nature, confirmation is required by default.

.PARAMETER Name
Specifies the name of the volumegroup to remove.

.PARAMETER EvictVolumes
Specifies that all volumes are removed from the volumegroup before deletion.

This removes volumes from the group but does not delete the volumes.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Remove-IBMSVVolumeGroup -Name vg1

Removes the volumegroup.

.EXAMPLE
PS> Remove-IBMSVVolumeGroup -Name vg1 -EvictVolumes

Removes the volumegroup after evicting all volumes.

.EXAMPLE
PS> Get-IBMSVVolumeGroup | Where-Object { $_.name -like 'test*' } | Remove-IBMSVVolumeGroup

Removes volumegroups using pipeline input.

.INPUTS
System.String

You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- This is a destructive operation and cannot be undone.
- If the volumegroup does not exist, the operation completes silently.
- Fully supports -WhatIf and -Confirm.

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
