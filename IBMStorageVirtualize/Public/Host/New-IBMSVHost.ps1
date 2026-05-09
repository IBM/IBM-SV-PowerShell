<#
.SYNOPSIS
Creates a new host on an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVHost cmdlet creates a host on an IBM Storage Virtualize system.

It maps to the mkhost command.

The cmdlet is idempotent:
- If the specified host already exists, the existing host object is returned.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER Name
Specifies the name of the host to create.

.PARAMETER SasWWPN
Specifies the SAS WWPN(s) for the host.

.PARAMETER FCWWPN
Specifies the Fibre Channel WWPN(s) for the host.

.PARAMETER IscsiName
Specifies the iSCSI name(s) for the host.

.PARAMETER Nqn
Specifies the NVMe Qualified Name(s) for the host.

Requires -Protocol to be an NVMe type.

.PARAMETER FDMIName
Specifies the FDMI host name.

.PARAMETER IOGrp
Specifies the I/O group(s) for the host.

.PARAMETER Protocol
Specifies the host protocol.
Valid values: fcscsi, fcnvme, rdmanvme, tcpnvme, sas, iscsi.

.PARAMETER Type
Specifies the host type.
Valid values: hpux, tpgs, generic, openvms, adminlun, hide_secondary.

.PARAMETER Site
Specifies the site for the host.

.PARAMETER HostCluster
Specifies the host cluster.

Mutually exclusive with -OwnershipGroup.

.PARAMETER OwnershipGroup
Specifies the ownership group.

Mutually exclusive with -HostCluster.

.PARAMETER Portset
Specifies the portset for the host.

.PARAMETER Partition
Specifies the partition for the host.

.PARAMETER Location
Specifies the location of the host.

Requires -Partition.

.PARAMETER AutoStorageDiscovery
Specifies whether automatic storage discovery is enabled.
Valid values: yes, no.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> New-IBMSVHost -Name Host1 -FCWWPN "210100E08B251EE6:210100E08B251EE7" -Site site1 -HostCluster hostcluster0
PS> New-IBMSVHost -Name Host1 -FCWWPN $FCWWPN1,$FCWWPN2 -Site site1 -HostCluster hostcluster0

Creates a FC host.

.EXAMPLE
PS> New-IBMSVHost -Name Host2 -IscsiName "iqn.localhost.hostid.7f000001,iqn.localhost.hostid.7f000002" -Protocol iscsi
PS> New-IBMSVHost -Name Host2 -IscsiName $IQN1,$IQN2 -Protocol iscsi

Creates an iSCSI host.

.EXAMPLE
PS> New-IBMSVHost -Name NVMeHost1 -Nqn "nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef2ffff" -Protocol fcnvme -Portset portset0

Creates a fcnvme host.

.EXAMPLE
PS> New-IBMSVHost -Name NVMeHost1 -Nqn "nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef2ffff" -Protocol tcpnvme -Portset portset0

Creates a tcpnvme host.

.EXAMPLE
PS> New-IBMSVHost -Name NVMeHost1 -Nqn "nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef2ffff" -Protocol rdmanvme -Portset portset0

Creates a rdmanvme host.

.EXAMPLE
PS> New-IBMSVHost -Name Host1 -FCWWPN "210100E08B251EE6:210100E08B251EE7" -Protocol 'sas'

Creates a SAS host.

.EXAMPLE
PS> New-IBMSVHost -Name Host1 -FDMIName "78A1BC1-1" -Protocol 'fcscsi'

Creates a FDMI host.

.INPUTS
System.String

You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
System.Object

Returns the created host object.

If the host already exists, the existing object is returned.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Performs validation of parameter combinations before execution.
- Only one initiator type parameter is allowed.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkhost
#>

