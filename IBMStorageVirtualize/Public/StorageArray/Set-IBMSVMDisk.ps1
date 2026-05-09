<#
.SYNOPSIS
Modifies an existing MDisk (Managed Disk) in an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVMDisk cmdlet updates properties of an existing MDisk.

It maps to the chmdisk command.

The cmdlet is idempotent:
- Only properties that differ from the current configuration are modified.
- If no changes are required, no operation is performed.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER Name
Specifies the name of the MDisk to modify.

.PARAMETER NewName
Specifies a new name for the MDisk.

If both Name and NewName exist, the operation fails.

If the specified Name does not exist but NewName exists, the cmdlet continues updating the NewName mdisk.

.PARAMETER Tier
Specifies the storage tier for the MDisk.
Valid values: tier0_flash, tier1_flash, tier_enterprise, tier_nearline, tier_scm.

.PARAMETER EasyTierLoad
Specifies the Easy Tier load priority for the MDisk.
Valid values: default, low, medium, high, very_high.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Set-IBMSVMDisk -Name "mdisk01" -NewName "mdisk_prod"

Renames the MDisk from "mdisk01" to "mdisk_prod".

.EXAMPLE
PS> Set-IBMSVMDisk -Name "mdisk01" -Tier "tier0_flash"

Updates the storage tier of "mdisk01" to tier0_flash.

.EXAMPLE
PS> Set-IBMSVMDisk -Name "mdisk01" -EasyTierLoad "high"

Sets the Easy Tier load priority of "mdisk01" to high.

.EXAMPLE
PS> Set-IBMSVMDisk -Name "mdisk01" -NewName "mdisk_prod" -Tier "tier1_flash" -EasyTierLoad "medium"

Updates multiple properties of the MDisk in a single operation.

.INPUTS
System.String

You can pipe an MDisk name or objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- If the specified MDisk does not exist, a terminating error is thrown.
- If both Name and NewName exist, the operation fails.
- Only modified properties are sent to the backend.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chmdisk
#>

function Set-IBMSVMDisk {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$NewName,

        [ValidateSet("tier0_flash", "tier1_flash", "tier_enterprise", "tier_nearline", "tier_scm")]
        [string] $Tier,

        [ValidateSet("default", "low", "medium", "high", "very_high")]
        [string]$EasyTierLoad,

        [string]$Cluster
    )

    process {
        # --- Initial check ---
        if ($NewName -and $NewName -eq $Name) { $NewName = $null }
        $data = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsmdisk" -CmdArgs ("-gui", $Name)
        if ($data.err) {
            throw (Resolve-Error -ErrorInput $data -Category InvalidOperation)
        }

        $newData = if ($NewName) { Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsmdisk" -CmdArgs ("-gui", $NewName) } else { $null }
        if ($newData.err) {
            throw (Resolve-Error -ErrorInput $newData -Category InvalidOperation)
        }

        if ($data -and $newData) {
            throw (Resolve-Error -ErrorInput "Both '$Name' and '$NewName' exist. Cannot rename, cannot proceed with other updates." -Category ResourceExists)
        }
        if (-not $data) {
            if (-not $newData) {
                throw (Resolve-Error -ErrorInput "MDisk '$Name' does not exist." -Category ObjectNotFound)
            }
            Write-IBMSVLog -Level WARN -Message "MDisk '$NewName' already exists. Continuing other updates on '$NewName' MDisk."
            $data = $newData
            $Name = $NewName
        }

        # --- Update MDisk ---
        if ($PSCmdlet.ShouldProcess("MDisk '$Name'", 'Modify')) {

            # --- Probe logic ---
            $props = @{}
            if ($NewName -and ($NewName -ne $data.name)) { $props['name'] = $NewName }
            if ($Tier -and ($Tier -ne $data.tier)) { $props['tier'] = $Tier }
            if ($EasyTierLoad -and ($EasyTierLoad -ne $data.easy_tier_load)) { $props['easytierload'] = $EasyTierLoad }
            if ($props.Count -eq 0) { Write-IBMSVLog -Level INFO -Message "No changes required for MDisk '$Name'."; return }

            # --- Apply changes ---
            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chmdisk" -CmdOpts $props -CmdArgs $Name
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "MDisk '$Name' updated successfully."
        }
    }
}
