<#
.SYNOPSIS
Removes an existing volume from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVVolume cmdlet deletes a volume from the system.

It maps to the rmvolume command.

The cmdlet is idempotent:
- If the volume does not exist, no action is performed.

Supports -WhatIf and -Confirm for safe execution.
Due to the destructive nature, confirmation is required by default.

.PARAMETER Name
Specifies the name or UID of the volume to remove.

.PARAMETER RemoveHostMappings
Specifies that all host mappings associated with the volume are removed before deletion.

.PARAMETER RemoveFCMappings
Specifies that all Fibre Channel mappings associated with the volume are removed before deletion.

.PARAMETER RemoveRCRelationships
Specifies that all remote copy relationships associated with the volume are removed before deletion.

.PARAMETER DiscardImage
Specifies that the volume image is discarded during removal.

.PARAMETER CancelBackUp
Specifies that any active backup operations are canceled before deletion.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Remove-IBMSVVolume -Name Vol1

Removes the volume.

.EXAMPLE
PS> Remove-IBMSVVolume -Name Vol1 -RemoveHostMappings -RemoveFCMappings

Removes the volume and associated mappings.

.EXAMPLE
PS> Remove-IBMSVVolume -Name Vol1 -RemoveRCRelationships -DiscardImage

Removes the volume after cleaning up relationships.

.EXAMPLE
PS> Remove-IBMSVVolume -Name Vol1 -WhatIf

Shows what would happen if the volume were removed.

.INPUTS
System.String

You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- This is a destructive operation and cannot be undone.
- If the volume does not exist, the operation completes silently.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/rmvolume
#>

function Remove-IBMSVVolume {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [switch]$RemoveHostMappings,

        [switch]$RemoveFCMappings,

        [switch]$RemoveRCRelationships,

        [switch]$DiscardImage,

        [switch]$CancelBackUp,

        [string]$Cluster
    )

    process {
        # --- Remove Volume ---
        if ($PSCmdlet.ShouldProcess("Volume '$Name'", "Remove")) {

            # --- Existence check ---
            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvdisk" -CmdArgs $Name
            if ($current -and $current.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            if (-not $current) {
                Write-IBMSVLog -Level INFO -Message "Volume '$Name' does not exist."
                return
            }

            $opts = @{}
            if ($RemoveHostMappings) { $opts.removehostmappings = $true }
            if ($RemoveFCMappings) { $opts.removefcmaps = $true }
            if ($RemoveRCRelationships) { $opts.removercrelationships = $true }
            if ($DiscardImage) { $opts.discardimage = $true }
            if ($CancelBackUp) { $opts.cancelbackup = $true }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmvolume" -CmdOpts $opts -CmdArgs $Name
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Volume '$Name' removed successfully."
        }
    }
}
