<#
.SYNOPSIS
Creates a new snapshot on an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVSnapshot cmdlet creates a snapshot on an IBM Storage Virtualize system.

.PARAMETER Name
Specifies the name of the snapshot to create.

.PARAMETER VolumeGroup
Specifies the name of the source volume group for which the snapshot is being created.
Mutually exclusive with -Volumes.

.PARAMETER Volumes
Specifies the name(s) of the volumes for which the snapshots are to be created.
Multiple volumes can be specified as an array or colon-separated string.
Mutually exclusive with -VolumeGroup.

.PARAMETER Pool
Specifies the name of the child pool within which the snapshot is being created.

.PARAMETER IgnoreLegacy
Specifies that the volume snapshots are added although there are already legacy FlashCopy mappings using the volume as a source.

.PARAMETER Safeguarded
Specifies that the snapshot is safeguarded.
Requires -RetentionDays or -RetentionMinutes.

.PARAMETER RetentionDays
Specifies the retention period in days for safeguarded snapshots.
Requires -Safeguarded.
Mutually exclusive with -RetentionMinutes.

.PARAMETER RetentionMinutes
Specifies the retention period in minutes (range 1-1440) for snapshots.
Mutually exclusive with -RetentionDays.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> New-IBMSVSnapshot -Name snap1 -VolumeGroup vg1 -Pool Pool0Childpool0
Creates a snapshot of a volume group.

.EXAMPLE
PS> New-IBMSVSnapshot -Name snap2 -Volumes vol1,vol2 -Pool Pool0Childpool0
Creates a snapshot of multiple volumes.

.EXAMPLE
PS> New-IBMSVSnapshot -Name snap3 -Volumes vol1 -Pool Pool0Childpool0 -Safeguarded -RetentionDays 7
Creates a safeguarded snapshot with 7 days retention.

.EXAMPLE
PS> New-IBMSVSnapshot -Name snap4 -VolumeGroup vg1 -Pool Pool0Childpool0 -RetentionMinutes 60
Creates a snapshot with 60 minutes retention.

.EXAMPLE
PS> New-IBMSVSnapshot -Name snap5 -Volumes vol1,vol2 -Pool Pool0Childpool0 -IgnoreLegacy
Creates a snapshot ignoring legacy FlashCopy mappings.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
System.Object
Returns the created snapshot, or the existing snapshot if it already exists.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/addsnapshot
#>

function New-IBMSVSnapshot {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)][string]$Name,

        [string]$VolumeGroup,

        [string[]]$Volumes,

        [string]$Pool,

        [switch]$IgnoreLegacy,

        [switch]$Safeguarded,

        [int]$RetentionDays,

        [int]$RetentionMinutes,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        $validated = @{}
        if (-not $VolumeGroup -and -not $Volumes) {
            throw (Resolve-Error -ErrorInput "Either -VolumeGroup or -Volumes must be specified." -Category InvalidArgument)
        }

        $mutexrules = @{
            mutex1 = @('VolumeGroup', 'Volumes')
            mutex2 = @('RetentionDays', 'RetentionMinutes')
            mutex3 = @('Safeguarded', 'RetentionMinutes')
        }

        foreach ($rule in $mutexrules.Values) {
            $present = $rule | Where-Object { $PSBoundParameters.ContainsKey($_) }
            if ($present.Count -gt 1) {
                $params = $present | ForEach-Object { "-$_" }
                throw (Resolve-Error -ErrorInput "Parameters $($params -join ', ') are mutually exclusive." -Category InvalidArgument)
            }
        }

        if ($PSBoundParameters.ContainsKey('Safeguarded') -and -not $PSBoundParameters.ContainsKey('RetentionDays')) {
            throw (Resolve-Error -ErrorInput "The -RetentionDays parameter is required when the -Safeguarded parameter is specified." -Category InvalidArgument)
        }

        if ($Volumes) {
            $res = ConvertTo-NormalizedValue -Name 'Volume' -Value ($Volumes -join ":") -Separator ":"
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $validated.Volumes = $res.out
        }

        # --- Create Snapshot ---
        if ($PSCmdlet.ShouldProcess("Snapshot '$Name'", "Create")) {

            # --- Existence check ---
            if ($VolumeGroup) {
                $checkOpts = @{
                    snapshot    = $Name
                    volumegroup = $VolumeGroup
                }
                $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumegroupsnapshot" -CmdOpts $checkOpts
            }
            else {
                $checkOpts = @{
                    filtervalue = "snapshot_name=$Name"
                }
                $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumesnapshot" -CmdOpts $checkOpts
                if ($existing.PSObject.Properties.Name -contains "err") {
                    throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
                }

                # Filter for independent snapshots (not part of a volume group)
                if ($existing) {
                    $existing = $existing | Where-Object { $_.volume_group_name -eq '' } | Select-Object -First 1
                }
            }

            if ($existing) {
                Write-IBMSVLog -Level INFO -Message "Snapshot '$Name' already exists. Returning existing object."
                return $existing
            }

            $opts = @{ name = $Name }
            foreach ($param in $validated.keys) {
                $opts[$param.ToLower()] = $validated[$param]
            }
            foreach ($field in @('Pool', 'IgnoreLegacy', 'RetentionMinutes', 'VolumeGroup', 'Safeguarded', 'RetentionDays')) {
                if ($PSBoundParameters.ContainsKey($field)) {
                    $value = $PSBoundParameters[$field]
                    if ($null -ne $value -and ($value -isnot [string] -or $value -ne '')) {
                        if ($value -is [System.Management.Automation.SwitchParameter]) {
                            $opts[$field.ToLower()] = $value.IsPresent
                        }
                        else {
                            $opts[$field.ToLower()] = $value
                        }
                    }
                }
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "addsnapshot" -CmdOpts $opts
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Snapshot '$Name' created successfully."

            if ($VolumeGroup) {
                $retrieveOpts = @{
                    snapshot    = $Name
                    volumegroup = $VolumeGroup
                }
                $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumegroupsnapshot" -CmdOpts $retrieveOpts
            }
            else {
                $retrieveOpts = @{
                    filtervalue = "snapshot_name=$Name"
                }
                $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumesnapshot" -CmdOpts $retrieveOpts
                if ($current) {
                    $current = $current | Where-Object { $_.volume_group_name -eq '' }
                }
            }

            if ($current -and $current.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            return $current
        }
    }
}
