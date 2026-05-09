<#
.SYNOPSIS
Creates a new MDisk (Managed Disk) in an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVMDisk cmdlet creates a managed disk (MDisk) in the specified MDisk group.

It supports creating:
- A traditional array using explicitly specified drives (mkarray), or
- A distributed array using either manually specified layout parameters or system recommendations (mkdistributedarray).

When -UseRecommendation is specified, the cmdlet queries the system for an optimal array layout using lsarrayrecommendation and applies the first recommended configuration.

The cmdlet is idempotent:
- If a MDisk with the specified name already exists, the existing object is returned.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER Name
Specifies the name of the MDisk to create.

.PARAMETER MDiskGrp
Specifies the MDisk group in which to create the MDisk.

.PARAMETER Level
Specifies the RAID level for the array.
Valid values: raid0, raid1, raid5, raid6, raid10.

Required when:
- Creating a traditional array, or
- Creating a distributed array without -UseRecommendation.

.PARAMETER Strip
Specifies the strip size (in KiB) for the array.
Default value: 256.

.PARAMETER SlowWritePriority
Specifies whether the system prioritizes completing slow write operations, even if it temporarily reduces redundancy.
Valid values: latency, redundancy.

.PARAMETER Encrypt
Specifies whether the array should be encrypted.
Valid values: yes, no.

Defaults to yes when encryption is enabled and supported by all nodes in the I/O group.

.PARAMETER Drive
Specifies one or more drives to include in a traditional array.

Required for traditional array creation.

.PARAMETER SpareGoal
Specifies the number of spare drives for a traditional array.

.PARAMETER DriveClass
Specifies the drive class for distributed array creation.

Used for:
- Manual distributed array creation, or
- As input for recommendation queries.

Default value: 0.

.PARAMETER DriveCount
Specifies the number of drives in a distributed array.

Required when not using -UseRecommendation.

When using -UseRecommendation:
- If not specified, all available candidate drives are used.
- If specified, the value is validated and used as input for the recommendation query.

.PARAMETER StripeWidth
Specifies the stripe width for a distributed array.

.PARAMETER RebuildAreas
Specifies the number of rebuild areas for a distributed array.
Valid values: 0, 1, 2, 3, 4.

.PARAMETER RebuildAreasGoal
Specifies the rebuild areas goal for a distributed array.
Valid values: 0, 1, 2, 3, 4.

.PARAMETER AllowSuperior
Specifies whether to allow the use of superior drives in a distributed array.

.PARAMETER UseRecommendation
Specifies that the system automatically selects optimal distributed array parameters using lsarrayrecommendation.

When specified:
- Parameters -Level, -StripeWidth, -RebuildAreas, -RebuildAreasGoal, and -AllowSuperior cannot be used.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> New-IBMSVMDisk -Name MDisk1 -MDiskGrp MDG1 -Level raid1 -Drive @("1A","1B","1C") -SpareGoal 1

Creates a RAID 1 MDisk in MDisk Group MDG1 using specified drives with one spare.

.EXAMPLE
PS> New-IBMSVMDisk -Name DistMDisk1 -MDiskGrp MDG2 -Level raid5 -DriveClass 0 -DriveCount 6 -StripeWidth 4 -AllowSuperior

Creates a distributed RAID 5 MDisk with manual configuration.

.EXAMPLE
PS> New-IBMSVMDisk -Name RecmDistMDisk1 -MDiskGrp MDG3 -UseRecommendation

Creates a distributed RAID 5 MDisk named `RecmDistMDisk1` in MDisk Group `MDG3` using system-recommended parameters based on available candidate drives.

.INPUTS
System.String

You can pipe name, mdiskgrp and level to this cmdlet.

.OUTPUTS
System.Object

Returns the MDisk object.

If the MDisk already exists, the existing object is returned.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Performs validation of parameter combinations before execution.
- Supports both traditional and distributed arrays.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkdistributedarray

.LINK
https://www.ibm.com/docs/en/search/mkarray
#>

