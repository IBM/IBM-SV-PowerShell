<#
.SYNOPSIS
Modifies an existing snapshot policy on an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVSnapshotPolicy cmdlet updates properties of an existing snapshot policy.

.PARAMETER Name
Specifies the name of the snapshot policy to modify.

.PARAMETER NewName
Specifies a new name for the snapshot policy.
If both Name and NewName exist, the operation fails.
If the specified Name does not exist but NewName exists, the cmdlet continues updating the NewName snapshotpolicy.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Set-IBMSVSnapshotPolicy -Name policy0 -NewName policy0_renamed
Renames the snapshot policy.

.EXAMPLE
PS> Set-IBMSVSnapshotPolicy -Name policy1 -NewName policy1_new -WhatIf
Shows what would happen without renaming the snapshot policy.

.EXAMPLE
PS> Get-IBMSVSnapshotPolicy | Where-Object { $_.name -eq 'old_policy' } | Set-IBMSVSnapshotPolicy -NewName 'new_policy'
Renames a snapshot policy using pipeline input.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chsnapshotpolicy
#>

function Set-IBMSVSnapshotPolicy {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$NewName,

        [string]$Cluster
    )

    process {
        # --- Initial check ---
        if ($NewName -eq $Name) { $NewName = $null }
        $data = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lssnapshotpolicy" -CmdArgs ($Name)
        if ($data -and $data.PSObject.Properties.Name -contains "err") {
            throw (Resolve-Error -ErrorInput $data -Category InvalidOperation)
        }

        $newData = if ($NewName) { Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lssnapshotpolicy" -CmdArgs ($NewName) } else { $null }
        if ($newData -and $newData.PSObject.Properties.Name -contains "err") {
            throw (Resolve-Error -ErrorInput $newData -Category InvalidOperation)
        }

        if ($data -and $newData) {
            throw (Resolve-Error -ErrorInput "Both '$Name' and '$NewName' exist. Cannot rename." -Category ResourceExists)
        }

        if (-not $data) {
            if (-not $newData) {
                throw (Resolve-Error -ErrorInput "Snapshot Policy '$Name' does not exist." -Category ObjectNotFound)
            }
            Write-IBMSVLog -Level INFO -Message "Snapshot Policy '$NewName' already exists. No changes required."
            return
        }

        # --- Update Snapshot Policy ---
        if ($PSCmdlet.ShouldProcess("Snapshot Policy '$Name'", "Modify")) {

            $props = @{}
            if ($NewName -and ($NewName -ne $data.name)) {
                $props['name'] = $NewName
            }

            if ($props.Count -eq 0) {
                Write-IBMSVLog -Level INFO -Message "No changes required for Snapshot Policy '$Name'."
                return
            }

            # --- Apply changes ---
            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chsnapshotpolicy" -CmdOpts $props -CmdArgs $Name
            if ($result -and $result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Snapshot Policy '$Name' renamed to '$NewName' successfully."
        }
    }
}
