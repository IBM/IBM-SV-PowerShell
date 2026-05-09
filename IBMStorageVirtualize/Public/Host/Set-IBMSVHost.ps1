<#
.SYNOPSIS
Modifies an existing host on an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVHost cmdlet updates properties of an existing host.

It maps to chhost, addhostport, rmhostport, addhostiogrp, rmhostiogrp,
addhostclustermember, rmhostclustermember, and related commands depending on requested changes.

Some parameter updates are applied in multiple operations when required to satisfy
mutual exclusivity constraints.

The cmdlet is idempotent:
- Only properties that differ from the current configuration are modified.
- If no changes are required, no REST calls are made.

Supports -WhatIf and -Confirm for safe execution.

For parameters that accept multiple values (for example, FCWWPN, SasWWPN,
IscsiName, Nqn, and IOGrp), the provided list represents the desired final state.
Existing values not in the list are removed, and new values are added.

.PARAMETER Name
Specifies the name of the host to update.

.PARAMETER NewName
Specifies a new name for the host.

If both Name and NewName exist, the operation fails.

If the specified Name does not exist but NewName exists, the cmdlet continues updating the NewName host.

.PARAMETER Type
Specifies the host type.
Valid values: hpux, tpgs, generic, adminlun.

.PARAMETER SasWWPN
Specifies one or more SAS WWPNs.

.PARAMETER FCWWPN
Specifies one or more Fibre Channel WWPNs.

.PARAMETER IscsiName
Specifies one or more iSCSI names.

.PARAMETER Nqn
Specifies one or more NVMe Qualified Names.

.PARAMETER IOGrp
Specifies one or more I/O groups.

.PARAMETER HostUsername
Specifies the iSCSI CHAP username.

On systems running version 8.7.2.0 or later, this maps to the hostusername option of the chhost command.
On earlier versions, the cmdlet uses the iscsiusername option to achieve the same behavior.

Requires -HostSecret.

.PARAMETER HostSecret
Specifies the iSCSI CHAP secret.

On systems running version 8.7.2.0 or later, this maps to the hostsecret option of the chhost command.
On earlier versions, the cmdlet uses the chapsecret option to achieve the same behavior.

.PARAMETER NoHostSecret
Removes the host CHAP secret.

.PARAMETER StorageUsername
Specifies the storage CHAP username.

Requires -HostSecret and -StorageSecret.

.PARAMETER StorageSecret
Specifies the storage CHAP secret.

Requires -HostSecret.

.PARAMETER NoStorageSecret
Removes the storage CHAP secret.

.PARAMETER Site
Specifies the site for the host.

.PARAMETER NoSite
Removes the site assignment.

.PARAMETER StatusPolicy
Specifies the status policy.
Valid values: redundant, complete.

.PARAMETER StatusSite
Specifies the status site.
Valid values: all, local.

.PARAMETER OwnershipGroup
Specifies the ownership group.

.PARAMETER NoOwnershipGroup
Removes the ownership group.

.PARAMETER Portset
Specifies the portset.

.PARAMETER Partition
Specifies the partition.

.PARAMETER NoPartition
Removes the partition.

.PARAMETER DraftPartition
Specifies the draft partition.

.PARAMETER NoDraftPartition
Removes the draft partition.

.PARAMETER Location
Specifies the location.

.PARAMETER NoLocation
Removes the location.

.PARAMETER AutoStorageDiscovery
Specifies whether automatic storage discovery is enabled.
Valid values: yes, no.

.PARAMETER SuppressOfflineAlert
Specifies whether offline alerts are suppressed.
Valid values: yes, no.

.PARAMETER HostCluster
Specifies the host cluster to add the host to.

.PARAMETER NoHostCluster
Removes the host from its host cluster.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Set-IBMSVHost -Name Host1 -NewName HostOne

Renames the host.

.EXAMPLE
PS> Set-IBMSVHost -Name Host1 -Type generic

Updates the host type.

