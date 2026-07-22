<#
.SYNOPSIS
Removes an existing storage partition from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVPartition cmdlet deletes a storage partition from the IBM Storage Virtualize system.

.PARAMETER Name
Specifies the name of the storage partition to remove.

.PARAMETER DeleteNonPreferredManagementObjects
Specifies that objects on the non-preferred management system are deleted.
Mutually exclusive with -DeletePreferredManagementObjects.

.PARAMETER DeletePreferredManagementObjects
Specifies that objects on the preferred management system are deleted.
Mutually exclusive with -DeleteNonPreferredManagementObjects.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Remove-IBMSVPartition -Name partition1
Removes a storage partition.

.EXAMPLE
PS> Remove-IBMSVPartition -Name partition1 -DeleteNonPreferredManagementObjects
Removes a partition with replication policy, deleting non-preferred management objects.

.EXAMPLE
PS> Remove-IBMSVPartition -Name partition1 -DeletePreferredManagementObjects
Removes a partition with replication policy, deleting preferred management objects.

.EXAMPLE
PS> Remove-IBMSVPartition -Name partition1 -WhatIf
Shows what would happen if the partition were removed.

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
https://www.ibm.com/docs/en/search/rmpartition
#>

function Remove-IBMSVPartition {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [switch]$DeleteNonPreferredManagementObjects,

        [switch]$DeletePreferredManagementObjects,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        if ($DeleteNonPreferredManagementObjects -and $DeletePreferredManagementObjects) {
            throw (Resolve-Error -ErrorInput "Parameters -DeleteNonPreferredManagementObjects and -DeletePreferredManagementObjects are mutually exclusive." -Category InvalidArgument)
        }

        # --- Remove Partition ---
        if ($PSCmdlet.ShouldProcess("Partition '$Name'", "Remove")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lspartition" -CmdArgs ($Name)
            if ($existing -and $existing.err) {
                throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
            }
            if (-not $existing) {
                Write-IBMSVLog -Level INFO -Message "Partition '$Name' does not exist."
                return
            }

            $opts = @{}
            if ($DeleteNonPreferredManagementObjects) {
                $opts['deletenonpreferredmanagementobjects'] = $true
            }
            if ($DeletePreferredManagementObjects) {
                $opts['deletepreferredmanagementobjects'] = $true
            }

            $result = $null
            $isDeleted = $false
            $maxRetries = 3

            for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {

                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmpartition" -CmdOpts $opts -CmdArgs $Name
                if (-not $result.err -or $result.out -match '(?i)the specified object does not exist') {
                    $isDeleted = $true
                    break
                }

                if ($attempt -lt $maxRetries) {
                    Start-Sleep -Milliseconds 1500
                }
            }

            if (-not $isDeleted) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }

            Write-IBMSVLog -Level INFO -Message "Partition '$Name' removed successfully."
        }
    }
}
