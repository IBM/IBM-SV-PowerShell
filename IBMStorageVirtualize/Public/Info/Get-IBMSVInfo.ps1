$ObjectRegistry = @{
    Pool                      = @{ Cmd = "lsmdiskgrp"; Version = $null; RequiresObjectName = $false }
    Node                      = @{ Cmd = "lsnode"; Version = $null; RequiresObjectName = $false }
    IOGroup                   = @{ Cmd = "lsiogrp"; Version = $null; RequiresObjectName = $false }
    HostCluster               = @{ Cmd = "lshostcluster"; Version = "7.7.1.0"; RequiresObjectName = $false }
    FCConnectivity            = @{ Cmd = "lsfabric"; Version = $null; RequiresObjectName = $false }
    FCConsistgrp              = @{ Cmd = "lsfcconsistgrp"; Version = $null; RequiresObjectName = $false }
    RCConsistgrp              = @{ Cmd = "lsrcconsistgrp"; Version = $null; RequiresObjectName = $false }
    VdiskCopy                 = @{ Cmd = "lsvdiskcopy"; Version = $null; RequiresObjectName = $false }
    FCPort                    = @{ Cmd = "lsportfc"; Version = $null; RequiresObjectName = $false }
    FabricPort                = @{ Cmd = "lsfabricport"; Version = "8.6.0.0"; RequiresObjectName = $false }
    TargetPortFC              = @{ Cmd = "lstargetportfc"; Version = "7.7.0.0"; RequiresObjectName = $false }
    iSCSIPort                 = @{ Cmd = "lsportip"; Version = $null; RequiresObjectName = $false }
    FCMap                     = @{ Cmd = "lsfcmap"; Version = $null; RequiresObjectName = $false }
    System                    = @{ Cmd = "lssystem"; Version = "6.3.0.0"; RequiresObjectName = $false }
    CloudAccount              = @{ Cmd = "lscloudaccount"; Version = "7.8.0.0"; RequiresObjectName = $false }
    CloudAccountUsage         = @{ Cmd = "lscloudaccountusage"; Version = "7.8.0.0"; RequiresObjectName = $false }
    CloudImportCandidate      = @{ Cmd = "lscloudaccountimportcandidate"; Version = "7.8.0.0"; RequiresObjectName = $false }
    LdapServer                = @{ Cmd = "lsldapserver"; Version = "6.3.0.0"; RequiresObjectName = $false }
    User                      = @{ Cmd = "lsuser"; Version = $null; RequiresObjectName = $false }
    Partnership               = @{ Cmd = "lspartnership"; Version = "6.3.0.0"; RequiresObjectName = $false }
    ReplicationPolicy         = @{ Cmd = "lsreplicationpolicy"; Version = "8.5.2.0"; RequiresObjectName = $false }
    SnapshotPolicy            = @{ Cmd = "lssnapshotpolicy"; Version = "8.5.1.0"; RequiresObjectName = $false }
    VolumeGroup               = @{ Cmd = "lsvolumegroup"; Version = "7.8.0.0"; RequiresObjectName = $false }
    VolumePopulation          = @{ Cmd = "lsvolumepopulation"; Version = "8.5.1.0"; RequiresObjectName = $false }
    VolumeGroupPopulation     = @{ Cmd = "lsvolumegrouppopulation"; Version = "8.5.1.0"; RequiresObjectName = $false }
    SnapshotSchedule          = @{ Cmd = "lssnapshotschedule"; Version = "8.5.1.0"; RequiresObjectName = $false }
    VolumeGroupSnapshotPolicy = @{ Cmd = "lsvolumegroupsnapshotpolicy"; Version = "8.5.1.0"; RequiresObjectName = $false }
    DNSServer                 = @{ Cmd = "lsdnsserver"; Version = "7.8.0.0"; RequiresObjectName = $false }
    SystemCert                = @{ Cmd = "lssystemcert"; Version = "7.6.0.0"; RequiresObjectName = $false }
    TrustStore                = @{ Cmd = "lstruststore"; Version = "8.5.1.0"; RequiresObjectName = $false }
    Sra                       = @{ Cmd = "lssra"; Version = "7.7.0.0"; RequiresObjectName = $false }
    SysLogServer              = @{ Cmd = "lssyslogserver"; Version = $null; RequiresObjectName = $false }
    UserGroup                 = @{ Cmd = "lsusergrp"; Version = $null; RequiresObjectName = $false }
    EmailServer               = @{ Cmd = "lsemailserver"; Version = $null; RequiresObjectName = $false }
    EmailUser                 = @{ Cmd = "lsemailuser"; Version = $null; RequiresObjectName = $false }
    CloudBackup               = @{ Cmd = "lsvolumebackup"; Version = "7.8.0.0"; RequiresObjectName = $false }
    CloudBackupGeneration     = @{ Cmd = "lsvolumebackupgeneration"; Version = "7.8.0.0"; RequiresObjectName = $true }
    ProvisioningPolicy        = @{ Cmd = "lsprovisioningpolicy"; Version = "8.4.1.0"; RequiresObjectName = $false }
    VolumeGroupSnapshot       = @{ Cmd = "lsvolumegroupsnapshot"; Version = "8.5.1.0"; RequiresObjectName = $false }
    CallHome                  = @{ Cmd = "lscloudcallhome"; Version = "8.2.1.0"; RequiresObjectName = $false }
    IP                        = @{ Cmd = "lsip"; Version = "8.4.2.0"; RequiresObjectName = $false }
    Ownershipgroup            = @{ Cmd = "lsownershipgroup"; Version = "8.3.0.0"; RequiresObjectName = $false }
    Portset                   = @{ Cmd = "lsportset"; Version = "8.4.2.0"; RequiresObjectName = $false }
    SafeguardedPolicy         = @{ Cmd = "lssafeguardedpolicy"; Version = "8.4.2.0"; RequiresObjectName = $false }
    SafeguardedSchedule       = @{ Cmd = "lssafeguardedschedule"; Version = "8.4.2.0"; RequiresObjectName = $false }
    EnclosureStats            = @{ Cmd = "lsenclosurestats"; Version = $null; RequiresObjectName = $false }
    EnclosureStatsHistory     = @{ Cmd = "lsenclosurestats"; Version = $null; RequiresObjectName = $true }
    DriveClass                = @{ Cmd = "lsdriveclass"; Version = "7.6.0.0"; RequiresObjectName = $false }
    Security                  = @{ Cmd = "lssecurity"; Version = "7.4.0.0"; RequiresObjectName = $false }
    Partition                 = @{ Cmd = "lspartition"; Version = "8.6.1.0"; RequiresObjectName = $false }
    Plugin                    = @{ Cmd = "lsplugin"; Version = "8.6.0.0"; RequiresObjectName = $false }
    Volumegroupreplication    = @{ Cmd = "lsvolumegroupreplication"; Version = "8.5.2.0"; RequiresObjectName = $false }
    Quorum                    = @{ Cmd = "lsquorum"; Version = $null; RequiresObjectName = $false }
    Enclosure                 = @{ Cmd = "lsenclosure"; Version = $null; RequiresObjectName = $false }
    Snmpserver                = @{ Cmd = "lssnmpserver"; Version = $null; RequiresObjectName = $false }
    Testldapserver            = @{ Cmd = "testldapserver"; Version = "6.3.0.0"; RequiresObjectName = $false }
    Availablepatch            = @{ Cmd = "lsavailablepatch"; Version = "8.7.0.0"; RequiresObjectName = $false }
    Patch                     = @{ Cmd = "lspatch"; Version = "8.5.4.0"; RequiresObjectName = $false }
    FlashsystemGrid           = @{ Cmd = "lsgrid"; Version = "8.7.1.0"; RequiresObjectName = $false }
    FlashsystemGridMembers    = @{ Cmd = "lsgridmembers"; Version = "8.7.2.0"; RequiresObjectName = $false }
    FlashsystemGridSystem     = @{ Cmd = "lsgridsystem"; Version = "8.7.3.0"; RequiresObjectName = $false }
    FlashsystemGridPartition  = @{ Cmd = "lsgridpartition"; Version = "8.7.2.0"; RequiresObjectName = $false }
    Systempatches             = @{ Cmd = "lssystempatches"; Version = "8.5.4.0"; RequiresObjectName = $false }
    HostIOGrp                 = @{ Cmd = "lshostiogrp"; Version = $null; RequiresObjectName = $true }
    VdiskAccess               = @{ Cmd = "lsvdiskaccess"; Version = $null; RequiresObjectName = $false }
    Host                      = @{ Cmd = "lshost"; Version = $null; RequiresObjectName = $false }
    Volume                    = @{ Cmd = "lsvdisk"; Version = $null; RequiresObjectName = $false }
    HostVdiskMap              = @{ Cmd = "lshostvdiskmap"; Version = $null; RequiresObjectName = $false }
    VdiskHostMap              = @{ Cmd = "lsvdiskhostmap"; Version = $null; RequiresObjectName = $true }
    HostClusterVolumeMap      = @{ Cmd = "lshostclustervolumemap"; Version = $null; RequiresObjectName = $false }
    VolumeSnapshot            = @{ Cmd = "lsvolumesnapshot"; Version = "8.5.1.0"; RequiresObjectName = $false }
    EventLog                  = @{ Cmd = "lseventlog"; Version = $null; RequiresObjectName = $false }
    RemoteCopy                = @{ Cmd = "lsrcrelationship"; Version = $null; RequiresObjectName = $false }
    Mdisk                     = @{ Cmd = "lsmdisk"; Version = $null; RequiresObjectName = $false }
    Drive                     = @{ Cmd = "lsdrive"; Version = $null; RequiresObjectName = $false }
    Array                     = @{ Cmd = "lsarray"; Version = $null; RequiresObjectName = $false }
    Timezones                 = @{ Cmd = "lstimezones"; Version = $null; RequiresObjectName = $false }
    Proxy                     = @{ Cmd = "lsproxy"; Version = $null; RequiresObjectName = $false }
}

