<#
.SYNOPSIS
Modifies an existing portset on an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVPortset cmdlet updates properties of an existing portset.

.PARAMETER Name
Specifies the name of the portset to modify.

.PARAMETER NewName
Specifies a new name for the portset.
If both Name and NewName exist, the operation fails.
If the specified Name does not exist but NewName exists, the cmdlet continues updating the NewName portset.

.PARAMETER OwnershipGroup
Specifies the ownership group for the portset.
Mutually exclusive with -NoOwnershipGroup.

.PARAMETER NoOwnershipGroup
Specifies that the ownership group is removed from the portset.
Mutually exclusive with -OwnershipGroup.

.PARAMETER ReplicationPortsetLinkUID
Specifies the replication portset link UID parameter of the portset.
Mutually exclusive with -ResetReplicationPortsetLinkUID.

.PARAMETER ResetReplicationPortsetLinkUID
Resets the replication_portset_link_uid parameter to a newly generated portset link UID.
Mutually exclusive with -ReplicationPortsetLinkUID.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Set-IBMSVPortset -Name portset1 -NewName portset1_renamed
Renames the portset.

.EXAMPLE
PS> Set-IBMSVPortset -Name portset1 -OwnershipGroup owner1
Updates the ownership group for the portset.

.EXAMPLE
PS> Set-IBMSVPortset -Name portset1 -NoOwnershipGroup
Removes the ownership group from the portset.

.EXAMPLE
PS> Set-IBMSVPortset -Name fcportset1 -ReplicationPortsetLinkUID "3A05584AC8EEA48B514F9C4F14A03540"
Updates the replication portset link UID.

.EXAMPLE
PS> Set-IBMSVPortset -Name fcportset1 -ResetReplicationPortsetLinkUID
Resets the replication portset link UID to a newly generated value.

.EXAMPLE
PS> Set-IBMSVPortset -Name portset1 -NewName portset2 -OwnershipGroup owner2
Renames and updates ownership group.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chportset
#>

function Set-IBMSVPortset {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$NewName,

        [string]$OwnershipGroup,

        [switch]$NoOwnershipGroup,

        [string]$ReplicationPortsetLinkUID,

        [switch]$ResetReplicationPortsetLinkUID,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        $mutexrules = @{
            mutex1 = @('OwnershipGroup', 'NoOwnershipGroup')
            mutex2 = @('ReplicationPortsetLinkUID', 'ResetReplicationPortsetLinkUID')
        }

        foreach ($rule in $mutexrules.Values) {
            $present = $rule | Where-Object { $PSBoundParameters.ContainsKey($_) }
            if ($present.Count -gt 1) {
                $params = $present | ForEach-Object { "-$_" }
                throw (Resolve-Error -ErrorInput "Parameters $($params -join ', ') are mutually exclusive." -Category InvalidArgument)
            }
        }

        # --- Initial check ---
        if ($NewName -and $NewName -eq $Name) { $NewName = $null }

        $data = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsportset" -CmdArgs ("-gui", $Name)
        if ($data -and $data.PSObject.Properties.Name -contains "err") {
            throw (Resolve-Error -ErrorInput $data -Category InvalidOperation)
        }

        $newData = if ($NewName) { Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsportset" -CmdArgs ("-gui", $NewName) } else { $null }
        if ($newData -and $newData.PSObject.Properties.Name -contains "err") {
            throw (Resolve-Error -ErrorInput $newData -Category InvalidOperation)
        }

        if ($data -and $newData) {
            throw (Resolve-Error -ErrorInput "Both '$Name' and '$NewName' exist. Cannot rename, cannot proceed with other updates." -Category ResourceExists)
        }

        if (-not $data) {
            if (-not $newData) {
                throw (Resolve-Error -ErrorInput "Portset '$Name' does not exist." -Category ObjectNotFound)
            }
            Write-IBMSVLog -Level WARN -Message "Portset '$NewName' already exists. Continuing other updates on '$NewName' portset."
            $data = $newData
            $Name = $NewName
            $NewName = $null
        }

        # --- Update Portset ---
        if ($PSCmdlet.ShouldProcess("Portset '$Name'", "Modify")) {

            # --- Probe logic ---
            $props = @{}
            $paramsMapping = @(
                @{ Key = 'NewName'; Existing = $data.name; paramName = 'name' }
                @{ Key = 'OwnershipGroup'; Existing = $data.owner_name }
                @{ Key = 'NoOwnershipGroup'; Existing = -not [bool]$data.owner_name }
                @{ Key = 'ReplicationPortsetLinkUID'; Existing = $data.replication_portset_link_uid }
            )
            foreach ($item in $paramsMapping) {
                if ($PSBoundParameters.ContainsKey($item.Key)) {
                    $inputValue = Get-Variable -Name $item.Key -ValueOnly
                    $paramName = if ($item.paramName) { $item.paramName } else { $item.Key.ToLower() }
                    if ($inputValue -and $inputValue -ne $item.Existing) {
                        if ($inputValue -is [System.Management.Automation.SwitchParameter]) { $inputValue = $true }
                        $props[$paramName] = $inputValue
                    }
                }
            }
            if ($ResetReplicationPortsetLinkUID) {
                $props['resetreplicationportsetlinkuid'] = $true
            }

            if ($props.Count -eq 0) {
                Write-IBMSVLog -Level INFO -Message "No changes required for Portset '$Name'."
                return
            }

            # --- Apply changes ---
            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chportset" -CmdOpts $props -CmdArgs $Name
            if ($result -and $result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }

            if ($props.ContainsKey('name')) {
                if ($props.Count -gt 1) {
                    Write-IBMSVLog -Level INFO -Message "Portset '$Name' renamed to '$NewName' and updated successfully."
                }
                else {
                    Write-IBMSVLog -Level INFO -Message "Portset '$Name' renamed to '$NewName'."
                }
            }
            else {
                Write-IBMSVLog -Level INFO -Message "Portset '$Name' updated successfully."
            }
        }
    }
}