.EXAMPLE
PS> Set-IBMSVHost -Name Host1 -FCWWPN "210100E08B251EE6:210100F08C262EE7"

Replaces all FC WWPNs with the provided list.

.EXAMPLE
PS> Set-IBMSVHost -Name Host1 -IOGrp 0,1

Updates I/O group assignments.

.EXAMPLE
PS> Set-IBMSVHost -Name Host1 -HostCluster Cluster1

Adds the host to a host cluster.

.EXAMPLE
PS> Set-IBMSVHost -Name Host1 -NoHostCluster

Removes the host from its host cluster.

.EXAMPLE
PS> Set-IBMSVHost -Name Host1 -HostUsername user -HostSecret secret

Configures CHAP authentication.

.EXAMPLE
PS> Set-IBMSVHost -Name Host1 -StorageUsername storageuser -StorageSecret storagesecret -HostSecret hostsecret

Configures mutual CHAP authentication (requires supported system version).

.EXAMPLE
PS> Set-IBMSVHost -Name Host1 -AutoStorageDiscovery yes -SuppressOfflineAlert yes

Updates advanced host settings.

.EXAMPLE
PS> Set-IBMSVHost -Name Host1 -WhatIf

Shows what would happen without applying changes.

.INPUTS
System.String

You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- If the specified host does not exist, a terminating error is thrown.
- If both Name and NewName exist, the operation fails.
- Only modified properties are sent to the backend.
- Performs validation of parameter combinations before execution.
- Some updates are applied in multiple steps to satisfy mutual exclusivity constraints.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chhost

.LINK
https://www.ibm.com/docs/en/search/addhostclustermember

.LINK
https://www.ibm.com/docs/en/search/rmhostclustermember

.LINK
https://www.ibm.com/docs/en/search/addhostport

.LINK
https://www.ibm.com/docs/en/search/rmhostport

.LINK
https://www.ibm.com/docs/en/search/addhostiogrp

.LINK
https://www.ibm.com/docs/en/search/rmhostiogrp
#>

