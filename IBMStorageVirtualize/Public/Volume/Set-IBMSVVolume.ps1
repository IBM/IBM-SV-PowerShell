<#
.SYNOPSIS
Modifies an existing volume in an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVVolume cmdlet updates properties of an existing volume.

It maps to chvolume, chvdisk, and related commands depending on system capabilities and requested changes.

The cmdlet is idempotent:
- Only properties that differ from the current configuration are modified.
- If no changes are required, no operation is performed.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER Name
Specifies the name or UID of the volume to modify.

.PARAMETER NewName
Specifies a new name for the volume.

If both Name and NewName exist, the operation fails.

If the specified Name does not exist but NewName exists, the cmdlet continues updating the NewName volume.

.PARAMETER Cache
Specifies the cache mode for the volume.
Valid values: none, readonly, readwrite.

.PARAMETER RateIOPS
Specifies the IOPS rate limit for the volume.

.PARAMETER RateMBps
Specifies the bandwidth limit (in MB/s) for the volume.

.PARAMETER Udid
Specifies the user-defined identifier (UDID) for the volume.

.PARAMETER Warning
Specifies the warning threshold for used capacity.

This parameter is only valid for thin-provisioned or compressed volumes.

The value may be specified as:
- A percentage (for example: `80%`), or
- An absolute capacity value, optionally used with `-Unit`
  (for example: `500 -Unit gb`)

.PARAMETER Unit
Specifies the unit for -Size or -Warning.
Valid values: b, kb, mb, gb, tb, pb.

.PARAMETER AutoExpand
Specifies whether automatic expansion is enabled.
Valid values: on, off.

Valid only for thin-provisioned or compressed volumes.

.PARAMETER SyncRate
Specifies the synchronization rate for the volume.

.PARAMETER EasyTier
Specifies the Easy Tier setting.
Valid values: on, off.

.PARAMETER MirrorWritePriority
Specifies the mirror write priority.
Valid values: latency, redundancy.

.PARAMETER VolumeGroup
Specifies the volume group for the volume.

Mutually exclusive with -NoVolumeGroup.

.PARAMETER NoVolumeGroup
Specifies that the volume is removed from its volume group.

Mutually exclusive with -VolumeGroup.

.PARAMETER RetainBackupEnabled
Specifies that cloud backup data is retained when removing the volume group.

Requires -NoVolumeGroup.

.PARAMETER CloudBackup
Specifies cloud backup state.
Valid values: enable, disable.

.PARAMETER CloudAccountName
Specifies the cloud account name.

Required when -CloudBackup is enable.

.PARAMETER BackupGrainsize
Specifies the grain size for cloud backup.
Valid values: 64, 256.

Valid only when -CloudBackup is enable.

.PARAMETER Size
Specifies the new size of the volume.

If the value is larger, the volume is expanded.
If smaller, the volume is shrunk.

.PARAMETER IOGrp
Specifies one or more I/O groups for the volume.

Existing I/O group access is replaced.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Set-IBMSVVolume -Name Vol1 -NewName Vol1_New

Renames the volume.

.EXAMPLE
PS> Set-IBMSVVolume -Name Vol1 -Cache readwrite -RateIOPS 5000

Updates cache and performance limits.

.EXAMPLE
PS> Set-IBMSVVolume -Name ThinVol1 -Warning 80% -AutoExpand on

Updates warning threshold and auto-expand.

.EXAMPLE
PS> Set-IBMSVVolume -Name Vol1 -Size 2 -Unit tb

Resizes the volume.

.EXAMPLE
PS> Set-IBMSVVolume -Name Vol1 -IOGrp 0,1

Updates I/O group access.

.EXAMPLE
PS> Set-IBMSVVolume -Name Vol1 -CloudBackup enable -CloudAccountName CloudAcct1

Enables cloud backup.

.INPUTS
System.String

You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- If the specified volume does not exist, a terminating error is thrown.
- If both Name and NewName exist, the operation fails.
- Only modified properties are sent to the backend.
- Performs validation of parameter combinations before execution.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chvolume

.LINK
https://www.ibm.com/docs/en/search/chvdisk

.LINK
https://www.ibm.com/docs/en/search/expandvdisksize

.LINK
https://www.ibm.com/docs/en/search/shrinkvdisksize

.LINK
https://www.ibm.com/docs/en/search/addvdiskaccess

.LINK
https://www.ibm.com/docs/en/search/rmvdiskaccess
#>

