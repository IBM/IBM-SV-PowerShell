<#
.SYNOPSIS
Creates a new truststore on IBM Storage Virtualize systems by exporting and exchanging certificates between clusters.

.DESCRIPTION
Creates the truststore between two IBM Storage Virtualize clusters.
For each cluster, the cmdlet exports the remote's root CA certificate (using chsystemcertstore
or chsystemcert depending on build version), transfers it via SCP, then runs mktruststore
with the appropriate scope flag (-grid, -flashgrid, or -restapi) derived from the target
cluster's build version. The operation runs symmetrically on both clusters in a single call.

.PARAMETER Name
Specifies the name of the truststore to create on the local cluster.

.PARAMETER RemoteTruststoreName
Specifies the name of the truststore to create on the remote cluster.
If not provided, defaults to the same value as -Name.

.PARAMETER RemoteCluster
Specifies the remote cluster on which to create the truststore.
This is a required parameter.

.PARAMETER Cluster
Specifies the local IBM Storage Virtualize cluster on which the truststore is created.
If not provided, the primary cluster is used.

.EXAMPLE
PS> New-IBMSVTruststore -Name "trust_partner" -RemoteCluster "10.10.10.20"
Creates a truststore named "trust_partner" on both the local and remote clusters.

.EXAMPLE
PS> New-IBMSVTruststore -Name "trust_local" -RemoteTruststoreName "trust_remote" -RemoteCluster "10.10.10.20" -Cluster "10.10.10.10"
Creates truststores with different names on local and remote clusters.

.INPUTS
None

.OUTPUTS
System.Object[]
Returns an array containing the truststore objects from both the local and remote
clusters (one entry each). If a truststore already existed on a cluster, the
existing object is returned for that cluster instead.

.NOTES
- Requires an active session on both clusters established via Connect-IBMStorageVirtualize before calling this cmdlet.
- The SCP transfer uses the credentials stored in the existing session; no separate SSH credentials are required.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mktruststore

.LINK
https://www.ibm.com/docs/en/search/chsystemcertstore

.LINK
https://www.ibm.com/docs/en/search/chsystemcert
#>