function Test-Result {
    param(
        $Result,

        [string]$ObjectType,

        [string]$ObjectName,

        [string]$Cmd
    )

    if ($Result -is [pscustomobject] -and $Result.PSObject.Properties.Name -contains "out" -and [string]$Result.out -match 'CMMVC\d+E\s+(?<msg>[^,]+)') {
        $errorCode = ($matches[0] -split '\s+')[0]
        $errorMsg = $matches['msg'].Trim()

        switch ($errorCode) {
            "CMMVC5707E" {
                $msg = "CMMVC5707E Missing or invalid parameters for $Cmd"
                Write-IBMSVLog -Level ERROR -Message $msg
                throw $msg
            }
            "CMMVC5767E" {
                $msg = "CMMVC5767E Invalid parameters for $Cmd"
                Write-IBMSVLog -Level ERROR -Message $msg
                throw $msg
            }
            "CMMVC7205E" {
                $msg = "CMMVC7205E $Cmd unsupported on firmware"
                Write-IBMSVLog -Level ERROR -Message $msg
                throw $msg
            }
            default {
                Write-IBMSVLog -Level ERROR -Message "$errorCode $errorMsg" -HostMsg
                return @()
            }
        }
    }

    if (-not $Result) {
        if ($ObjectName) {
            Write-IBMSVLog -Level INFO -Message "$ObjectType '$ObjectName' not found."
        }
        else {
            Write-IBMSVLog -Level INFO -Message "No results found for $ObjectType"
        }
        return @()
    }

    return $Result
}

