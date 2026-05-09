function Resolve-Error {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)]
        [object]$ErrorInput,

        [System.Management.Automation.ErrorCategory]$Category = [System.Management.Automation.ErrorCategory]::NotSpecified,

        [object]$TargetObject
    )

    $Message = $null
    $Result = $null

    if ($ErrorInput -is [string]) {
        $Message = $ErrorInput
    }
    elseif ($ErrorInput -and $ErrorInput.PSObject.Properties.Count -gt 0) {

        $props = $ErrorInput.PSObject.Properties | Where-Object MemberType -eq NoteProperty
        if ($props.Count -eq 1) {
            $Message = $props[0].Value
        }
        else {
            $Result = $ErrorInput
        }
    }

    if (-not $TargetObject) {
        if (-not $TargetObject) {
            if ($Result) {
                $TargetObject = $Result
            }
            elseif ($Message) {
                $TargetObject = $Message
            }
        }
    }

    if (-not $Message) {
        if ($Result) {
            $Message = "REST call failed (HTTP $($Result.code)) to $($Result.url)"
        }
        else {
            $Message = "Operation failed."
        }
    }

    if ($MyInvocation.PSCommandPath) {
        $caller = Split-Path $MyInvocation.PSCommandPath -Leaf
    }
    elseif ($MyInvocation.MyCommand.Name) {
        $caller = $MyInvocation.MyCommand.Name
    }
    else {
        $caller = "Interactive"
    }

    if ($Result) {
        Write-IBMSVLog -Level ERROR -Message $Result -Caller $caller
    }
    else {
        Write-IBMSVLog -Level ERROR -Message $Message -Caller $caller
    }

    $exception = switch ($Category) {
        'InvalidArgument' { [System.ArgumentException]::new($Message) }
        'InvalidOperation' { [System.InvalidOperationException]::new($Message) }
        'ResourceExists' { [System.InvalidOperationException]::new($Message) }
        'ObjectNotFound' { [System.Management.Automation.ItemNotFoundException]::new($Message) }
        'NotImplemented' { [System.NotImplementedException]::new($Message) }
        'ConnectionError' { [System.InvalidOperationException]::new($Message) }
        'AuthenticationError' { [System.UnauthorizedAccessException]::new($Message) }
        default { [System.Exception]::new($Message) }
    }

    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        $exception,
        "IBMSV.Error",
        $Category,
        $TargetObject
    )

    if ($Result) {
        $lines = @()
        if ($Result.url) { $lines += "url  : $($Result.url)" }
        if ($Result.code) { $lines += "code : $($Result.code)" }
        if ($Result.err) { $lines += "err  : $($Result.err)" }
        if ($Result.out) { $lines += "out  : $($Result.out)" }

        if ($Result.data) {
            try {
                $prettyData = if ($Result.data -is [string]) {
                    ($Result.data | ConvertFrom-Json | ConvertTo-Json -Depth 10)
                }
                else {
                    ($Result.data | ConvertTo-Json -Depth 10)
                }
                $lines += "data : $prettyData"
            }
            catch {
                $lines += "data : $($Result.data)"
            }
        }

        if ($lines.Count -gt 0) {
            $details = $lines -join [Environment]::NewLine
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($details)
        }
    }

    return $errorRecord
}
