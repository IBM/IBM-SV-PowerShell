<#
.SYNOPSIS
Configures logging settings for the IBM Storage Virtualize PowerShell module.

.DESCRIPTION
The `Set-IBMSVLogger` cmdlet configures the logging behavior for the
IBM Storage Virtualize PowerShell module. You can set the log level,
log file path, and log rotation settings.

Log levels (from most to least verbose):
- DEBUG: Detailed diagnostic information for troubleshooting
- INFO: General informational messages (Default)
- WARN: Warning messages for potentially harmful situations
- ERROR: Error messages for failures only

Log Rotation:
When MaxLogSizeMB is set, the log file will be automatically rotated when
it reaches the specified size. Old logs are archived with timestamps.

.PARAMETER Level
Specifies the minimum log level to record.
Valid values: DEBUG, INFO, WARN, ERROR
Default: INFO

Messages at or above this level will be logged. For example:
- ERROR: Only errors
- WARN: Warnings and errors
- INFO: Info, warnings, and errors
- DEBUG: All messages

.PARAMETER LogFile
Specifies the path to the log file.
If not provided, logs will be written to the default location.
The directory will be created if it doesn't exist.

.PARAMETER MaxLogSizeMB
Maximum size of the log file in megabytes before rotation occurs.
Set to 0 to disable log rotation.
Default: 10 MB

.PARAMETER MaxArchiveFiles
Maximum number of archived log files to keep.
Older archives are automatically deleted.
Set to 0 to keep all archives.
Default: 5

.PARAMETER ShowConfig
Displays the current logger configuration without making changes.

.EXAMPLE
PS> Set-IBMSVLogger -Level DEBUG

Sets the log level to DEBUG for detailed diagnostic output.

.EXAMPLE
PS> Set-IBMSVLogger -Level ERROR -LogFile "C:\Logs\ibmsv.log"

Sets the log level to ERROR and specifies a log file path.

.EXAMPLE
PS> Set-IBMSVLogger -LogFile "C:\Logs\ibmsv.log" -MaxLogSizeMB 50 -MaxArchiveFiles 10

Updates the log file path and configures rotation at 50MB with 10 archive files.

.EXAMPLE
PS> Set-IBMSVLogger -MaxLogSizeMB 0

Disables log rotation while keeping other settings.

.EXAMPLE
PS> Set-IBMSVLogger -ShowConfig

Displays the current logger configuration.

.INPUTS
None. You cannot pipe input to this cmdlet.

.OUTPUTS
None. This cmdlet does not return output unless -ShowConfig is used.

.NOTES
- Log settings persist for the current PowerShell session only.
- Log rotation happens automatically when the size threshold is reached.
- Archived logs are named with timestamps: LogName_yyyyMMdd_HHmmss.log
#>

function Set-IBMSVLogger {
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Configure')]
    param(
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level,

        [string]$LogFile,

        [ValidateRange(0, 1000)]
        [int]$MaxLogSizeMB,

        [ValidateRange(0, 100)]
        [int]$MaxArchiveFiles,

        [switch]$ShowConfig
    )

    if ($ShowConfig) {
        $config = [PSCustomObject]@{
            Level           = $script:LoggerConfig.Level
            LogFile         = $script:LoggerConfig.LogFile
            MaxLogSizeMB    = $script:LoggerConfig.MaxLogSizeMB
            MaxArchiveFiles = $script:LoggerConfig.MaxArchiveFiles
        }

        Write-Information "`nCurrent Logger Configuration:" -InformationAction Continue
        $config | Format-List

        if (Test-Path $script:LoggerConfig.LogFile) {
            $logInfo = Get-Item $script:LoggerConfig.LogFile
            $sizeMB = [math]::Round($logInfo.Length / 1MB, 2)
            Write-Information "Log File Size: $sizeMB MB" -InformationAction Continue
            Write-Information "Last Modified: $($logInfo.LastWriteTime)" -InformationAction Continue
        }
        else {
            Write-Information "Log file does not exist yet." -InformationAction Continue
        }

        return
    }

    if ($PSCmdlet.ShouldProcess("Logger configuration", "Update")) {
        $changes = @()

        if ($PSBoundParameters.ContainsKey('Level')) {
            $oldLevel = $script:LoggerConfig.Level
            $script:LoggerConfig.Level = $Level
            $changes += "Level: $oldLevel -> $Level"
        }

        if ($PSBoundParameters.ContainsKey('LogFile')) {
            $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogFile)
            $oldLogFile = $script:LoggerConfig.LogFile
            $script:LoggerConfig.LogFile = $resolvedPath
            $changes += "LogFile: $oldLogFile -> $resolvedPath"

            $logDir = Split-Path $resolvedPath -Parent
            if ($logDir -and -not (Test-Path $logDir)) {
                try {
                    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
                    $changes += "Created log directory: $logDir"
                }
                catch {
                    Write-Warning "Failed to create log directory: $_"
                }
            }
        }

        if ($PSBoundParameters.ContainsKey('MaxLogSizeMB')) {
            $oldSize = $script:LoggerConfig.MaxLogSizeMB
            $script:LoggerConfig.MaxLogSizeMB = $MaxLogSizeMB
            $changes += "MaxLogSizeMB: $oldSize -> $MaxLogSizeMB"
        }

        if ($PSBoundParameters.ContainsKey('MaxArchiveFiles')) {
            $oldArchive = $script:LoggerConfig.MaxArchiveFiles
            $script:LoggerConfig.MaxArchiveFiles = $MaxArchiveFiles
            $changes += "MaxArchiveFiles: $oldArchive -> $MaxArchiveFiles"
        }

        if ($changes.Count -gt 0) {
            $changeMessage = "Logger configuration updated: " + ($changes -join "; ")
            Write-IBMSVLog -Level INFO -Message $changeMessage
            Write-Verbose $changeMessage
        }
        elseif ($changes.Count -eq 0) {
            Write-Verbose "No logger configuration changes made."
        }
    }
}