function New-IBMSVHost {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string[]]$SasWWPN,

        [string[]]$FCWWPN,

        [string[]]$IscsiName,

        [string[]]$Nqn,

        [string]$FDMIName,

        [string[]]$IOGrp,

        [ValidateSet("fcscsi", "fcnvme", "rdmanvme", "tcpnvme", "sas", "iscsi")]
        [string]$Protocol,

        [ValidateSet("hpux", "tpgs", "generic", "openvms", "adminlun", "hide_secondary")]
        [string]$Type,

        [string]$Site,

        [string]$HostCluster,

        [string]$OwnershipGroup,

        [string]$Portset,

        [string]$Partition,

        [string]$Location,

        [ValidateSet("yes", "no")]
        [string]$AutoStorageDiscovery,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        $validated = @{}

        $hostIdentifiers = @("SasWWPN", "FCWWPN", "IscsiName", "Nqn", "FDMIName")
        $currHostIdentifier = $hostIdentifiers | Where-Object { $PSBoundParameters.ContainsKey($_) }
        if ($currHostIdentifier.Count -ne 1) {
            throw (Resolve-Error -ErrorInput "You must specify exactly one initiator parameter: -SasWWPN, -FCWWPN, -IscsiName, -Nqn, -FDMIName." -Category InvalidArgument)
        }

        $mutex = @(
            @('HostCluster', 'OwnershipGroup'),
            @('Partition', 'SasWWPN'),
            @('Partition', 'IOGrp'),
            @('Partition', 'Site')
        )
        foreach ($rule in $mutex) {
            if ($PSBoundParameters.ContainsKey($rule[0]) -and $PSBoundParameters.ContainsKey($rule[1])) {
                throw (Resolve-Error -ErrorInput "Parameters -$($rule[0]) and -$($rule[1]) are mutually exclusive." -Category InvalidArgument)
            }
        }

        $requiredif = @(
            @('Location', 'Partition'),
            @('Nqn', 'Protocol')
        )
        foreach ($rule in $requiredif) {
            if ($PSBoundParameters.ContainsKey($rule[0]) -and -not $PSBoundParameters.ContainsKey($rule[1])) {
                throw (Resolve-Error -ErrorInput "Parameters -$($rule[0]) is invalid without -$($rule[1])." -Category InvalidArgument)
            }
        }

        $nqnProtocols = @('tcpnvme', 'fcnvme', 'rdmanvme', 'nvme')
        if ($Nqn -and ($Protocol -notin $nqnProtocols)) {
            throw (Resolve-Error -ErrorInput "If -Nqn is specified, -Protocol must be one of: $($nqnProtocols -join ", ")." -Category InvalidArgument)
        }

        if ($SasWWPN) {
            $res = ConvertTo-NormalizedValue -Name 'SasWWPN' -Value ($SasWWPN -join ":") -Separator ":"
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $validated.SasWWPN = $res.out
        }
        if ($FCWWPN) {
            $res = ConvertTo-NormalizedValue -Name 'FCWWPN' -Value ($FCWWPN -join ":") -Separator ":"
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $validated.FCWWPN = $res.out
        }
        if ($IscsiName) {
            $res = ConvertTo-NormalizedValue -Name 'IscsiName' -Value ($IscsiName -join ",") -Separator ","
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $validated.IscsiName = $res.out
        }
        if ($Nqn) {
            $res = ConvertTo-NormalizedValue -Name 'Nqn' -Value ($Nqn -join ",") -Separator ","
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $validated.Nqn = $res.out
        }
        if ($IOGrp) {
            $res = ConvertTo-NormalizedValue -Name 'IOGrp' -Value ($IOGrp -join ":") -Separator ":"
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $validated.IOGrp = $res.out
        }

        # --- Create host ---
        if ($PSCmdlet.ShouldProcess("Host $Name", "Create")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lshost" -CmdArgs ($Name)
            if ($existing) {
                if ($existing.err) {
                    throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
                }
                Write-IBMSVLog -Level INFO -Message "Host '$Name' already exists. Returning existing object."
                return $existing
            }

            $opts = @{ force = $true }
            foreach ($param in $validated.keys) {
                $opts[$param.ToLower()] = $validated[$param]
            }

            foreach ($field in @('Name', 'FDMIName', 'Type', 'Site', 'Portset', 'Partition', 'Location', 'Protocol', 'OwnershipGroup', 'HostCluster', 'AutoStorageDiscovery')) {
                if ($PSBoundParameters.ContainsKey($field)) {
                    $value = $PSBoundParameters[$field]
                    if ($null -ne $value -and $value -ne '') {
                        if ($value -is [System.Management.Automation.SwitchParameter]) {
                            $opts[$field.ToLower()] = if ($value.IsPresent) { $true } else { $false }
                        }
                        else {
                            $opts[$field.ToLower()] = $value
                        }
                    }
                }
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "mkhost" -CmdOpts $opts
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Host [$($result.id)] '$Name' created successfully."

            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lshost" -CmdArgs ($Name)
            if ($current.err) {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            return $current
        }
    }
}
