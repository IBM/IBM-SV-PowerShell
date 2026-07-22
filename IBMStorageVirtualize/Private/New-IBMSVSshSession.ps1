function New-IBMSVSshSession {
    [CmdletBinding()]
    param(
        [string]$Cluster
    )

    $session = $script:sessions[$Cluster]
    $cred = $null

    if ($session.SecretName) {
        try {
            $cred = if ($session.VaultName) {
                Get-Secret -Name $session.SecretName -Vault $session.VaultName -ErrorAction Stop
            }
            else {
                Get-Secret -Name $session.SecretName -ErrorAction Stop
            }
        }
        catch {
            return [pscustomobject]@{
                err = "Failed to retrieve secret '$($session.SecretName)'. $_"
            }
        }
    }
    elseif ($session.Credential) {
        $cred = $session.Credential
    }
    else {
        return [pscustomobject]@{ err = "No credential available for '$Cluster'. Reconnect with -AllowCredentialCaching or -SecretName." }
    }

    try {
        $sshParams = @{
            ComputerName = $session.Cluster
            Port         = $Script:DefaultSshPort
            AcceptKey    = $true
            ErrorAction  = 'Stop'
            Credential   = $cred
        }

        $sshSession = New-SSHSession @sshParams

        if (-not $sshSession -or -not $sshSession.Connected) {
            return [pscustomobject]@{
                err = "Failed to establish an SSH session to '$Cluster'."
            }
        }

        Write-IBMSVLog -Level DEBUG -Message "SSH session established for $Cluster (Session ID: $($sshSession.SessionId))"

        return $sshSession
    }
    catch {
        $errorMessage = $_.Exception.Message

        if ($errorMessage -match "Key exchange negotiation failed|host key.*mismatch|host key.*differ|fingerprint") {
            if ($session.AutoAddHostKey) {
                Write-IBMSVLog -Level WARN -Message "Host key mismatch detected for $($session.Cluster). Attempting to remove old key and add new key on connection retry..."
                try {
                    Remove-SSHTrustedHost -HostName $session.Cluster -ErrorAction SilentlyContinue | Out-Null
                    Write-IBMSVLog -Level DEBUG -Message "Old host key removed. Retrying connection..."

                    $sshSession = New-SSHSession @sshParams
                    if (-not $sshSession -or -not $sshSession.Connected) {
                        return [pscustomobject]@{
                            err = "Failed to establish an SSH session to '$Cluster'."
                        }
                    }
                    Write-IBMSVLog -Level INFO -Message "SSH session established after host key update for $Cluster (Session ID: $($sshSession.SessionId))"
                    return $sshSession
                }
                catch {
                    return [pscustomobject]@{
                        err = "SSH connection failed after removing host key: $($_.Exception.Message)"
                    }
                }
            }
            else {
                return [pscustomobject]@{
                    err = "Host key mismatch detected for $($session.Cluster). Use -AutoAddHostKey parameter to automatically remove old key and add new key on next connection attempt."
                }
            }
        }
        else {
            Write-IBMSVLog -Level DEBUG -Message "Unhandled SSH connection error for $($session.Cluster): Type=$($_.Exception.GetType().FullName), Message=$errorMessage"
            return [pscustomobject]@{
                err = "SSH connection failed: $errorMessage"
            }
        }
    }
}
