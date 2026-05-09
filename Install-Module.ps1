$ErrorActionPreference = 'Stop'

$pwshVersion = $PSVersionTable.PSVersion.Major
if ($pwshVersion -lt 5) {
    Write-Error "PowerShell 5.1 or later is required."
    exit 1
}

$ModuleName = "IBMStorageVirtualize"

$Source = Join-Path $PSScriptRoot $ModuleName

if (-not (Test-Path $Source)) {
    Write-Error "Source module folder not found: $Source"
    exit 1
}

$DestinationRoot = $env:PSModulePath -split [System.IO.Path]::PathSeparator

if ($DestinationRoot.Count -eq 0 -or [string]::IsNullOrWhiteSpace($DestinationRoot[0])) {
    Write-Error "PSModulePath is not configured correctly. Cannot determine installation location."
    exit 1
}

if (-not (Test-Path -Path $DestinationRoot[0])) {
    Write-Verbose "Creating module directory: $($DestinationRoot[0])"
    New-Item -ItemType Directory -Path $DestinationRoot[0] -Force | Out-Null
}

$Destination = Join-Path $DestinationRoot[0] $ModuleName

Write-Information "Installing module to: $Destination" -InformationAction Continue

if (Test-Path $Destination) {
    Write-Information "Removing existing module at $Destination" -InformationAction Continue
    Remove-Item -Recurse -Force $Destination
}

Write-Verbose "Copying module files from $Source to $Destination"
Copy-Item -Path $Source -Destination $Destination -Recurse -Force

Get-ChildItem $Destination -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

Try {
    Import-Module $ModuleName -Force -ErrorAction Stop
    Write-Information "Successfully installed and imported $ModuleName." -InformationAction Continue
}
Catch {
    Write-Error "Module copied but failed to import: $($_.Exception.Message)"
    throw
}