function Set-IBMSVVolume {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$NewName,

        [ValidateSet("none", "readonly", "readwrite")]
        [string]$Cache,

        [int]$RateIOPS,

        [int]$RateMBps,

        [ValidatePattern('^(0x[0-9A-Fa-f]+|[0-9]+)$')]
        [string]$Udid,

        [string]$Warning,

        [ValidateSet("b", "kb", "mb", "gb", "tb", "pb")]
        [string]$Unit,

        [ValidateSet("on", "off")]
        [string]$AutoExpand,

        [int]$SyncRate,

        [ValidateSet("on", "off")]
        [string]$EasyTier,

        [ValidateSet("latency", "redundancy")]
        [string]$MirrorWritePriority,

        [string]$VolumeGroup,

        [switch]$NoVolumeGroup,

        [switch]$RetainBackupEnabled,

        [ValidateSet("enable", "disable")]
        [string]$CloudBackup,

        [string]$CloudAccountName,

        [ValidateSet(64, 256)]
        [int]$BackupGrainsize,

        [int64]$Size,

        [string[]]$IOGrp,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        if ($VolumeGroup -and $NoVolumeGroup) {
            throw (Resolve-Error -ErrorInput "Parameters -VolumeGroup and -NoVolumeGroup are mutually exclusive." -Category InvalidArgument)
        }

        if ($Size -and $Warning) {
            throw (Resolve-Error -ErrorInput "Parameters -Size and -Warning are mutually exclusive." -Category InvalidArgument)
        }

        if ($Unit -and (-not $Size -and -not $Warning )) {
            throw (Resolve-Error -ErrorInput "CMMVC5731E Parameter -Unit is invalid without -Size or -Warning." -Category InvalidArgument)
        }

        if ($CloudBackup -eq 'enable') {
            if (-not $CloudAccountName) {
                throw (Resolve-Error -ErrorInput "Parameter -CloudAccountName is required when -CloudBackup is 'enable'." -Category InvalidArgument)
            }
        }
        else {
            if ($CloudAccountName) {
                throw (Resolve-Error -ErrorInput "Parameter -CloudAccountName can only be used when -CloudBackup is 'enable'." -Category InvalidArgument)
            }
            if ($BackupGrainsize) {
                throw (Resolve-Error -ErrorInput "Parameter -BackupGrainsize can only be used when -CloudBackup is 'enable'." -Category InvalidArgument)
            }
        }
        if ($RetainBackupEnabled -and -not $NoVolumeGroup) {
            throw (Resolve-Error -ErrorInput "Parameter -RetainBackupEnabled requires -NoVolumeGroup." -Category InvalidArgument)
        }

        if ($IOGrp) {
            $res = ConvertTo-NormalizedValue -Name 'IOGrp' -Value ($IOGrp -join ":") -Separator ":"
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $IOGrp = $res.out
        }

        # --- Initial check ---
        $data = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvdisk" -CmdArgs ("-gui", "-bytes", $Name)
        if ($data -and $data.PSObject.Properties.Name -contains "err") {
            throw (Resolve-Error -ErrorInput $data -Category InvalidOperation)
        }

        $newData = if ($NewName) { Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvdisk" -CmdArgs ("-gui", "-bytes", $NewName) } else { $null }
        if ($newData -and $newData.PSObject.Properties.Name -contains "err") {
            throw (Resolve-Error -ErrorInput $newData -Category InvalidOperation)
        }

        if ($data -and $newData) {
            if (($data[0].name -eq $newData[0].name) -and ($data[0].vdisk_UID -ne $newData[0].vdisk_UID)) {
                throw (Resolve-Error -ErrorInput "Multiple volumes with the same name '$($data[0].name)' exist with different UIDs. Cannot rename, cannot proceed with other updates." -Category ResourceExists)
            }
            elseif ($data[0].name -ne $newData[0].name) {
                throw (Resolve-Error -ErrorInput "Both '$Name' and '$NewName' exist. Cannot rename, cannot proceed with other updates." -Category ResourceExists)
            }
        }
        if (-not $data) {
            if (-not $newData) {
                throw (Resolve-Error -ErrorInput "Volume '$Name' does not exist." -Category ObjectNotFound)
            }
            Write-IBMSVLog -Level WARN -Message "Volume '$NewName' already exists. Continuing other updates on '$NewName' Volume."
            $data = $newData
            $Name = $NewName
        }

        # --- Update Volume ---
        if ($PSCmdlet.ShouldProcess("Volume '$Name'", "Modify")) {

            $thinVol = if ($data[1].se_copy -eq "yes") { $true } else { $false }
            $compressedVol = if ($data[1].compressed_copy -eq "yes") { $true } else { $false }

            $version = Get-IBMSVVersion -Cluster $Cluster
            if ($version.err) {
                throw (Resolve-Error -ErrorInput $version -Category InvalidOperation)
            }
            $chvolumeSupported = $version -ge "9.1.0.0"

            # --- Probe logic ---
            $props = @{
                chvolume = @()
                chvdisk  = @()
                other    = @()
            }

            if ($NewName -and ($NewName -ne $data[0].name)) {
                if ($chvolumeSupported) {
                    $props.chvolume += @{ name = $NewName }
                }
                else {
                    $props.chvdisk += @{ name = $NewName }
                }
            }
            if ($Cache -and ($Cache -ne $data[0].cache)) {
                $props.chvdisk += @{cache = $Cache }
            }
            if ($RateIOPS -and $RateIOPS -ne [int]($data[0].IOPs_limit)) {
                $props.chvdisk += @{rate = $RateIOPS }
            }
            if ($RateMBps -and $RateMBps -ne [int]($data[0].bandwidth_limit_MB)) {
                $props.chvdisk += @{
                    rate   = $RateMBps
                    unitmb = $true
                }
            }
            if ($Udid -and ($Udid -ne $data[0].udid)) {
                $props.chvdisk += @{udid = $Udid }
            }
            if ($Warning) {
                if (-not $thinVol -and -not $compressedVol) {
                    throw (Resolve-Error -ErrorInput "Parameter -Warning is applicable only for thin-provisioned and compressed volumes." -Category InvalidArgument)
                }
                $inputPercent = [int]($Warning.TrimEnd('%'))
                $existingPercent = [int]($data[1].warning)
                if ($Warning -match '^\d+%$') {
                    if ($inputPercent -ne $existingPercent) {
                        $props.chvdisk += @{warning = $Warning }
                    }
                }
                else {
                    $existingPercent = [int]$data[1].warning
                    $capacityBytes = [int64]$data[0].capacity

                    $unitUsed = if ($Unit) { $Unit } else { 'mb' }
                    $inputBytes = ConvertTo-Byte -Size $Warning -Unit $unitUsed
                    $inputBytes = [math]::Ceiling($inputBytes / 512) * 512

                    $inputPercent = ($inputBytes / $capacityBytes) * 100
                    $inputPercentRounded = [math]::Round($inputPercent, 0, [MidpointRounding]::AwayFromZero)

                    if ($inputPercentRounded -ne $existingPercent) {
                        $props.chvdisk += @{
                            warning = $Warning
                            unit    = $unitUsed
                        }
                    }
                }
            }
            if ($AutoExpand -and ($AutoExpand -ne $data[1].autoexpand)) {
                if (-not $thinVol -and -not $compressedVol) {
                    throw (Resolve-Error -ErrorInput "Parameter -AutoExpand is applicable only for thin-provisioned and compressed volumes." -Category InvalidArgument)
                }
                $props.chvdisk += @{ autoexpand = $AutoExpand }
            }
            if ($SyncRate -and ($SyncRate -ne [int]($data[0].sync_rate))) {
                $props.chvdisk += @{ syncrate = $SyncRate }
            }
            if ($EasyTier -and ($EasyTier -ne $data[1].easy_tier)) {
                $props.chvdisk += @{ easytier = $EasyTier }
            }
            if ($MirrorWritePriority -and ($MirrorWritePriority -ne $data[0].mirror_write_priority)) {
                $props.chvdisk += @{ mirrorwritepriority = $MirrorWritePriority }
            }
            if ($VolumeGroup -and ($VolumeGroup -ne $data[0].volume_group_name)) {
                if ($chvolumeSupported) {
                    $props.chvolume += @{ volumegroup = $VolumeGroup }
                }
                else {
                    $props.chvdisk += @{ volumegroup = $VolumeGroup }
                }
            }
            if ($NoVolumeGroup -and $data[0].volume_group_name -ne "") {
                if ($RetainBackupEnabled) {
                    $props.chvdisk += @{
                        novolumegroup       = $true
                        retainbackupenabled = $true
                    }
                }
                else {
                    if ($chvolumeSupported) { $props.chvolume += @{ novolumegroup = $true } }
                    else { $props.chvdisk += @{ novolumegroup = $true } }
                }
            }
            if ($CloudBackup) {
                if ($CloudBackup -eq "enable") {
                    if ($data[0].cloud_backup_enabled -eq "no") {
                        $props.chvdisk += @{
                            backup = "cloud"
                            enable = $true
                        }
                    }
                }
                else {
                    if ($data[0].cloud_backup_enabled -eq "yes") {
                        $props.chvdisk += @{
                            backup  = "cloud"
                            disable = $true
                        }
                    }
                }
            }
            if ($CloudAccountName -and ($CloudAccountName -ne $data[0].cloud_account_name)) { $props.chvdisk += @{ cloudaccountname = $CloudAccountName } }
            if ($BackupGrainsize -and ($BackupGrainsize -ne [int]($data[0].backup_grain_size))) { $props.chvdisk += @{ backupgrainsize = $BackupGrainsize } }

            if ($IOGrp) {
                $existingIds = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvdiskaccess" -CmdArgs ($Name)
                if ($existingIds.err) {
                    throw (Resolve-Error -ErrorInput $existingIds -Category InvalidOperation)
                }
                $existingIds = @($existingIds | ForEach-Object { $_.IO_group_id })
                $inputIds = $IOGrp.Split(":")
                $IOGrpsToAdd = $inputIds | Where-Object { $_ -notin $existingIds }
                $IOGrpsToRemove = $existingIds | Where-Object { $_ -notin $inputIds }
                if ($IOGrpsToAdd.Count -gt 0) {
                    $props.other += @{
                        type  = 'addIOGrp'
                        iogrp = ($IOGrpsToAdd -join ":")
                    }
                }
                if ($IOGrpsToRemove.Count -gt 0) {
                    $props.other += @{
                        type  = 'removeIOGrp'
                        iogrp = ($IOGrpsToRemove -join ":")
                    }
                }
            }
            if ($Size) {
                $unitUsed = if ($Unit) { $Unit } else { 'mb' }
                $inputBytes = [int64](ConvertTo-Byte -Size $Size -Unit $unitUsed)
                $existingBytes = [int64]$data[0].capacity

                if ($inputBytes -ne $existingBytes) {

                    if ($inputBytes -gt $existingBytes) {
                        if ($chvolumeSupported) {
                            $cmd = @{ size = $Size }
                            if ($PSBoundParameters.ContainsKey('Unit')) {
                                $cmd['unit'] = $Unit
                            }
                            $props.chvolume += $cmd
                        }
                        else {
                            $props.other += @{
                                type = 'expandSize'
                                size = [int64]($inputBytes - $existingBytes)
                            }
                        }
                    }
                    else {
                        $props.other += @{
                            type = 'shrinkSize'
                            size = [int64]($existingBytes - $inputBytes)
                        }
                    }
                }
            }

            if ($props.chvolume.Count -eq 0 -and $props.chvdisk.Count -eq 0 -and $props.other.Count -eq 0) {
                Write-IBMSVLog -Level INFO -Message "No changes required for Volume '$Name'."
                return
            }

            # --- Apply changes ---
            foreach ($opts in $props.chvolume) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chvolume" -CmdOpts $opts -CmdArgs $Name
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                if ($opts.ContainsKey('name')) { $Name = $NewName }
            }

            foreach ($opts in $props.chvdisk) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chvdisk" -CmdOpts $opts -CmdArgs $Name
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                if ($opts.ContainsKey('name')) { $Name = $NewName }
            }

            foreach ($key in $props.other) {
                switch ($key.type) {
                    'expandSize' {
                        $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "expandvdisksize" -CmdOpts @{ size = $key.size; unit = 'b' } -CmdArgs $Name
                        if ($result.err) {
                            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                        }
                    }
                    'shrinkSize' {
                        $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "shrinkvdisksize" -CmdOpts @{ size = $key.size; unit = 'b' } -CmdArgs $Name
                        if ($result.err) {
                            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                        }
                    }
                    'addIOGrp' {
                        $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "addvdiskaccess" -CmdOpts @{ iogrp = $key.iogrp } -CmdArgs $Name
                        if ($result.err) {
                            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                        }
                    }
                    'removeIOGrp' {
                        $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmvdiskaccess" -CmdOpts @{ iogrp = $key.iogrp } -CmdArgs $Name
                        if ($result.err) {
                            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                        }
                    }
                }
            }

            Write-IBMSVLog -Level INFO -Message "Volume '$Name' updated successfully."
        }
    }
}
