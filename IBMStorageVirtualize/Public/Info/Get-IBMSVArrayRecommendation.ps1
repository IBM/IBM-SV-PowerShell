<#
.SYNOPSIS
Returns array layout recommendations for a distributed array.

.DESCRIPTION
The Get-IBMSVArrayRecommendation cmdlet queries the system using the
lsarrayrecommendation command and returns recommended array layouts
based on the specified drive class, drive count, and MDisk group.

The cmdlet validates that:
- Candidate drives exist for the specified drive class
- The requested drive count is within valid range (2 to available drives)
- The MDisk group exists

.PARAMETER MDiskGrp
Specifies the MDisk group for which to retrieve recommendations.

.PARAMETER DriveClass
Specifies the drive class ID.

Default: 0.

.PARAMETER DriveCount
Specifies the number of drives to consider.

If not specified, all available candidate drives of the specified class are used.
Must be between 2 and the number of available candidate drives.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Get-IBMSVArrayRecommendation -MDiskGrp mdiskgrp0 -DriveClass 1 -DriveCount 12

Returns recommended array layouts for a 12-drive distributed array in mdiskgrp0.

.EXAMPLE
PS> Get-IBMSVArrayRecommendation -MDiskGrp Pool1

Returns recommendations using available drives.

.INPUTS
None.

.OUTPUTS
System.Object[]

Returns recommended array layouts.

If no recommendations are available, an empty array is returned.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Returns an empty array if no recommendations are available or validation fails.

.LINK
https://www.ibm.com/docs/en/search/lsarrayrecommendation
#>

function Get-IBMSVArrayRecommendation {
    [CmdletBinding()]
    [OutputType([hashtable], [object[]])]
    param(
        [Parameter(Mandatory)][string]$MDiskGrp,

        [int]$DriveClass = 0,

        [int]$DriveCount,

        [string]$Cluster
    )

    $driveInfo = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsdrive" -CmdOpts @{ filtervalue = "use=candidate:drive_class_id=$DriveClass" }
    if ($driveInfo -and $driveInfo.PSObject.Properties.Name -contains "err") {
        throw (Resolve-Error -ErrorInput $driveInfo -Category InvalidOperation)
    }

    if (-not $driveInfo -or $driveInfo.Count -eq 0) {
        $msg = "No candidate drives found for DriveClass '$DriveClass'. Cannot create or recommend an array."
        Write-IBMSVLog -Level INFO -Message $msg
        return @()
    }

    $driveCnt = if ($DriveCount) {
        if ($DriveCount -lt 2 -or $DriveCount -gt $driveInfo.Count) {
            if ($driveInfo.Count -lt 2) {
                $msg = "Invalid DriveCount specified for recommendation. Only $($driveInfo.Count) candidate drive(s) available."
            }
            else {
                $msg = "Invalid DriveCount specified for recommendation. Must be between 2 and $($driveInfo.Count)."
            }
            Write-IBMSVLog -Level INFO -Message $msg
            return @()
        }
        $DriveCount
    }
    else {
        $driveInfo.Count
    }

    $result = Invoke-IBMSVRestRequest -Cmd "lsarrayrecommendation" -CmdOpts @{ driveclass = $DriveClass; drivecount = $driveCnt } -CmdArgs $MDiskGrp -Cluster $Cluster

    if ($result -is [pscustomobject] -and $result.PSObject.Properties.Name -contains "err") {
        if ([string]$result.out -match 'CMMVC\d+E\s+(?<msg>[^,]+)') {
            $errorCode = ($matches[0] -split '\s+')[0]
            $errorMsg = $matches['msg'].Trim()
            Write-IBMSVLog -Level INFO -Message "$errorCode $errorMsg"
            return @()
        }
        else {
            throw (Resolve-Error -ErrorInput "Command 'lsarrayrecommendation' failed with error: $($result.err)" -Category InvalidOperation)
        }
    }

    if (-not $result) {
        Write-IBMSVLog -Level INFO -Message "No array recommendations returned."
        return @()
    }

    if ($result -isnot [System.Collections.IEnumerable] -or $result -is [hashtable] -or $result -is [pscustomobject]) {
        return @($result)
    }

    return @($result)
}
