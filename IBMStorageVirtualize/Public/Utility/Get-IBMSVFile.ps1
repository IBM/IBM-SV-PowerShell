<#
.SYNOPSIS
Downloads a file from an IBM Storage Virtualize system to the local machine.

.DESCRIPTION
The Get-IBMSVFile cmdlet downloads a file from a directory on an IBM Storage Virtualize
system (such as /dumps) to a specified local path.

Output path resolution:
If parameter OutFilePath is not specified, file is saved to the current working directory using the original filename.
If an existing directory is specified as OutFilePath, file is saved into that directory using the original filename.
If an absolute file path is specified as OutFilePath, file is saved at the exact path specified.

.PARAMETER Prefix
Specifies the directory on the storage system where the file resides.

.PARAMETER Filename
Specifies the name of the file to be downloaded from the storage system.

.PARAMETER OutFilePath
Specifies the local directory or full file path where the downloaded file should be saved.
If a directory is specified, the file is saved with its original name inside that directory.
If not specified, the file is saved to the current working directory.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Get-IBMSVFile -Prefix "/dumps" -Filename "ip_quorum.jar"
Downloads ip_quorum.jar from /dumps to the current working directory.

.EXAMPLE
PS> Get-IBMSVFile -Prefix "/dumps/iostats" -Filename "Nh_stats_78G00F3-1_121212_121212" -OutFilePath "C:\test"
Downloads Nh_stats_78G00F3-1_121212_121212 into the C:\test directory.

.EXAMPLE
PS> Get-IBMSVFile -Prefix "/dumps" -Filename "ip_quorum.jar" -OutFilePath "C:\quorum\myquorum.jar"
Downloads ip_quorum.jar and saves it as C:\quorum\myquorum.jar.

.INPUTS
System.String
You can pipe prefix and filename to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- The parent directory of the target path must exist when specifying a full file path.
- Supports -WhatIf and -Confirm.
#>

function Get-IBMSVFile {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Prefix,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Filename,

        [string]$OutFilePath,

        [string]$Cluster
    )

    process {
        $resolvedPath = $null
        if (-not $OutFilePath) {
            $resolvedPath = Join-Path -Path $PWD.Path -ChildPath $Filename
        }
        elseif (Test-Path -LiteralPath $OutFilePath -PathType Container) {
            $resolvedPath = Join-Path -Path $OutFilePath -ChildPath $Filename
        }
        else {
            $parentDir = [System.IO.Path]::GetDirectoryName($OutFilePath)
            if ($parentDir -and -not (Test-Path -LiteralPath $parentDir -PathType Container)) {
                throw (Resolve-Error -ErrorInput "Parent directory '$parentDir' does not exist." -Category InvalidArgument)
            }
            $resolvedPath = $OutFilePath
        }

        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($resolvedPath)

        if ($PSCmdlet.ShouldProcess("File: $Filename ($Prefix)", "Download to: $resolvedPath")) {
            Write-IBMSVLog -Level DEBUG -Message "Downloading file '$Filename' from prefix '$Prefix' to '$resolvedPath'."

            $opts = @{
                prefix   = $Prefix
                filename = $Filename
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "download" -CmdOpts $opts -OutFile $resolvedPath
            if ($result -and $result.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }

            Write-IBMSVLog -Level INFO -Message "File downloaded successfully to: $resolvedPath"
        }
    }
}