function New-IBMSVMDisk {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = "DistributedArray")]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$MDiskGrp,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateSet("raid0", "raid1", "raid5", "raid6", "raid10")]
        [string]$Level,

        [int]$Strip = 256,

        [ValidateSet("latency", "redundancy")]
        [string]$SlowWritePriority,

        [ValidateSet("yes", "no")]
        [string]$Encrypt,

        [string]$Cluster,

        [Parameter(Mandatory, ParameterSetName = 'Array')]
        [string[]]$Drive,

        [Parameter(ParameterSetName = 'Array')]
        [int]$SpareGoal,

        [Parameter(ParameterSetName = 'DistributedArray')]
        [int]$DriveClass = 0,

        [Parameter(ParameterSetName = 'DistributedArray')]
        [int]$DriveCount,

        [Parameter(ParameterSetName = 'DistributedArray')]
        [int]$StripeWidth,

        [Parameter(ParameterSetName = 'DistributedArray')]
        [ValidateSet(0, 1, 2, 3, 4)]
        [int]$RebuildAreas,

        [Parameter(ParameterSetName = 'DistributedArray')]
        [ValidateSet(0, 1, 2, 3, 4)]
        [int]$RebuildAreasGoal,

        [Parameter(ParameterSetName = 'DistributedArray')]
        [switch]$AllowSuperior,

        [Parameter(ParameterSetName = 'DistributedArray')]
        [switch]$UseRecommendation
    )

    process {
        # --- Parameter-level validation ---
        if ($Drive) {
            $res = ConvertTo-NormalizedValue -Name 'Drive' -Value ($Drive -join ":") -Separator ":"
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $Drive = $res.out
        }

        if ((-not $Drive -and -not $DriveCount) -and -not $UseRecommendation -and -not $Level) {
            throw (Resolve-Error -ErrorInput "To create an MDisk you must specify -Level with -Drive, or -Level with -DriveCount, or -UseRecommendation." -Category InvalidArgument)
        }

        if ($Level -and -not $UseRecommendation -and -not $Drive -and -not $DriveCount) {
            throw (Resolve-Error -ErrorInput "Parameter -Drive or -DriveCount must be specified when -Level is specified." -Category InvalidArgument)
        }

        switch ($PSCmdlet.ParameterSetName) {
            'Array' {
                if (-not $Level) {
                    throw (Resolve-Error -ErrorInput "Parameter -Level is required when using -Drive." -Category InvalidArgument)
                }
            }

            'DistributedArray' {
                if ($UseRecommendation) {
                    $invalid = @()
                    if ($Level) { $invalid += "-Level" }
                    if ($StripeWidth) { $invalid += "-StripeWidth" }
                    if ($RebuildAreas) { $invalid += "-RebuildAreas" }
                    if ($RebuildAreasGoal) { $invalid += "-RebuildAreasGoal" }
                    if ($AllowSuperior) { $invalid += "-AllowSuperior" }
                    if ($invalid) {
                        throw (Resolve-Error -ErrorInput "Parameter(s) $($invalid -join ', ') cannot be used with -UseRecommendation." -Category InvalidArgument)
                    }
                }
                else {
                    $missing = @()
                    if (-not $Level) { $missing += "-Level" }
                    if (-not $DriveCount) { $missing += "-DriveCount" }
                    if ($missing) {
                        throw (Resolve-Error -ErrorInput "Parameter(s) $($missing -join ', ') required when not using -UseRecommendation." -Category InvalidArgument)
                    }
                }
            }
        }

        # --- Create MDisk ---
        if ($PSCmdlet.ShouldProcess("MDisk '$Name'", 'Create')) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsmdisk" -CmdArgs ($Name)
            if ($existing) {
                if ($existing.err) {
                    throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
                }
                Write-IBMSVLog -Level INFO -Message "MDisk '$Name' already exists. Returning existing object."
                return $existing
            }

            # --- Recommendation handling ---
            if ($UseRecommendation) {
                $recommendations = Get-IBMSVArrayRecommendation `
                    -MDiskGrp $MDiskGrp `
                    -DriveClass $DriveClass `
                    -DriveCount $DriveCount `
                    -Cluster $Cluster

                if (-not $recommendations -or $recommendations.Count -eq 0) {
                    throw (Resolve-Error -ErrorInput "No array recommendations available for the specified parameters." -Category InvalidArgument)
                }

                $DriveCount = $recommendations[0].drive_count
                $DriveClass = $recommendations[0].drive_class_id
                $Level = $recommendations[0].raid_level
                $Strip = $recommendations[0].strip_size
                $StripeWidth = $recommendations[0].stripe_width
                $RebuildAreas = $recommendations[0].rebuild_areas
            }

            $opts = @{
                name  = $Name
                level = $Level
                strip = $Strip
            }

            if ($SlowWritePriority) { $opts['slowwritepriority'] = $SlowWritePriority }
            if ($Encrypt) { $opts['encrypt'] = $Encrypt }

            switch ($PSCmdlet.ParameterSetName) {
                'Array' {
                    $cmd = "mkarray"
                    $opts['drive'] = $Drive
                    if ($PSBoundParameters.ContainsKey('SpareGoal')) { $opts['sparegoal'] = $SpareGoal }
                }
                'DistributedArray' {
                    $cmd = "mkdistributedarray"
                    $opts['driveclass'] = $DriveClass
                    $opts['drivecount'] = $DriveCount
                    if ($PSBoundParameters.ContainsKey('StripeWidth') -or $UseRecommendation) { $opts['stripewidth'] = $StripeWidth }
                    if ($PSBoundParameters.ContainsKey('RebuildAreas') -or $UseRecommendation) { $opts['rebuildareas'] = $RebuildAreas }
                    if ($PSBoundParameters.ContainsKey('RebuildAreasGoal') -or $UseRecommendation) { $opts['rebuildareasgoal'] = $RebuildAreasGoal }
                    if ($AllowSuperior) { $opts['allowsuperior'] = $true }
                }
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd $cmd -CmdOpts $opts -CmdArgs $MDiskGrp
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "MDisk [$($result.id)] '$Name' created successfully."

            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsmdisk" -CmdArgs ($Name)
            if ($current.err) {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            return $current
        }
    }
}