function New-IBMSVTruststore {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$RemoteTruststoreName,

        [Parameter(Mandatory)]
        [string]$RemoteCluster,

        [string]$Cluster
    )

    process {
        if (-not $Cluster) {
            $Cluster = $script:primarysession
        }

        if (-not $RemoteTruststoreName) {
            $RemoteTruststoreName = $Name
        }

        $buildVersion = Get-IBMSVVersion -Cluster $Cluster
        if ($buildVersion.PSObject.Properties.Name -contains "err") {
            throw (Resolve-Error -ErrorInput $buildVersion -Category InvalidOperation)
        }
        [version]$buildVersion = $buildVersion
        $remoteBuildVersion = Get-IBMSVVersion -Cluster $RemoteCluster
        if ($remoteBuildVersion.PSObject.Properties.Name -contains "err") {
            throw (Resolve-Error -ErrorInput $remoteBuildVersion -Category InvalidOperation)
        }
        [version]$remoteBuildVersion = $remoteBuildVersion
        $truststoreToCreate = @(
            [pscustomobject]@{
                Cluster            = $Cluster
                BuildVersion       = $buildVersion
                Name               = $Name
                RemoteCluster      = $RemoteCluster
                RemoteBuildVersion = $remoteBuildVersion
            }
            [pscustomobject]@{
                Cluster            = $RemoteCluster
                BuildVersion       = $remoteBuildVersion
                Name               = $RemoteTruststoreName
                RemoteCluster      = $Cluster
                RemoteBuildVersion = $buildVersion
            }
        )
        $result = @()
        foreach ($system in $truststoreToCreate) {
            if ($PSCmdlet.ShouldProcess("Truststore $($system.Name)", "Create")) {
                $truststoreData = Invoke-IBMSVRestRequest -Cluster $system.Cluster -Cmd "lstruststore" -CmdArgs $system.Name
                if ($truststoreData) {
                    if ($truststoreData.PSObject.Properties.Name -contains "err") {
                        throw (Resolve-Error -ErrorInput $truststoreData -Category InvalidOperation)
                    }
                    Write-IBMSVLog -Level INFO -Message "Truststore '$($system.Name)' already exists. Returning existing object."
                    $result += $truststoreData
                }
                else {
                    # --- Export Certificate ---
                    $certStoreCmdsSupported = $system.RemoteBuildVersion -ge ([version]"9.1.0.0")

                    $ExportCommand = $null
                    $ExportCmdOpts = $null
                    $CertificateFile = $null
                    if ($certStoreCmdsSupported) {
                        $iccInfo = Invoke-IBMSVRestRequest -Cluster $system.RemoteCluster -Cmd "lssystemcertstore" -CmdArgs @("internal_communication")
                        if ($iccInfo.PSObject.Properties.Name -contains "err") {
                            throw (Resolve-Error -ErrorInput $iccInfo -Category InvalidOperation)
                        }
                        $ExportCommand = "chsystemcertstore"
                        if ($iccInfo) {
                            $ExportCmdOpts = @{ exportrootca = $true; scope = "internal_communication" }
                            $CertificateFile = "system_rootcacertificate_slot_3.pem"
                        }
                        else {
                            $ExportCmdOpts = @{ exportrootca = $true; scope = "default" }
                            $CertificateFile = "rootcacertificate.pem"
                        }
                    }
                    else {
                        $ExportCommand = "chsystemcert"
                        if ([version]$system.RemoteBuildVersion -eq ([version]"8.7.3.0")) {
                            $ExportCmdOpts = @{ exportrootcacert = $true }
                            $CertificateFile = "rootcacertificate.pem"
                        }
                        else {
                            # legacy
                            $ExportCmdOpts = @{ export = $true }
                            $CertificateFile = "certificate.pem"
                        }
                    }

                    Write-IBMSVLog -Level DEBUG -Message "Exporting certificate $CertificateFile using $ExportCommand"
                    $exportResult = Invoke-IBMSVRestRequest -Cluster $system.RemoteCluster -Cmd $ExportCommand -CmdOpts $ExportCmdOpts
                    if ($exportResult.PSObject.Properties.Name -contains "err") {
                        throw (Resolve-Error -ErrorInput $exportResult -Category InvalidOperation)
                    }
                    Write-IBMSVLog -Level INFO -Message "Certificate '$CertificateFile' exported."

                    # --- Exchange Certificate ---
                    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                    $targetCertificateFile = "{0}_{1}_{2}" -f `
                        [System.IO.Path]::GetFileNameWithoutExtension($CertificateFile),
                        ($system.RemoteCluster -replace '\.', '_'),
                        $timestamp
                    $targetCertificateFile += ".pem"
                    Write-IBMSVLog -Level DEBUG -Message "Transferring certificate '$CertificateFile' as '$targetCertificateFile'."

                    $scpResult = Copy-IBMSVCertificateViaSCP -SourceCluster $system.RemoteCluster -TargetCluster $system.Cluster -CertFile $CertificateFile -TargetCertFile $targetCertificateFile
                    if (-not $scpResult.Success) {
                        throw (Resolve-Error -ErrorInput $scpResult.Error -Category InvalidOperation)
                    }

                    Write-IBMSVLog -Level INFO -Message "Certificate '$CertificateFile' transferred successfully as '$targetCertificateFile'."

                    # --- Create Truststore ---
                    $opts = @{
                        file = "/tmp/$targetCertificateFile"
                        name = $system.Name
                    }

                    if ($CertificateFile -eq "certificate.pem") {
                        $opts["restapi"] = "on"
                    }
                    else {
                        [version]$buildVersion = "$($system.BuildVersion.Major).$($system.BuildVersion.Minor)"
                        $buildPatch = $system.BuildVersion.Build
                        if ($buildVersion -eq ([version]"8.7") -and $buildPatch -eq "3") {
                            $opts["flashgrid"] = "on"
                        }
                        elseif ($buildVersion -gt ([version]"8.7")) {
                            $opts["grid"] = "on"
                        }
                        else {
                            $opts["restapi"] = "on"
                        }
                    }

                    Write-IBMSVLog -Level DEBUG -Message "Creating truststore '$($system.Name)'"
                    $createResult = Invoke-IBMSVRestRequest -Cluster $system.Cluster -Cmd "mktruststore" -CmdOpts $opts
                    if ($createResult.PSObject.Properties.Name -contains "err") {
                        throw (Resolve-Error -ErrorInput $createResult -Category InvalidOperation)
                    }
                    Write-IBMSVLog -Level INFO -Message "Truststore [$($createResult.id)] '$($system.Name)' created successfully."

                    $current = Invoke-IBMSVRestRequest -Cluster $system.Cluster -Cmd "lstruststore" -CmdArgs ($system.Name)
                    if ($current.PSObject.Properties.Name -contains "err") {
                        throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
                    }
                    $result += $current
                }
            }
        }
        return $result
    }
}

function Copy-IBMSVCertificateViaSCP {
    [CmdletBinding()]
    param(
        [string]$SourceCluster,
        [string]$TargetCluster,
        [string]$CertFile,
        [string]$TargetCertFile

    )
    $sshSession = $null

    $sourceSession = $script:sessions[$SourceCluster]
    $targetSession = $script:sessions[$TargetCluster]

    $sshSession = New-IBMSVSshSession -Cluster $sourceSession.Cluster
    if ($sshSession.PSObject.Properties.Name -contains "err") {
        return [pscustomobject]@{
            Success = $false
            Error   = $sshSession.err
        }
    }
    $scpCommand = "scp -O -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null /dumps/$CertFile $($targetSession.Credential.UserName)@$($TargetCluster):/tmp/$TargetCertFile"
    try {
        $stream = New-SSHShellStream -SSHSession $sshSession

        $stream.WriteLine($scpCommand)
        Start-Sleep -Milliseconds 500

        $output = ""
        $passwordSent = $false
        $transferComplete = $false

        $timeout = [TimeSpan]::FromSeconds(120)
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        while ($stopwatch.Elapsed -lt $timeout) {

            if ($stream.DataAvailable) {

                $data = $stream.Read()

                if ($data) {
                    $output += $data

                    if (-not $passwordSent -and $data -match "(?i)password:") {

                        $stream.WriteLine(
                            [System.Net.NetworkCredential]::new(
                                '',
                                $targetSession.Credential.Password
                            ).Password
                        )

                        $passwordSent = $true
                        continue
                    }

                    if ($passwordSent -and $data -match "(?i)(Permission denied|Authentication failed)") {
                        return [pscustomobject]@{
                            Success = $false
                            Error   = "Authentication failed while transferring the certificate via SCP."
                        }
                    }

                    $certFilePattern = [regex]::Escape($CertFile)
                    if ($output -match $certFilePattern -and $output -match '100%') {
                        $transferComplete = $true
                        break
                    }
                }
            }

            Start-Sleep -Milliseconds 200
        }

        $stopwatch.Stop()

        if (-not $transferComplete) {
            return [pscustomobject]@{
                Success = $false
                Error   = "Certificate exchange did not complete. Output: $output"
            }
        }
        return [pscustomobject]@{
            Success = $true
            Error   = $null
        }
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            Error   = $_.Exception.Message
        }
    }
    finally {
        if ($stream) {
            $stream.Dispose()
        }
        Remove-SSHSession -SSHSession $sshSession | Out-Null
    }
}
