$Script:primarysession = $null
$Script:sessions = @{}
$Script:LoggerConfig = @{
    Level           = 'INFO'
    LogFile         = Join-Path -Path $PWD -ChildPath 'IBMSV_powershell.log'
    MaxLogSizeMB    = 10
    MaxArchiveFiles = 5
}

$PublicFunctions = @()

$PrivatePath = Join-Path $PSScriptRoot "Private"
if (Test-Path $PrivatePath) {
    Get-ChildItem -Path $PrivatePath -Filter *.ps1 | ForEach-Object {
        . $_.FullName
    }
}

$PublicPath = Join-Path $PSScriptRoot "Public"
if (Test-Path $PublicPath) {
    Get-ChildItem -Path $PublicPath -Recurse -Filter *.ps1 | ForEach-Object {
        . $_.FullName
        $PublicFunctions += $_.BaseName
    }
}
Export-ModuleMember -Function $PublicFunctions
