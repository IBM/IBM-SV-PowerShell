<#
.SYNOPSIS
Creates a clone of a volume or volumegroup on an IBM Storage Virtualize system.
The default behaviour is to create a volumegroup clone if FromSourceVolumes is not specified.

.DESCRIPTION
The New-IBMSVClone cmdlet creates a clone or thinclone of a volume or volumegroup on an IBM Storage Virtualize system.
The clone is created from an existing snapshot.

.PARAMETER Name
Specifies the name of the clone to create.

.PARAMETER Type
Specifies the type of clone to create.
Valid values: clone, thinclone.
Required for creating a clone.

.PARAMETER Snapshot
Specifies the name of the snapshot that is used to create the clone.
Required for creating a clone.

.PARAMETER Pool
Specifies the name of the storage pool(mdiskgrp) to use while creating the clone.
Required for volume clones.
Optional for volumegroup clones.

.PARAMETER IOGrp
Specifies the name of the I/O group for the new clone.

.PARAMETER VolumeGroup
Specifies the name of the volumegroup to which the volume clone is to be added.
Valid only for volume clones.
When logging in via partition IP, this parameter is required to create a volume clone.

.PARAMETER FromSourceVolumes
Specifies colon/comma separated list of the parent volumes name.
Required for volume clones.
Optional for volumegroup clones.

.PARAMETER PreferredNode
Specifies the preferred node that is used to access the volume.
Valid only for volume clones.

.PARAMETER Partition
Specifies the name of the storage partition to be assigned to the volumegroup.
Valid only for volumegroup clones.
Mutually exclusive with -DraftPartition.

.PARAMETER DraftPartition
Specifies the draftpartition for the volumegroup.
Valid only for volumegroup clones.
Mutually exclusive with -Partition.

.PARAMETER OwnershipGroup
Specifies the name of the ownership group to which the object is being added.
Valid only for volumegroup clones.

.PARAMETER IgnoreUserFCMaps
Specifies that snapshots can be created with the scheduler or with the addsnapshot command,
if any volumes in the volume group are used as a source volume in legacy FlashCopy mapping.
Valid only for volumegroup clones.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> New-IBMSVClone -Name vol1_clone_1 -Type clone -Snapshot snapshot1 -FromSourceVolumes vol1 -Pool pool1
Creates a clone of a volume from snapshot.

.EXAMPLE
PS> New-IBMSVClone -Name vol1_thinclone_1 -Type thinclone -Snapshot snapshot1 -FromSourceVolumes vol1 -Pool pool1
Creates a thinclone of a volume from snapshot.

.EXAMPLE
PS> New-IBMSVClone -Name vg1_clone_1 -Type clone -Snapshot snapshot1 -Pool pool1 -IOGrp io_grp0 -Partition ptn1 -OwnershipGroup grp1
Creates a clone of a volumegroup from snapshot.

.EXAMPLE
PS> New-IBMSVClone -Name vg1_clone_1 -Type clone -Snapshot snapshot1 -Pool pool1 -IOGrp io_grp0 -DraftPartition draft_ptn1
Creates a clone of a volumegroup with draft partition.

.EXAMPLE
PS> New-IBMSVClone -Name vg1_clone_1 -Type clone -Snapshot snapshot1 -FromSourceVolumes vol1,vol2,vol3 -Pool pool1
PS> New-IBMSVClone -Name vg1_clone_1 -Type clone -Snapshot snapshot1 -FromSourceVolumes "vol1:vol2:vol3" -Pool pool1
Creates a clone of volume vector from snapshot.

.EXAMPLE
PS> New-IBMSVClone -Name vg1_thinclone_1 -Type thinclone -Snapshot snapshot1
Creates a thinclone of a volumegroup from snapshot.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
System.Object
Returns the created clone, or the existing clone if it already exists.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Supports both volume and volumegroup clone creation.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkvolume
https://www.ibm.com/docs/en/search/mkvolumegroup
#>