function Invoke-IBMSVInfo {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string]$ObjectType,

        [string]$ObjectName,

        [boolean]$Detailed,

        [string]$FilterValue,

        [switch]$Gui,

        [switch]$Bytes,

        [string]$Cluster
    )

    $obj = $ObjectRegistry[$ObjectType]

    $cmd = if ($obj.Cmd) { $obj.Cmd } else { "ls$($ObjectType.ToLower())" }
    $requiredVersion = $obj.Version

    if ($requiredVersion) {
        $currentVersion = Get-IBMSVVersion -Cluster $Cluster
        if ($currentVersion -and $currentVersion.PSObject.Properties.Name -contains "err") { return $currentVersion }

        if ([version]$currentVersion -lt [version]$requiredVersion) {
            return [pscustomobject]@{
                err = "$ObjectType requires firmware >= $requiredVersion (current=$currentVersion)"
            }
        }
    }

    if ($obj.RequiresObjectName -and -not $ObjectName) {
        return [pscustomobject]@{
            err = "ObjectName is required for $ObjectType"
        }
    }

    $cmdArgs = @()
    $cmdOpts = @{}

    if ($Gui) { $cmdArgs += "-gui" }
    if ($Bytes) { $cmdArgs += "-bytes" }

    if ($FilterValue) {
        $cmdOpts.filtervalue = $FilterValue
    }

    if ($cmd -eq "lsvolumebackupgeneration") {
        $localOpts = @{ volume = $ObjectName }
        if ($FilterValue) { $localOpts.filtervalue = $FilterValue }
        return Test-Result -Result (Invoke-IBMSVRestRequest -Cmd $cmd -CmdOpts $localOpts -CmdArgs $cmdArgs -Cluster $Cluster) -ObjectType $ObjectType -ObjectName $ObjectName -Cmd $cmd
    }
    elseif ($ObjectType -eq "EnclosureStatsHistory") {
        return Test-Result -Result (Invoke-IBMSVRestRequest -Cmd $cmd -CmdOpts @{ history = "power_w:temp_c:temp_f" } -CmdArgs $($cmdArgs + $ObjectName)  -Cluster $Cluster) -ObjectType $ObjectType -ObjectName $ObjectName -Cmd $cmd
    }
    elseif ($cmd -eq "lscurrentuser") {
        $Res = Test-Result -Result (Invoke-IBMSVRestRequest -Cmd $cmd -CmdArgs $($cmdArgs + $ObjectName) -Cluster $Cluster) -ObjectType $ObjectType -Cmd $cmd
        if ($Res -and $Res.PSObject.Properties.Name -contains "err") { return $Res }
        if ($Res -is [System.Collections.IEnumerable] -and
            $Res.Count -gt 1 -and
            ($Res | Where-Object { $_ -is [pscustomobject] -and $_.PSObject.Properties.Count -eq 1 }).Count -eq $Res.Count) {

            $acc = @{}
            foreach ($item in $Res) {
                $p = $item.PSObject.Properties.Name | Select-Object -First 1
                $acc[$p] = $item.$p
            }
            return [pscustomobject]$acc
        }
        return $Res
    }
    elseif ($cmd -eq "lsfabricport") {
        if (-not $Detailed) {
            return Test-Result -Result (Invoke-IBMSVRestRequest -Cmd $cmd -CmdOpts @{ callhome = $true } -CmdArgs $($cmdArgs + $ObjectName) -Cluster $Cluster) -ObjectType $ObjectType -ObjectName $ObjectName -Cmd $cmd
        }
        return Test-Result -Result (Invoke-IBMSVRestRequest -Cmd $cmd -CmdOpts @{ callhome = $true } -CmdArgs $cmdArgs -Cluster $Cluster) -ObjectType $ObjectType -ObjectName $ObjectName -Cmd $cmd
    }

    if ($Detailed) {
        if ($cmd -eq "lsdumps") {
            $nodes = Test-Result -Result (Invoke-IBMSVRestRequest -Cmd "lsnodecanister" -Cluster $Cluster -CmdArgs $cmdArgs) -ObjectType $ObjectType -Cmd $cmd
            if ($nodes -and $nodes.PSObject.Properties.Name -contains "err") { return $nodes }
            return ($nodes | ForEach-Object {
                    Test-Result -Result (Invoke-IBMSVRestRequest -Cmd "lsdumps" -CmdArgs @($_.id) -Cluster $Cluster) -ObjectType $ObjectType -ObjectName $_.id -Cmd $cmd
                })
        }

        $concise = Test-Result -Result (Invoke-IBMSVRestRequest -Cmd $cmd -CmdOpts $cmdOpts -CmdArgs $cmdArgs -Cluster $Cluster) -ObjectType $ObjectType -Cmd $cmd
        if ($concise -and $concise.PSObject.Properties.Name -contains "err") { return $concise }

        $concise = @($concise)
        if ($concise.Count -eq 0) { return @() }

        $first = $concise[0]
        $idName = $first.PSObject.Properties.Name | Select-Object -First 1

        if (-not $idName) {
            return $concise
        }

        $ids = $concise | ForEach-Object { $_.$idName }

        if ($ids.Count -ne ($ids | Select-Object -Unique).Count) {
            return $concise
        }

        $isFirstIteration = $true
        $result = [System.Collections.Generic.List[object]]::new()
        foreach ($i in $ids) {
            $tmp = Test-Result -Result (Invoke-IBMSVRestRequest -Cmd $cmd -CmdArgs ($cmdArgs + $i) -Cluster $Cluster) -ObjectType $ObjectType -ObjectName $i -Cmd $cmd
            if ($tmp -and $tmp.PSObject.Properties.Name -contains "err") { return $tmp }

            if ($isFirstIteration) {
                $isFirstIteration = $false
                if (-not $tmp) {
                    return $concise
                }

                if ($tmp.PSObject.Properties.Count -eq $first.PSObject.Properties.Count) {
                    return $concise
                }
            }

            if ($tmp -is [System.Collections.IEnumerable]) {
                $result.Add($tmp)
            }
            else {
                $result.Add(@($tmp))
            }
        }

        return $result
    }
    elseif ($ObjectName) {
        return Test-Result -Result (Invoke-IBMSVRestRequest -Cmd $cmd -CmdArgs ($cmdArgs + $ObjectName) -Cluster $Cluster) -ObjectType $ObjectType -ObjectName $ObjectName -Cmd $cmd
    }
    else {
        return Test-Result -Result (Invoke-IBMSVRestRequest -Cmd $cmd -CmdOpts $cmdOpts -CmdArgs $cmdArgs -Cluster $Cluster) -ObjectType $ObjectType -Cmd $cmd
    }
}

