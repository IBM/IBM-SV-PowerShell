<#
.SYNOPSIS
Creates a new portset on an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVPortset cmdlet creates a portset on an IBM Storage Virtualize system.

.PARAMETER Name
Specifies the name of the portset to create.

.PARAMETER Type
Specifies the type for the portset.
Valid values: host, replication, highspeedreplication, management.
If not specified, 'host' will be used as the default.

.PARAMETER PortType
Specifies the type of port that can be mapped to the portset.
Valid values: fc, ethernet.
If not specified, 'ethernet' will be used as the default.

.PARAMETER OwnershipGroup
Specifies the name of the ownership group to which the portset object is being mapped.

.PARAMETER ReplicationPortsetLinkUid
Specifies the replication portset link UID parameter for the portset.
This is a 32-character hexadecimal string that uniquely identifies the portset for replication purposes.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> New-IBMSVPortset -Name portset1 -Type host -OwnershipGroup owner1
Creates a host portset with an ownership group.

.EXAMPLE
PS> New-IBMSVPortset -Name fcportset1 -PortType fc -Type host -OwnershipGroup owner1
Creates an FC portset.

.EXAMPLE
PS> New-IBMSVPortset -Name hsrportset1 -PortType ethernet -Type highspeedreplication
Creates a high-speed replication portset.

.EXAMPLE
PS> New-IBMSVPortset -Name portset1 -Type management -OwnershipGroup owner1
Creates a management portset.

.EXAMPLE
PS> New-IBMSVPortset -Name fcportset1 -PortType fc -Type host -OwnershipGroup owner1 -ReplicationPortsetLinkUid F8C5C02FC24F019154B57B59DD753BFF
Creates an FC portset with a specific replication portset link UID.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
System.Object
Returns the created portset, or the existing portset if it already exists.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkportset
#>

function New-IBMSVPortset {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [ValidateSet("host", "replication", "highspeedreplication", "management")]
        [string]$Type,

        [ValidateSet("fc", "ethernet")]
        [string]$PortType,

        [string]$OwnershipGroup,

        [string]$ReplicationPortsetLinkUid,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        if ($PSBoundParameters.ContainsKey('ReplicationPortsetLinkUid') -and $ReplicationPortsetLinkUid -notmatch '^[0-9A-Fa-f]{32}$') {
            throw (Resolve-Error -ErrorInput "Parameter -ReplicationPortsetLinkUid must be a 32-character hexadecimal string." -Category InvalidArgument)
        }

        # --- Create Portset ---
        if ($PSCmdlet.ShouldProcess("Portset '$Name'", "Create")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsportset" -CmdArgs ($Name)
            if ($existing) {
                if ($existing.PSObject.Properties.Name -contains "err") {
                    throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
                }
                Write-IBMSVLog -Level INFO -Message "Portset '$Name' already exists. Returning existing object."
                return $existing
            }

            $opts = @{ name = $Name }
            foreach ($field in @('Type', 'PortType', 'OwnershipGroup', 'ReplicationPortsetLinkUid')) {
                if ($PSBoundParameters.ContainsKey($field)) {
                    $value = $PSBoundParameters[$field]
                    if ($null -ne $value -and $value -ne '') {
                        if ($value -is [System.Management.Automation.SwitchParameter]) {
                            $opts[$field.ToLower()] = $value.IsPresent
                        }
                        else {
                            $opts[$field.ToLower()] = $value
                        }
                    }
                }
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "mkportset" -CmdOpts $opts
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Portset [$($result.id)] '$Name' created successfully."

            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsportset" -CmdArgs ($Name)
            if ($current -and $current.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            return $current
        }
    }
}
