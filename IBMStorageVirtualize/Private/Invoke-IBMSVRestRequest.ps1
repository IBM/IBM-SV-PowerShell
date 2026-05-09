function Invoke-IBMSVRestRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Cmd,

        [hashtable]$CmdOpts,

        [string[]]$CmdArgs,

        [string]$Cluster,

        [int]$Timeout = 60
    )

    $session = if ($Cluster) {
        if (-not $script:sessions.ContainsKey($Cluster)) {
            return [pscustomobject]@{ err = "No session found for cluster $Cluster." }
        }
        $script:sessions[$Cluster]
    }
    else {
        if (-not $script:primarysession) {
            return [pscustomobject]@{ err = "No primary session found. Specify -Cluster or reconnect using Connect-IBMStorageVirtualize -Primary." }
        }
        $script:sessions[$script:primarysession]
    }

    if (-not $session.Token) {
        return [pscustomobject]@{
            err = "No REST token available. Connect with credentials using Connect-IBMStorageVirtualize."
        }
    }

    $postfix = $Cmd
    if ($CmdArgs) {
        $CmdArgs = $CmdArgs | Where-Object { $_ -and $_.Trim() -ne "" }
        $postfix += "/" + ($CmdArgs -join "/")
    }
    $HostName = if ($session.domain) { "$($session.cluster).$($session.domain)" } else { $session.cluster }
    $url = "https://${HostName}:7443/rest/v1/$postfix"

    $headers = @{
        "Content-Type" = "application/json"
        "X-Auth-Token" = $session.Token
    }

    $payloadJson = if ($CmdOpts) { $CmdOpts | ConvertTo-Json -Depth 10 } else { $null }
    $payloadSafe = if ($CmdOpts) { ConvertTo-SafeObject -InputObject $CmdOpts } else { $null }

    $maxRetries = 3
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        try {
            Write-IBMSVLog -Level DEBUG -Message "Attempt $attempt/$maxRetries : URL=$url"
            if ($payloadSafe) { Write-IBMSVLog -Level DEBUG -Message "Payload: $($payloadSafe | ConvertTo-Json -Depth 10)" }

            $result = Set-CertPolicy -ValidateCerts $session.ValidateCerts
            if ($result.err) { return $result }
            $response = Invoke-RestMethod -Uri $url -Method 'Post' -Headers $headers -Body $payloadJson -TimeoutSec $Timeout

            if ($Cmd -eq "lssystem" -and $response.code_level) {
                $script:sessions[$session.Cluster].SVCVersion = [version]($response.code_level.Split()[0])
            }

            return $response
        }
        catch {
            $status = $null
            $bodyText = $null

            if ($_.Exception.PSObject.Properties.Name -contains 'StatusCode') {
                try {
                    $status = [int]$_.Exception.StatusCode
                }
                catch {
                    Write-IBMSVLog -Level DEBUG -Message "Failed to parse StatusCode: $($_.Exception.Message)"
                }
            }

            if (-not $bodyText -and $_.ErrorDetails -and $_.ErrorDetails.Message) {
                $bodyText = try { $_.ErrorDetails.Message | ConvertFrom-Json } catch { $_.ErrorDetails.Message }
            }

            if (-not $status -and $_.Exception.Response) {
                try {
                    $status = [int]$_.Exception.Response.StatusCode
                    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $raw = $reader.ReadToEnd()
                    if (-not $bodyText) {
                        $bodyText = try { $raw | ConvertFrom-Json } catch { $raw }
                    }
                }
                catch {
                    if (-not $status) { $status = $null }
                    if (-not $bodyText) { $bodyText = $_.Exception.Message }
                }
            }

            if (-not $bodyText) {
                $bodyText = $_.Exception.Message
            }

            $error_codes_to_absorb = ("CMMVC5753E", "CMMVC5754E", "CMMVC5804E", "CMMVC6591E")
            if ($bodyText -match '(CMMVC\d+E)') { $errCode = $matches[1] }
            if (($cmd -like "ls*" -or $cmd -eq "testldapserver") -and ($errCode -in $error_codes_to_absorb)) {
                return $null
            }

            if ($status -eq 429) {
                $delay = [math]::Pow(2, $attempt)
                Write-IBMSVLog -Level WARN -Message "Rate limited (429). Retrying in $delay seconds..."
                Start-Sleep -Seconds $delay
                continue
            }

            if ($status -eq 401) {
                Write-IBMSVLog -Level WARN -Message "Unauthorized (401) — Token expired. Refreshing token..."

                $cred = $null

                if ($session.SecretName) {
                    try {
                        if ($session.VaultName) {
                            $cred = Get-Secret -Name $session.SecretName -Vault $session.VaultName -ErrorAction Stop
                        }
                        else {
                            $cred = Get-Secret -Name $session.SecretName -ErrorAction Stop
                        }
                    }
                    catch {
                        return [pscustomobject]@{ err = "Failed to retrieve secret '$($session.SecretName)'. $_" }
                    }
                }
                elseif ($session.Credential) {
                    $cred = $session.Credential
                }
                else {
                    return [pscustomobject]@{
                        err = "Token expired and no credential available. Reconnect required."
                    }
                }

                try {
                    $result = Set-CertPolicy -ValidateCerts $session.ValidateCerts
                    if ($result.err) { return $result }

                    $authResponse = Invoke-RestMethod -Uri "https://${HostName}:7443/rest/v1/auth" -Method POST -Headers @{
                        "Content-Type"    = "application/json"
                        "X-Auth-Username" = $cred.UserName
                        "X-Auth-Password" = $cred.GetNetworkCredential().Password
                    } -TimeoutSec $Timeout

                    $script:sessions[$session.Cluster].Token = $authResponse.token
                    $script:sessions[$session.Cluster].LastRefreshed = (Get-Date)

                    Write-IBMSVLog -Level INFO -Message "Token refreshed successfully." -HostMsg

                    $headers["X-Auth-Token"] = $authResponse.token

                    $result = Invoke-IBMSVPluginRegistration -Session $script:sessions[$session.Cluster] -Username $session.Credential.Username
                    if ($result.err) { return $result }

                }
                catch {
                    return [pscustomobject]@{
                        err = "Authentication failed during token refresh: $($_.Exception.Message)"
                    }
                }

                continue
            }

            return [pscustomobject]@{
                url  = $url
                code = if ($status) { $status } else { -1 }
                err  = "HTTPError: $($_.Exception.Message)"
                out  = $bodyText
                data = $payloadSafe
            }
        }
    }

    return [pscustomobject]@{
        url  = $url
        code = -1
        err  = "Max retries exceeded for command '$Cmd'."
        out  = $null
        data = $payloadSafe
    }
}