function Set-IBMSVHost {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName = $true)]
        [string]$Name,

        [string]$NewName,

        [ValidateSet("hpux", "tpgs", "generic", "adminlun")]
        [string]$Type,

        [string[]]$SasWWPN,

        [string[]]$FCWWPN,

        [string[]]$IscsiName,

        [string[]]$Nqn,

        [string[]]$IOGrp,

        [string]$HostUsername,

        [string]$HostSecret,

        [switch]$NoHostSecret,

        [string]$StorageUsername,

        [string]$StorageSecret,

        [switch]$NoStorageSecret,

        [string]$Site,

        [switch]$NoSite,

        [ValidateSet("redundant", "complete")]
        [string]$StatusPolicy,

        [ValidateSet("all", "local")]
        [string]$StatusSite,

        [string]$OwnershipGroup,

        [switch]$NoOwnershipGroup,

        [string]$Portset,

        [string]$Partition,

        [switch]$NoPartition,

        [string]$DraftPartition,

        [switch]$NoDraftPartition,

        [string]$Location,

        [switch]$NoLocation,

        [ValidateSet("yes", "no")]
        [string]$AutoStorageDiscovery,

        [ValidateSet("yes", "no")]
        [string]$SuppressOfflineAlert,

        [string]$HostCluster,

        [switch]$NoHostCluster,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        $validationMutexRules = @{
            mutex1  = @('HostSecret', 'NoHostSecret')
            mutex2  = @('Site', 'NoSite')
            mutex3  = @('HostUsername', 'NoHostSecret')
            mutex5  = @('Partition', 'NoPartition', 'DraftPartition', 'NoDraftPartition')
            mutex9  = @('Site', 'Partition', 'DraftPartition')
            mutex11 = @('Location', 'NoLocation')
            mutex12 = @('StorageSecret', 'NoStorageSecret')
            mutex13 = @('StorageUsername', 'NoStorageSecret')
        }
        foreach ($rule in $validationMutexRules.Values) {
            $present = $rule | Where-Object { $PSBoundParameters.ContainsKey($_) }
            if ($present.Count -gt 1) {
                throw (Resolve-Error -ErrorInput "Parameters $($present -join ', ') are mutually exclusive." -Category InvalidArgument)
            }
        }

        if ($HostUsername -and -not $HostSecret) {
            throw (Resolve-Error -ErrorInput "CMMVC1336E The -HostSecret parameter is required when the -HostUsername parameter is specified." -Category InvalidArgument)
        }
        if ($StorageUsername -and -not $StorageSecret) {
            throw (Resolve-Error -ErrorInput "CMMVC1278E The -StorageSecret parameter is required when the -StorageUsername parameter is specified." -Category InvalidArgument)
        }

        if ($SasWWPN) {
            $res = ConvertTo-NormalizedValue -Name 'SasWWPN' -Value ($SasWWPN -join ":") -Separator ":"
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $SasWWPN = $res.out
        }
        if ($FCWWPN) {
            $res = ConvertTo-NormalizedValue -Name 'FCWWPN' -Value ($FCWWPN -join ":") -Separator ":"
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $FCWWPN = $res.out
        }
        if ($IscsiName) {
            $res = ConvertTo-NormalizedValue -Name 'IscsiName' -Value ($IscsiName -join ",") -Separator ","
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $IscsiName = $res.out
        }
        if ($Nqn) {
            $res = ConvertTo-NormalizedValue -Name 'Nqn' -Value ($Nqn -join ",") -Separator ","
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $Nqn = $res.out
        }
        if ($IOGrp) {
            $res = ConvertTo-NormalizedValue -Name 'IOGrp' -Value ($IOGrp -join ":") -Separator ":"
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $IOGrp = $res.out
        }

        $mutexrules = @{
            mutex4  = @('Type', 'OwnershipGroup', 'NoOwnershipGroup')
            mutex6  = @('Name', 'Partition', 'DraftPartition')
            mutex7  = @('Type', 'Partition', 'DraftPartition')
            mutex8  = @('HostSecret', 'Partition', 'DraftPartition')
            mutex10 = @('HostUsername', 'Partition', 'DraftPartition')
        }
        $dependencies = @{
            HostUsername    = @('HostSecret')
            StorageUsername = @('HostSecret', 'StorageSecret')
            StorageSecret   = @('HostSecret')
            NoHostSecret    = @('NoStorageSecret')
        }

        # --- Initial check ---
        if ($NewName -and $NewName -eq $Name) { $NewName = $null }
        $data = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lshost" -CmdArgs ("-gui", $Name)
        if ($data.err) {
            throw (Resolve-Error -ErrorInput $data -Category InvalidOperation)
        }

        $newData = if ($NewName) { Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lshost" -CmdArgs ("-gui", $NewName) } else { $null }
        if ($newData.err) {
            throw (Resolve-Error -ErrorInput $newData -Category InvalidOperation)
        }

        if ($data -and $newData) {
            throw (Resolve-Error -ErrorInput "Both '$Name' and '$NewName' exist. Cannot rename, cannot proceed with other updates." -Category ResourceExists)
        }
        if (-not $data) {
            if (-not $newData) {
                throw (Resolve-Error -ErrorInput "Host '$Name' does not exist." -Category ObjectNotFound)
            }
            Write-IBMSVLog -Level WARN -Message "Host '$NewName' already exists. Continuing other updates on '$NewName' Host."
            $data = $newData
            $Name = $NewName
        }

        # --- Update host ---
        if ($PSCmdlet.ShouldProcess("Host '$Name'", "Modify")) {

            # --- Probe logic ---
            $props = @{}
            $SasWWPNToAdd = $null; $SasWWPNToRemove = $null
            $FCWWPNToAdd = $null; $FCWWPNToRemove = $null
            $IscsiNameToAdd = $null; $IscsiNameToRemove = $null
            $NqnToAdd = $null; $NqnToRemove = $null
            $IOGrpsToAdd = $null; $IOGrpsToRemove = $null

            $paramsMapping = @(
                @{ Key = 'NewName'; Existing = $data.name; paramName = 'name' }
                @{ Key = 'Type'; Existing = $data.type }
                @{ Key = 'Site'; Existing = $data.site_name }
                @{ Key = 'NoSite'; Existing = -not [bool]$data.site_name }
                @{ Key = 'StatusPolicy'; Existing = $data.status_policy }
                @{ Key = 'StatusSite'; Existing = $data.status_site }
                @{ Key = 'OwnershipGroup'; Existing = $data.owner_name }
                @{ Key = 'NoOwnershipGroup'; Existing = -not [bool]$data.owner_name }
                @{ Key = 'Portset'; Existing = $data.portset_name }
                @{ Key = 'NoPartition'; Existing = -not [bool]$data.partition_name }
                @{ Key = 'NoDraftPartition'; Existing = -not [bool]$data.draft_partition_name }
                @{ Key = 'Location'; Existing = $data.location_system_name }
                @{ Key = 'NoLocation'; Existing = -not [bool]$data.location_system_name }
                @{ Key = 'AutoStorageDiscovery'; Existing = $data.auto_storage_discovery }
                @{ Key = 'SuppressOfflineAlert'; Existing = $data.offline_alert_suppressed }
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
            if ($HostCluster -and $HostCluster -ne $data.host_cluster_name) {
                if ($data.host_cluster_name -ne "") {
                    throw (Resolve-Error -ErrorInput "Host already belongs to HostCluster '$($data.host_cluster_name)'." -Category InvalidOperation)
                }
                else {
                    $props["addHostCluster"] = $true
                }
            }
            elseif ($NoHostCluster -and $data.host_cluster_name -ne "") {
                $props["removeHostCluster"] = $true
            }
            if ($SasWWPN) {
                $existingSasWWPN = @($data.nodes | Where-Object { $_.SAS_WWPN } | ForEach-Object { $_.SAS_WWPN })
                $inputSasWWPN = $SasWWPN.ToUpper().Split(":")
                $SasWWPNToAdd = $inputSasWWPN | Where-Object { $_ -notin $existingSasWWPN }
                $SasWWPNToRemove = $existingSasWWPN | Where-Object { $_ -notin $inputSasWWPN }
                if ($SasWWPNToAdd.Count -gt 0 -or $SasWWPNToRemove.Count -gt 0) { $props["SasWWPN"] = $true }
            }
            if ($FCWWPN) {
                $existingFCWWPN = @($data.nodes | Where-Object { $_.WWPN } | ForEach-Object { $_.WWPN })
                $inputFCWWPN = $FCWWPN.ToUpper().Split(":")
                $FCWWPNToAdd = $inputFCWWPN | Where-Object { $_ -notin $existingFCWWPN }
                $FCWWPNToRemove = $existingFCWWPN | Where-Object { $_ -notin $inputFCWWPN }
                if ($FCWWPNToAdd.Count -gt 0 -or $FCWWPNToRemove.Count -gt 0) { $props["FCWWPN"] = $true }
            }
            if ($IscsiName) {
                $existingIscsiName = @($data.nodes | Where-Object { $_.iscsi_name } | ForEach-Object { $_.iscsi_name })
                $inputIscsiName = $IscsiName.Split(",")
                $IscsiNameToAdd = $inputIscsiName | Where-Object { $_ -notin $existingIscsiName }
                $IscsiNameToRemove = $existingIscsiName | Where-Object { $_ -notin $inputIscsiName }
                if ($IscsiNameToAdd.Count -gt 0 -or $IscsiNameToRemove.Count -gt 0) { $props["IscsiName"] = $true }
            }
            if ($Nqn) {
                $existingNqn = @($data.nodes | Where-Object { $_.Nqn } | ForEach-Object { $_.Nqn })
                $inputNqn = $Nqn.Split(",")
                $NqnToAdd = $inputNqn | Where-Object { $_ -notin $existingNqn }
                $NqnToRemove = $existingNqn | Where-Object { $_ -notin $inputNqn }
                if ($NqnToAdd.Count -gt 0 -or $NqnToRemove.Count -gt 0) { $props["Nqn"] = $true }
            }
            if ($IOGrp) {
                $existingIds = @(Get-IBMSVHostIOGrp -Cluster $Cluster -ObjectName $Name | ForEach-Object { $_.id })
                $inputIds = $IOGrp.Split(":")
                $IOGrpsToAdd = $inputIds | Where-Object { $_ -notin $existingIds }
                $IOGrpsToRemove = $existingIds | Where-Object { $_ -notin $inputIds }
                if ($IOGrpsToAdd.Count -gt 0 -or $IOGrpsToRemove.Count -gt 0) { $props["IOGrp"] = $true }
            }
            if ($Partition -and $Partition -ne $data.partition_name) {
                if ($data.partition_name -ne "") {
                    throw (Resolve-Error -ErrorInput "Host already belongs to Partition '$($data.partition_name)'." -Category InvalidOperation)
                }
                else { $props["partition"] = $Partition }
            }
            if ($DraftPartition) {
                if ($DraftPartition -eq $data.draft_partition_name) { Write-IBMSVLog -Level INFO -Message "Host '$Name' already in draft Partition '$DraftPartition'" }
                elseif ($DraftPartition -eq $data.partition_name) { Write-IBMSVLog -Level INFO -Message "Host '$Name' already in Partition '$DraftPartition'" }
                else { $props["draftpartition"] = $DraftPartition }
            }
            $version = Get-IBMSVVersion -Cluster $Cluster
            if ($version.err) {
                throw (Resolve-Error -ErrorInput $version.err -Category InvalidArgument)
            }

            if ($HostUsername) {
                if ($version -lt [version]"8.7.2.0") {
                    $props["iscsiusername"] = $HostUsername
                }
                else {
                    if ($data.iscsi_name_count -eq 0) {
                        throw (Resolve-Error -ErrorInput "CMMVC6036E Cannot set Host username without an iSCSI name associated with the host." -Category InvalidOperation)
                    }
                    if ($HostUsername -ne $data.host_username) {
                        $props["hostusername"] = $HostUsername
                    }
                }
            }
            if ($HostSecret) {
                if ($version -lt [version]"8.7.2.0") {
                    $props["chapsecret"] = $HostSecret
                }
                else {
                    $props["hostsecret"] = $HostSecret
                }
            }
            if ($NoHostSecret) {
                if ($data.storage_secret -eq "yes" -and -not $NoStorageSecret) {
                    throw (Resolve-Error -ErrorInput "CMMVC1273E To remove Host Secret, Storage Secret must be removed first." -Category InvalidOperation)
                }
                elseif ($data.host_secret -eq "yes") {
                    $props["nohostsecret"] = $true
                }
            }
            if ($StorageUsername) {
                if ($data.host_secret -ne "yes" -and -not $HostSecret) {
                    throw (Resolve-Error -ErrorInput "CMMVC1277E To set Storage Username, Host Secret must be set first." -Category InvalidOperation)

                }
                if ($version -lt [version]"8.7.2.0") {
                    throw (Resolve-Error -ErrorInput "StorageUsername is not supported parameter on current system version." -Category NotImplemented)
                }
                else {
                    if ($data.iscsi_name_count -eq 0) {
                        throw (Resolve-Error -ErrorInput "CMMVC6036E Cannot set Storage username without an iSCSI name associated with the Storage." -Category InvalidOperation)
                    }
                    if ($StorageUsername -ne $data.storage_username) {
                        $props["storageusername"] = $StorageUsername
                    }
                }
            }
            if ($StorageSecret) {
                if ($data.host_secret -ne "yes" -and -not $HostSecret) {
                    throw (Resolve-Error -ErrorInput "CMMVC1277E To set Storage Secret, Host Secret must be set first." -Category InvalidOperation)

                }
                if ($version -lt [version]"8.7.2.0") {
                    throw (Resolve-Error -ErrorInput "StorageSecret is not supported parameter on current system version." -Category NotImplemented)
                }
                else {
                    $props["storagesecret"] = $StorageSecret
                }
            }
            if ($NoStorageSecret) {
                if ($version -lt [version]"8.7.2.0") {
                    throw (Resolve-Error -ErrorInput "NoStorageSecret is not supported parameter on current system version." -Category NotImplemented)
                }
                elseif ($data.storage_secret -eq "yes") {
                    $props["nostoragesecret"] = $true
                }
            }
            if ($props.Count -eq 0) { Write-IBMSVLog -Level INFO -Message "No changes required for host '$Name'."; return }

            # --- Apply changes ---
            if ($props.ContainsKey('addHostCluster')) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "addhostclustermember" -CmdOpts @{ host = $Name } -CmdArgs $HostCluster
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                $props.remove('addHostCluster')
            }
            elseif ($props.ContainsKey('removeHostCluster')) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmhostclustermember" -CmdOpts @{ host = $Name; keepmappings = $true } -CmdArgs $data.host_cluster_name
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                $props.remove('removeHostCluster')
            }
            if ($props.ContainsKey('SasWWPN')) {
                if ($SasWWPNToRemove) {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmhostport" -CmdOpts @{ saswwpn = ($SasWWPNToRemove -join ":"); force = $true } -CmdArgs $Name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                }
                if ($SasWWPNToAdd) {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "addhostport" -CmdOpts @{ saswwpn = ($SasWWPNToAdd -join ":"); force = $true } -CmdArgs $Name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                }
                $props.remove('SasWWPN')
            }
            if ($props.ContainsKey("FCWWPN")) {
                if ($FCWWPNToRemove) {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmhostport" -CmdOpts @{ fcwwpn = ($FCWWPNToRemove -join ":"); force = $true } -CmdArgs $Name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                }
                if ($FCWWPNToAdd) {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "addhostport" -CmdOpts @{ fcwwpn = ($FCWWPNToAdd -join ":"); force = $true } -CmdArgs $Name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                }
                $props.remove("FCWWPN")
            }
            if ($props.ContainsKey("IscsiName")) {
                if ($IscsiNameToRemove) {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmhostport" -CmdOpts @{ iscsiname = ($IscsiNameToRemove -join ","); force = $true } -CmdArgs $Name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                }
                if ($IscsiNameToAdd) {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "addhostport" -CmdOpts @{ iscsiname = ($IscsiNameToAdd -join ","); force = $true } -CmdArgs $Name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                }
                $props.remove("IscsiName")
            }
            if ($props.ContainsKey("Nqn")) {
                if ($NqnToRemove) {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmhostport" -CmdOpts @{ nqn = ($NqnToRemove -join ","); force = $true } -CmdArgs $Name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                }
                if ($NqnToAdd) {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "addhostport" -CmdOpts @{ nqn = ($NqnToAdd -join ","); force = $true } -CmdArgs $Name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                }
                $props.remove("Nqn")
            }
            if ($props.ContainsKey("IOGrp")) {
                if ($IOGrpsToAdd) {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "addhostiogrp" -CmdOpts @{ iogrp = ($IOGrpsToAdd -join ":") } -CmdArgs $Name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                }
                if ($IOGrpsToRemove) {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmhostiogrp" -CmdOpts @{ iogrp = ($IOGrpsToRemove -join ":") } -CmdArgs $Name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                }
                $props.remove("IOGrp")
            }

            if ($props.Count -gt 0) {
                $groups = Resolve-MutexGroup -Props $props -Rules $mutexrules -Dependencies $dependencies

                foreach ($g in $groups) {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chhost" -CmdOpts $g -CmdArgs $Name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                    if ($g.ContainsKey('name')) { $Name = $g['name'] }
                }
            }
            Write-IBMSVLog -Level INFO -Message "Host '$Name' updated successfully."
        }
    }
}
