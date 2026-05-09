<#
.SYNOPSIS
Creates a new volume in an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVVolume cmdlet creates a volume in an IBM Storage Virtualize system.

It maps to the mkvolume command.

The cmdlet is idempotent:
- If a volume with the specified name already exists, the existing object is returned.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER Name
Specifies the name of the volume to create.

.PARAMETER Size
Specifies the size of the volume.

The value is interpreted using the unit specified by -Unit.

.PARAMETER Unit
Specifies the unit for -Size.
Valid values: b, kb, mb, gb, tb, pb.

.PARAMETER Pool
Specifies the storage pool (MDisk group) where the volume is created.

.PARAMETER Cache
Specifies the cache mode for the volume.
Valid values: none, readonly, readwrite.

.PARAMETER Thin
Specifies that the volume is thin-provisioned.

Mutually exclusive with -Compressed.

.PARAMETER Compressed
Specifies that the volume is compressed.

Mutually exclusive with -Thin.

.PARAMETER Deduplicated
Specifies that the volume is deduplicated.

Valid only when -Thin or -Compressed is specified.

.PARAMETER BufferSize
Specifies the buffer size for thin or compressed volumes.

Valid only when -Thin or -Compressed is specified.

.PARAMETER Warning
Specifies the warning threshold for used capacity.

Valid only for thin or compressed volumes.

.PARAMETER NoAutoExpand
Specifies that automatic expansion is disabled.

Valid only when -Thin or -Compressed is specified.

.PARAMETER Grainsize
Specifies the grain size for thin-provisioned volumes.
Valid values: 32, 64, 128, 256.

Valid only when -Thin is specified.

.PARAMETER Udid
Specifies the user-defined identifier (UDID) for the volume.

.PARAMETER IOGrp
Specifies one or more I/O groups that can access the volume.

Multiple values are passed as a colon-separated list.

.PARAMETER PreferredNode
Specifies the preferred node for the volume.

Valid only when a single I/O group is specified.

.PARAMETER VolumeGroup
Specifies the volume group to which the volume belongs.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> New-IBMSVVolume -Name Vol1 -Size 100 -Unit gb -Pool Pool1

Creates a standard volume.

.EXAMPLE
PS> New-IBMSVVolume -Name ThinVol1 -Size 500 -Unit gb -Pool Pool1 -Thin

Creates a thin-provisioned volume.

.EXAMPLE
PS> New-IBMSVVolume -Name CompVol1 -Size 1 -Unit tb -Pool Pool1 -Compressed -Deduplicated

Creates a compressed and deduplicated volume.

.EXAMPLE
PS> New-IBMSVVolume -Name ThinVol2 -Size 200 -Unit gb -Pool Pool1 -Thin -Warning 70% -NoAutoExpand

Creates a thin-provisioned volume with warning threshold.

.EXAMPLE
PS> New-IBMSVVolume -Name VolIOGrp -Size 50 -Unit gb -Pool Pool1 -IOGrp 0 -PreferredNode 1

Creates a volume with a preferred node.

.INPUTS
System.String

You can pipe name, size and pool to this cmdlet.

.OUTPUTS
System.Object

Returns the created volume object.

If the volume already exists, the existing object is returned.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Performs validation of parameter combinations before execution.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkvolume
#>

function New-IBMSVVolume {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [int64]$Size,

        [ValidateSet("b", "kb", "mb", "gb", "tb", "pb")]
        [string]$Unit,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Pool,

        [ValidateSet("none", "readonly", "readwrite")]
        [string]$Cache,

        [switch]$Thin,

        [switch]$Compressed,

        [switch]$Deduplicated,

        [string]$BufferSize,

        [string]$Warning,

        [switch]$NoAutoExpand,

        [ValidateSet(32, 64, 128, 256)]
        [int]$Grainsize,

        [string]$Udid,

        [string[]]$IOGrp,

        [string]$PreferredNode,

        [string]$VolumeGroup,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        $validated = @{}
        if ($Grainsize -and -not $Thin) {
            throw (Resolve-Error -ErrorInput "Parameter -Grainsize is invalid without -Thin." -Category InvalidArgument)
        }
        if ($PreferredNode -and (-not $IOGrp -or ($IOGrp -split ':').Count -ne 1)) {
            throw (Resolve-Error -ErrorInput "Parameter -PreferredNode is only valid with a single iogrp." -Category InvalidArgument)
        }
        if (-not ($Thin -or $Compressed)) {
            $invalidParams = @()
            if ($BufferSize) { $invalidParams += '-BufferSize' }
            if ($Warning) { $invalidParams += '-Warning' }
            if ($Deduplicated) { $invalidParams += '-Deduplicated' }
            if ($NoAutoExpand) { $invalidParams += '-NoAutoExpand' }
            if ($invalidParams.Count -gt 0) {
                throw (Resolve-Error -ErrorInput "The parameter(s) $($invalidParams -join ', ') can only be used when one of -Thin or -Compressed is specified." -Category InvalidArgument)
            }
        }

        if ($Thin -and $Compressed) {
            throw (Resolve-Error -ErrorInput "Parameters -Thin and -Compressed are mutually exclusive." -Category InvalidArgument)
        }

        if ($IOGrp) {
            $res = ConvertTo-NormalizedValue -Name 'IOGrp' -Value ($IOGrp -join ":") -Separator ":"
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $validated.IOGrp = $res.out
        }

        # --- Create Volume ---
        if ($PSCmdlet.ShouldProcess("Volume '$Name'", "Create")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvdisk" -CmdArgs ($Name)
            if ($existing) {
                if ($existing.PSObject.Properties.Name -contains "err") {
                    throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
                }
                Write-IBMSVLog -Level INFO -Message "Volume '$Name' already exists. Returning existing object."
                return $existing
            }

            $opts = @{ name = $Name; pool = $Pool; size = $Size }
            foreach ($param in $validated.keys) {
                $opts[$param.ToLower()] = $validated[$param]
            }
            foreach ($field in @('Unit', 'Cache', 'Thin', 'Compressed', 'Deduplicated', 'BufferSize', 'Warning', 'NoAutoExpand', 'Grainsize', 'Udid', 'PreferredNode', 'VolumeGroup')) {
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

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "mkvolume" -CmdOpts $opts
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Volume [$($result.id)] '$Name' created successfully."

            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvdisk" -CmdArgs ($Name)
            if ($current -and $current.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            return $current
        }
    }
}
