<#
.SYNOPSIS
Removes an existing MDisk (Managed Disk) from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVMDisk cmdlet deletes an MDisk from the specified MDisk group
in the system.

It maps to the rmmdisk command.

The cmdlet is idempotent:
- If the MDisk does not exist, no action is performed.

Supports -WhatIf and -Confirm for safe execution.
Due to the destructive nature, confirmation is required by default.

.PARAMETER Name
Specifies the name of the MDisk to remove.

.PARAMETER MDiskGrp
Specifies the MDisk group containing the MDisk.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary session is used.

.EXAMPLE
PS> Remove-IBMSVMDisk -Name "mdisk01" -MDiskGrp "mdiskgrp0"

Removes the MDisk from the specified MDisk group.
Prompts for confirmation before deletion.

.EXAMPLE
PS> Remove-IBMSVMDisk -Name "mdisk01" -MDiskGrp "mdiskgrp0" -Confirm:$false

Removes the MDisk without prompting for confirmation.

.EXAMPLE
PS> Remove-IBMSVMDisk -Name "mdisk01" -MDiskGrp "mdiskgrp0" -WhatIf

Shows what would happen if the MDisk were removed.

.INPUTS
System.String

You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- This is a destructive operation and cannot be undone.
- If the MDisk does not exist, the operation completes silently.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/rmmdisk
#>

function Remove-IBMSVMDisk {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$MDiskGrp,

        [string]$Cluster
    )

    process {
        # --- Remove MDisk ---
        if ($PSCmdlet.ShouldProcess("MDisk '$Name'", "Remove")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsmdisk" -CmdArgs $Name
            if ($existing.err) {
                throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
            }
            if (-not $existing) {
                Write-IBMSVLog -Level INFO -Message "MDisk '$Name' does not exist."
                return
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmmdisk" -CmdOpts @{ mdisk = $Name } -CmdArgs $MDiskGrp
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "MDisk '$Name' removed successfully."
        }
    }
}