function New-IBMSVClone {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet("clone", "thinclone")]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Snapshot,

        [string]$Pool,

        [string]$IOGrp,

        [string]$VolumeGroup,

        [string[]]$FromSourceVolumes,

        [string]$PreferredNode,

        [string]$Partition,

        [string]$DraftPartition,

        [string]$OwnershipGroup,

        [switch]$IgnoreUserFCMaps,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        $validated = @{}

        if ($Partition -and $DraftPartition) {
            throw (Resolve-Error -ErrorInput "Parameters -Partition and -DraftPartition are mutually exclusive." -Category InvalidArgument)
        }

        if ($PreferredNode -and (-not $IOGrp -or ($IOGrp -split ':').Count -ne 1)) {
            throw (Resolve-Error -ErrorInput "Parameter -PreferredNode is only valid with a single iogrp." -Category InvalidArgument)
        }

        # Determine object type based on FromSourceVolumes
        $objectType = $null
        if ($FromSourceVolumes) {
            $res = ConvertTo-NormalizedValue -Name 'FromSourceVolumes' -Value ($FromSourceVolumes -join ":") -Separator ":"
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $validated.FromSourceVolumes = $res.out

            $sourceVolumesList = $validated.FromSourceVolumes -split ':'
            if ($sourceVolumesList.Count -eq 1) {
                $objectType = 'volume'
            }
            else {
                $objectType = 'volumegroup'
            }
        }
        else {
            # If FromSourceVolumes not specified, default behaviour
            $objectType = 'volumegroup'
        }

        if ($objectType -eq 'volume') {
            $invalidForVolume = @()
            if ($PSBoundParameters.ContainsKey('Partition')) { $invalidForVolume += '-Partition' }
            if ($PSBoundParameters.ContainsKey('DraftPartition')) { $invalidForVolume += '-DraftPartition' }
            if ($PSBoundParameters.ContainsKey('OwnershipGroup')) { $invalidForVolume += '-OwnershipGroup' }
            if ($PSBoundParameters.ContainsKey('IgnoreUserFCMaps')) { $invalidForVolume += '-IgnoreUserFCMaps' }

            if ($invalidForVolume.Count -gt 0) {
                throw (Resolve-Error -ErrorInput "Volume clone operation does not support the parameter(s): $($invalidForVolume -join ', ')." -Category InvalidArgument)
            }

            if (-not $Pool) {
                throw (Resolve-Error -ErrorInput "Parameter -Pool is required for volume clone creation." -Category InvalidArgument)
            }
        }
        else {
            $invalidForVolumeGroup = @()
            if ($PSBoundParameters.ContainsKey('VolumeGroup')) { $invalidForVolumeGroup += '-VolumeGroup' }
            if ($PSBoundParameters.ContainsKey('PreferredNode')) { $invalidForVolumeGroup += '-PreferredNode' }

            if ($invalidForVolumeGroup.Count -gt 0) {
                throw (Resolve-Error -ErrorInput "Volumegroup clone operation does not support the parameter(s): $($invalidForVolumeGroup -join ', ')." -Category InvalidArgument)
            }
        }

        # --- Create Clone ---
        if ($PSCmdlet.ShouldProcess("Clone '$Name' (Type: $objectType)", "Create")) {

            # --- Clone Existence check ---
            $cmd = if ($objectType -eq 'volume') { "lsvdisk" } else { "lsvolumegroup" }            
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd $cmd -CmdArgs ($Name)
            if ($existing) {
                if ($existing.PSObject.Properties.Name -contains "err") {
                    throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
                }
                Write-IBMSVLog -Level INFO -Message "Clone '$Name' already exists. Returning existing object."
                return $existing
            }

            # --- Snapshot Existence check ---
            if ($objectType -eq 'volume') {
                $snapshotOpts = @{
                    filtervalue = "snapshot_name=$Snapshot"
                }
                $cmd = 'lsvolumesnapshot'
            }
            else {
                $snapshotOpts = @{
                    filtervalue = "name=$Snapshot"
                }
                $cmd = 'lsvolumegroupsnapshot'
            }

            $snapshotData = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd $cmd -CmdOpts $snapshotOpts
            if (-not $snapshotData) {
                throw (Resolve-Error -ErrorInput "Snapshot '$Snapshot' does not exist." -Category InvalidOperation)
            }
            if ($snapshotData.PSObject.Properties.Name -contains 'err') {
                throw (Resolve-Error -ErrorInput $snapshotData -Category InvalidOperation)
            }

            $sourceGroupName = $snapshotData[0].volume_group_name
            $parentUid = $snapshotData[0].parent_uid

            #--- Build command options---
            $opts = @{
                name     = $Name
                type     = $Type
                snapshot = $Snapshot
            }

            if ($sourceGroupName) {
                $opts['fromsourcegroup'] = $sourceGroupName
            }
            else {
                $opts['fromsourceuid'] = $parentUid
            }

            if ($objectType -eq 'volume') {
                $opts['fromsourcevolume'] = $validated.FromSourceVolumes

                $parameterList = @('Pool', 'IOGrp', 'VolumeGroup', 'PreferredNode')
            }
            else {
                if ($validated.FromSourceVolumes) {
                    $opts['fromsourcevolumes'] = $validated.FromSourceVolumes
                }

                # For volumegroup, IOGrp maps to 'iogroup'
                if ($IOGrp) {
                    $opts['iogroup'] = $IOGrp
                }

                $parameterList = @('Pool', 'Partition', 'DraftPartition', 'OwnershipGroup', 'IgnoreUserFCMaps')
            }
            foreach ($field in $parameterList) {
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

            # --- Create the clone ---
            $cmd = if ($objectType -eq 'volume') { 'mkvolume' } else { 'mkvolumegroup' }
            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd $cmd -CmdOpts $opts
            if ($result.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Clone [$($result.id)] '$Name' created successfully."
            
            $cmd = if ($objectType -eq 'volume') { 'lsvdisk' } else { 'lsvolumegroup' }
            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd $cmd -CmdArgs ($Name)
            if ($current.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            return $current
        }
    }
}
