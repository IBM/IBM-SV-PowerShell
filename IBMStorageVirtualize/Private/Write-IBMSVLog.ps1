function Write-IBMSVLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ERROR', 'WARN', 'INFO', 'DEBUG')]
        [string]$Level,

        [Parameter(Mandatory)]
        [object]$Message,

        [switch]$HostMsg,

        [string]$CallerName
    )

    if ($Message -is [string]) {
        $text = $Message
    }
    elseif ($Message -is [System.Exception]) {
        $text = $Message.Message
        if ($Message.StackTrace) {
            $text += "`n$($Message.StackTrace)"
        }
    }
    elseif ($Message -is [System.Management.Automation.ErrorRecord]) {
        $text = $Message.Exception.Message
        if ($Message.ScriptStackTrace) {
            $text += "`n$($Message.ScriptStackTrace)"
        }
    }
    else {
        try {
            $text = $Message | ConvertTo-Json -Depth 10 -Compress
        }
        catch {
            $text = $Message | Out-String
        }
    }

    if ($HostMsg) {
        Write-Information $text -InformationAction Continue
    }
    else {
        switch ($Level) {
            'WARN' { Write-Warning $text }
            'INFO' { Write-Verbose $text }
        }
    }

    $logLevels = @{
        'ERROR' = 0
        'WARN'  = 1
        'INFO'  = 2
        'DEBUG' = 3
    }

    $configuredLevel = $script:LoggerConfig.Level
    if ($logLevels[$Level] -gt $logLevels[$configuredLevel]) {
        return
    }

    try {
        if ($script:LoggerConfig.MaxLogSizeMB -gt 0) {
            $logFile = $script:LoggerConfig.LogFile
            if (Test-Path $logFile) {
                $logFileInfo = Get-Item $logFile
                $logSizeMB = $logFileInfo.Length / 1MB

                if ($logSizeMB -ge $script:LoggerConfig.MaxLogSizeMB) {
                    $rotationTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                    $logDir = Split-Path $logFile -Parent
                    $logName = [System.IO.Path]::GetFileNameWithoutExtension($logFile)
                    $logExt = [System.IO.Path]::GetExtension($logFile)
                    $archiveName = "${logName}_${rotationTimestamp}${logExt}"
                    $archivePath = Join-Path $logDir $archiveName

                    Move-Item -Path $logFile -Destination $archivePath -Force

                    $rotationNotice = "$(Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fff") [INFO ] PID=$PID TID=$([System.Threading.Thread]::CurrentThread.ManagedThreadId) [LogRotation] " +
                                     "Previous log file reached size limit ($([math]::Round($logSizeMB, 2)) MB) and was archived as: $archiveName"
                    [System.IO.File]::AppendAllText(
                        $logFile,
                        $rotationNotice + [System.Environment]::NewLine
                    )

                    if ($script:LoggerConfig.MaxArchiveFiles -gt 0) {
                        $archives = Get-ChildItem -Path $logDir -Filter "${logName}_*${logExt}" |
                                    Sort-Object LastWriteTime -Descending |
                                    Select-Object -Skip $script:LoggerConfig.MaxArchiveFiles

                        $archives | Remove-Item -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }

        $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fff")
        $prid = "PID=$PID"
        $tid = "TID=$([System.Threading.Thread]::CurrentThread.ManagedThreadId)"

        $caller = if ($CallerName) {
            $CallerName
        }
        elseif ($MyInvocation.PSCommandPath) {
            Split-Path $MyInvocation.PSCommandPath -Leaf
        }
        else {
            "Interactive"
        }

        $line = "$timestamp [$($Level.PadRight(5))] $prid $tid [$caller] $text"

        $logDir = Split-Path $script:LoggerConfig.LogFile -Parent
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }

        [System.IO.File]::AppendAllText(
            $script:LoggerConfig.LogFile,
            $line + [System.Environment]::NewLine
        )
    }
    catch {
        Write-Warning "Failed to write to log file: $_"
        Write-Warning "Log message: $text"
    }
}
