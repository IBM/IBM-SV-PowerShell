function Invoke-IBMSVPluginRegistration {
    [CmdletBinding()]
    param(
        [object]$Session,

        [string]$Username
    )

    $machineId = $null

    try {
        if ($PSVersionTable.PSVersion.Major -lt 6) {
            $machineId = (Get-ItemProperty `
                    -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography' `
                    -Name MachineGuid `
                    -ErrorAction Stop).MachineGuid

            $machineOS = (Get-CimInstance Win32_OperatingSystem).Caption
        }
        else {
            if ($IsWindows) {
                $machineId = (Get-ItemProperty `
                        -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography' `
                        -Name MachineGuid `
                        -ErrorAction Stop).MachineGuid
            }
            elseif ($IsLinux) {
                if (Test-Path '/etc/machine-id') {
                    $machineId = (Get-Content '/etc/machine-id' -Raw -ErrorAction Stop).Trim()
                }
            }
            elseif ($IsMacOS) {
                $machineId = ioreg -rd1 -c IOPlatformExpertDevice 2>$null |
                    Select-String '"IOPlatformUUID" = "(.+)"' |
                    ForEach-Object { $_.Matches[0].Groups[1].Value }
            }

            $machineOS = $PSVersionTable.OS
        }
    }
    catch {
        Write-IBMSVLog -Level DEBUG -Message "Failed to obtain machine identifier: $($_.Exception.Message)"
    }

    if ([string]::IsNullOrWhiteSpace($machineId)) {
        Write-IBMSVLog -Level DEBUG -Message "Machine identifier unavailable. Using hostname."
        $machineId = [System.Net.Dns]::GetHostName()
    }

    if ([string]::IsNullOrWhiteSpace($machineOS)) {
        $machineOS = "Unknown OS"
    }

    $uniqueKey = "$Username`_$machineId"
    $ModuleVersion = (Get-Module -Name IBMStorageVirtualize).Version.ToString()

    $body = @{
        name      = "PowerShell"
        uniquekey = $uniqueKey
        version   = $ModuleVersion
        metadata  = "PowerShell Toolkit used on $machineOS by $Username"
    }

    try {
        $result = Set-CertPolicy -ValidateCerts $Session.ValidateCerts
        if ($result.err) { return $result }

        $HostName = if ($Session.domain) { "$($Session.cluster).$($Session.domain)" } else { $Session.cluster }
        Invoke-RestMethod -Uri "https://${HostName}:7443/rest/v1/registerplugin" `
            -Method POST `
            -Headers @{
                "Content-Type" = "application/json"
                "X-Auth-Token" = $Session.token
            } `
            -Body ($body | ConvertTo-Json -Depth 5) | Out-Null

        Write-IBMSVLog -Level DEBUG -Message "Plugin registered successfully."
    }
    catch {
        Write-IBMSVLog -Level ERROR -Message "Plugin registered failed: $($_.Exception.Message)"
    }
}