$Commands = $ObjectRegistry.Keys | Where-Object { $_ }
foreach ($objectType in $Commands) {
    $functionName = "Get-IBMSV$objectType"

    $scriptBlock = [ScriptBlock]::Create(@"
<#
.SYNOPSIS
Retrieves IBM Storage Virtualize $objectType information.

.DESCRIPTION
The $functionName cmdlet retrieves information for the '$objectType' object type.

By default, all objects are returned. You can filter results using -ObjectName or -FilterValue.

.PARAMETER ObjectName
Specifies the name or identifier of the object to retrieve.

Cannot be used with -Detailed or -FilterValue.

.PARAMETER FilterValue
Specifies a set of one or more (key=value) combination separated by a colon.

Format: "key=value" or "key1=value1:key2=value2".

Cannot be used with -ObjectName.

.PARAMETER Detailed
Retrieves detailed information for each object.

Cannot be used with -ObjectName.
May result in multiple API calls.

.PARAMETER Bytes
Returns capacity-related values in bytes when supported.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> $functionName

Returns all $objectType objects.

.EXAMPLE
PS> $functionName -ObjectName obj1

Returns a specific $objectType object.

.EXAMPLE
PS> $functionName -Detailed

Returns detailed information for all $objectType objects.

.EXAMPLE
PS> $functionName -FilterValue "status=online"

Returns filtered $objectType objects.

.EXAMPLE
PS> $functionName -Bytes

Returns values in bytes where supported.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Filter support depends on the backend command.
- The -Detailed parameter may result in multiple API calls.
#>

function $functionName {
    [CmdletBinding()]
    param(
        [string]`$ObjectName,
        [switch]`$Detailed,
        [string]`$FilterValue,
        [string]`$Cluster,
        [switch]`$Bytes
    )

    process {
        if (`$ObjectName -and (`$Detailed -or `$FilterValue)) {
            `$msg = "Parameter -ObjectName cannot be used together with -Detailed or -FilterValue."
            throw (Resolve-Error -ErrorInput `$msg -Category InvalidArgument)
        }

        `$params = @{
            ObjectType  = '$objectType'
            ObjectName  = `$ObjectName
            FilterValue = `$FilterValue
            Bytes       = `$Bytes
            Detailed    = `$Detailed
            Cluster     = `$Cluster
        }

        `$result = Invoke-IBMSVInfo @params

        if (`$result -and `$result.PSObject.Properties.Name -contains "err") {
            throw (Resolve-Error -ErrorInput `$result -Category InvalidOperation)
        }

        return `$result
    }
}

Export-ModuleMember -Function $functionName
"@)
    . $scriptBlock
}

function Get-IBMSVInfo {
    <#
    .SYNOPSIS
    Retrieves IBM Storage Virtualize information for one or more object types.

    .DESCRIPTION
    The Get-IBMSVInfo cmdlet retrieves information for one or more IBM Storage Virtualize object types.

    When a single object type is specified, the corresponding objects are returned.
    When multiple object types are specified, a hashtable keyed by object type is returned.

    If -Subset is not provided, the cmdlet retrieves all supported object types.
    Object types that require an ObjectName are skipped in this mode.

    .PARAMETER Subset
    Specifies one or more object types to retrieve.

    If not specified, all supported object types are retrieved.

    .PARAMETER ObjectName
    Specifies the name or identifier of the object to retrieve.

    Cannot be used with -Detailed or -FilterValue.

    .PARAMETER Detailed
    Retrieves detailed information for each object.

    Cannot be used with -ObjectName or when retrieving all object types.
    May result in multiple API calls.

    .PARAMETER FilterValue
    Specifies a filter expression to limit results.

    Format: "key=value" or "key1=value1:key2=value2".

    Requires exactly one object type and cannot be used with -ObjectName.

    .PARAMETER Cluster
    Specifies the FlashSystem cluster to connect to.

    If not provided, the primary session is used.

    .EXAMPLE
    PS> Get-IBMSVInfo

    Returns all supported object types.

    .EXAMPLE
    PS> Get-IBMSVInfo -Subset Pool

    Returns all storage pools.

    .EXAMPLE
    PS> Get-IBMSVInfo -Subset Volume -FilterValue "status=online"

    Returns filtered volume objects.

    .EXAMPLE
    PS> Get-IBMSVInfo -Subset Host -ObjectName host1

    Returns a specific host.

    .EXAMPLE
    PS> Get-IBMSVInfo -Subset Volume,Host

    Returns multiple object types in a hashtable.

    .EXAMPLE
    PS> Get-IBMSVInfo -Subset Volume -Detailed

    Returns detailed volume information.

    .INPUTS
    None.

    .OUTPUTS
    System.Object

    Returns:
    - An array of objects (single object type), or
    - A hashtable keyed by object type (multiple object types)

    .NOTES
    - Requires an authenticated session via Connect-IBMStorageVirtualize.
    - Intended for bulk retrieval scenarios.
    - For single object types, prefer specific cmdlets such as Get-IBMSVVolume or Get-IBMSVHost.
    - Filter support depends on backend capabilities.
    #>
    [CmdletBinding()]
    [OutputType([hashtable], [object[]])]
    param(
        [string[]]$Subset = $Commands,
        [string]$ObjectName,
        [switch]$Detailed,
        [string]$FilterValue,
        [string]$Cluster
    )

    process {
        if ($ObjectName -and $Detailed) {
            throw (Resolve-Error -ErrorInput "Parameter -Detailed is invalid when -ObjectName is specified." -Category InvalidArgument)
        }

        $isDiscoveryMode = ($Subset.Count -eq $Commands.Count -and -not (Compare-Object $Subset $Commands))

        if ($isDiscoveryMode -and $Detailed) {
            throw (Resolve-Error -ErrorInput "Selecting all object types with -Detailed is not supported." -Category InvalidArgument)
        }

        if ($FilterValue) {
            if ($Subset.Count -ne 1) {
                throw (Resolve-Error -ErrorInput "Parameter -FilterValue requires exactly one object type in -Subset." -Category InvalidArgument)
            }
            if ($ObjectName) {
                throw (Resolve-Error -ErrorInput "Parameter -FilterValue cannot be used with -ObjectName." -Category InvalidArgument)
            }
        }

        $output = @{}
        foreach ($objectType in $Subset | Where-Object { $_ }) {
            if ($isDiscoveryMode -and $ObjectRegistry[$objectType].RequiresObjectName) {
                Write-IBMSVLog -Level INFO -Message "Skipping $objectType in discovery mode (requires ObjectName)"
                $output[$objectType] = @()
                continue
            }

            Write-IBMSVLog -Level DEBUG -Message "Fetching $objectType information..."

            $data = Invoke-IBMSVInfo -ObjectType $objectType -ObjectName $ObjectName -Detailed $Detailed -FilterValue $FilterValue -Cluster $Cluster

            if ($data -and $data.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $data -Category InvalidOperation)
            }

            $output[$objectType] = if ($data) { $data } else { @() }
        }

        if ($Subset.Count -eq 1) {
            return $output[$Subset[0]]
        }
        return $output
    }
}
