function Invoke-IBMSVPluginRegistration {
    [CmdletBinding()]
    param(
        [hashtable]$Session,

        [string]$Username
    )

    $machineOS = $PSVersionTable.OS
    $machineId = $null

    if ($machineOS -match 'Darwin') {
        $machineId = ioreg -rd1 -c IOPlatformExpertDevice 2>$null |
            Select-String '"IOPlatformUUID" = "(.+)"' |
            ForEach-Object { $_.Matches[0].Groups[1].Value }
    }
    elseif ($machineOS -match 'Linux') {
        if (Test-Path "/etc/machine-id") {
            $machineId = (Get-Content "/etc/machine-id").Trim()
        }
    }
    elseif ($machineOS -match 'Windows') {
        try {
            $machineId = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography").MachineGuid
        }
        catch {
            Write-IBMSVLog -Level DEBUG -Message "Failed to read MachineGuid from registry: $($_.Exception.Message)"
        }
    }

    if (-not $machineId) {
        $machineId = [guid]::NewGuid().ToString()
    }

    $uniqueKey = "$Username`_$machineId"
    $ModuleVersion = (Get-Module -Name IBMStorageVirtualize).Version.ToString()

    $HostName = if ($Session.domain) { "$($Session.cluster).$($Session.domain)" } else { $Session.cluster }
    $body = @{
        name      = "PowerShell"
        uniquekey = $uniqueKey
        version   = $ModuleVersion
        metadata  = "PowerShell Toolkit used $machineOS by $Username"
    } | ConvertTo-Json -Depth 5

    try {
        $result = Set-CertPolicy -ValidateCerts $Session.ValidateCerts
        if ($result.err) { return $result }

        Invoke-RestMethod -Uri "https://${HostName}:7443/rest/v1/registerplugin" `
            -Method POST `
            -Headers @{
                "Content-Type" = "application/json"
                "X-Auth-Token" = $Session.token
            } `
            -Body $body | Out-Null

        Write-IBMSVLog -Level DEBUG -Message "Plugin registered successfully."
    }
    catch {
        Write-IBMSVLog -Level ERROR -Message "Plugin registered failed: $($_.Exception.Message)"
    }
}
