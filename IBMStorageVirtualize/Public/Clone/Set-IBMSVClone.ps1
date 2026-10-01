<#
.SYNOPSIS
Converts a thinclone volume or volumegroup to clone on an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVClone cmdlet converts an existing thinclone volume or volumegroup to a clone.

.PARAMETER Type
Specifies the type to convert to.
Must be 'clone' to convert a thinclone to clone.
Required parameter.

.PARAMETER Volumes
Specifies the name or colon/comma-separated list of volume names to convert from thinclone to clone.
Multiple volumes can be specified as an array or colon-separated string.
Mutually exclusive with -VolumeGroup.

.PARAMETER VolumeGroup
Specifies the name of the volumegroup to convert from thinclone to clone.
Mutually exclusive with -Volumes.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Set-IBMSVClone -Type clone -Volumes pwsh_vol_thinclone
Converts a single thinclone volume to clone.

.EXAMPLE
PS> Set-IBMSVClone -Type clone -Volumes vol1,vol2,vol3
PS> Set-IBMSVClone -Type clone -Volumes "vol1:vol2:vol3"
Converts multiple thinclone volumes to clone.

.EXAMPLE
PS> Set-IBMSVClone -Type clone -VolumeGroup pwsh_vg_thinclone
Converts a thinclone volumegroup to clone.

.INPUTS
System.String
You can pipe objects with a Volumes or VolumeGroup property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Supports both volume and volumegroup thinclone to clone conversion.
- Conversion from thinclone to clone is irreversible.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/converttoclone
#>

function Set-IBMSVClone {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateSet("clone")]
        [string]$Type,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Volumes,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$VolumeGroup,

        [string]$Cluster
    )

    process {
        if ($Volumes -and $VolumeGroup) {
            throw (Resolve-Error -ErrorInput "Parameters -Volumes and -VolumeGroup are mutually exclusive." -Category InvalidArgument)
        }

        if (-not $Volumes -and -not $VolumeGroup) {
            throw (Resolve-Error -ErrorInput "Either -Volumes or -VolumeGroup parameter must be specified." -Category InvalidArgument)
        }

        if ($VolumeGroup) {
            $vgInfo = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvolumegroup" -CmdArgs @($VolumeGroup)
            if ($vgInfo -and $vgInfo.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $vgInfo -Category InvalidOperation)
            }

            if (-not $vgInfo) {
                throw (Resolve-Error -ErrorInput "VolumeGroup '$VolumeGroup' does not exist." -Category ObjectNotFound)
            }

            if ($vgInfo.volume_group_type -ne "thinclone") {
                Write-IBMSVLog -Level INFO -Message "VolumeGroup '$VolumeGroup' is already in desired state."
                return
            }

            if ($PSCmdlet.ShouldProcess("VolumeGroup '$VolumeGroup'", "Convert from thinclone to clone")) {
                $opts = @{
                    volumegroup = $VolumeGroup
                }

                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "converttoclone" -CmdOpts $opts
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }

                Write-IBMSVLog -Level INFO -Message "VolumeGroup '$VolumeGroup' converted from thinclone to clone successfully."
            }
        }
        else {
            $res = ConvertTo-NormalizedValue -Name 'Volumes' -Value ($Volumes -join ":") -Separator ":"
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $volumesList = $res.out -split ':'

            $allVolumes = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsvdisk"
            if ($allVolumes -and $allVolumes.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $allVolumes -Category InvalidOperation)
            }

            $volumeTypeMap = @{}
            foreach ($vol in $allVolumes) {
                if ($vol -and $vol.name) {
                    $volumeTypeMap[$vol.name] = $vol.volume_type
                }
            }

            $invalidVolumes = @()
            $thincloneVolumes = @()
            $nonThincloneVolumes = @()

            foreach ($volName in $volumesList) {
                if (-not $volumeTypeMap.ContainsKey($volName)) {
                    $invalidVolumes += $volName
                }
                elseif ($volumeTypeMap[$volName] -eq "thinclone") {
                    $thincloneVolumes += $volName
                }
                elseif ($volumeTypeMap[$volName] -eq "clone" -or $volumeTypeMap[$volName] -eq "") {
                    $nonThincloneVolumes += $volName
                }
            }

            if ($invalidVolumes.Count -gt 0) {
                throw (Resolve-Error -ErrorInput "The following volume(s) do not exist: $($invalidVolumes -join ', ')" -Category ObjectNotFound)
            }

            if ($thincloneVolumes.Count -eq 0) {
                Write-IBMSVLog -Level INFO -Message "No thinclone volumes found. All specified volumes are already in desired state."
                return
            }

            if ($nonThincloneVolumes.Count -gt 0) {
                Write-IBMSVLog -Level INFO -Message "The following volume(s) are not thinclone and will be skipped: $($nonThincloneVolumes -join ', ')"
            }

            if ($PSCmdlet.ShouldProcess("Volume(s) '$($thincloneVolumes -join ', ')'", "Convert from thinclone to clone")) {
                $opts = @{
                    volumes = $thincloneVolumes -join ':'
                }

                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "converttoclone" -CmdOpts $opts
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }

                Write-IBMSVLog -Level INFO -Message "Volume(s) $($thincloneVolumes -join ', ') converted from thinclone to clone successfully."
            }
        }
    }
}
