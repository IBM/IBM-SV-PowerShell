<#
.SYNOPSIS
Configures proxy and Cloud Callhome settings on an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVCloudCallhome cmdlet manages proxy configuration and Cloud Callhome (Storage Insights) settings.

It maps to mkproxy, chproxy, rmproxy, chcloudcallhome and related commands depending on system capabilities and requested changes.

The cmdlet is idempotent:
- Only properties that differ from the current configuration are modified.
- If no changes are required, no operation is performed.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER ProxyUrl
Specifies the proxy server URL.

.PARAMETER ProxyPort
Specifies the proxy server port.

.PARAMETER ProxyUsername
Specifies the proxy authentication username.

Cannot be used with -RemoveProxyCredentials.

.PARAMETER ProxyPassword
Specifies the proxy authentication password.

Cannot be used with -RemoveProxyCredentials.

.PARAMETER ProxySslCertificatePath
Specifies the proxy SSL certificate path.

.PARAMETER RemoveProxyCredentials
Removes the configured proxy username and password.

Cannot be used with -ProxyUsername or -ProxyPassword.

.PARAMETER RemoveProxySslCertificatePath
Removes the configured proxy SSL certificate path.

Cannot be used with -ProxySslCertificatePath.

.PARAMETER RemoveProxy
Removes the proxy configuration.

Cannot be used with other proxy parameters.

.PARAMETER EnableCallhome
Enables Cloud Callhome.

If already enabled, a connection test is triggered.

.PARAMETER DisableCallhome
Disables Cloud Callhome.

.PARAMETER SITenantID
Specifies the Storage Insights tenant ID.

.PARAMETER ClearTenantID
Clears the tenant ID.

.PARAMETER SIAPIKey
Specifies the Storage Insights API key.

The tenant ID must be configured before setting the API key.

.PARAMETER ClearAPIKey
Clears the API key.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Set-IBMSVCloudCallhome -ProxyUrl http://proxy -ProxyPort 8080

Configures proxy.

.EXAMPLE
PS> Set-IBMSVCloudCallhome -EnableCallhome

Enables Cloud Callhome.

.EXAMPLE
PS> Set-IBMSVCloudCallhome -SITenantID t1 -SIAPIKey key

Configures the Storage Insights tenant ID and API key for Cloud Callhome.

.EXAMPLE
PS> Set-IBMSVCloudCallhome -ProxyUrl http://proxy -ProxyPort 8080 -SITenantID t1 -SIAPIKey key -EnableCallhome

Configures proxy, storage Insights and enables Cloud Callhome.

.INPUTS
None.

.OUTPUTS
System.Object

Returns proxy and callhome configuration.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs validation of parameter combinations before execution.
- Only modified properties are sent to the backend.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkproxy

.LINK
https://www.ibm.com/docs/en/search/chproxy

.LINK
https://www.ibm.com/docs/en/search/rmproxy

.LINK
https://www.ibm.com/docs/en/search/chcloudcallhome
#>

function Set-IBMSVCloudCallhome {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [string]$ProxyUrl,

        [int]$ProxyPort,

        [string]$ProxyUsername,

        [SecureString]$ProxyPassword,

        [string]$ProxySslCertificatePath,

        [switch]$RemoveProxyCredentials,

        [switch]$RemoveProxySslCertificatePath,

        [switch]$RemoveProxy,

        [switch]$EnableCallhome,

        [switch]$DisableCallhome,

        [string]$SITenantID,

        [switch]$ClearTenantID,

        [string]$SIAPIKey,

        [switch]$ClearAPIKey,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        if (($ProxyUsername -or $ProxyPassword) -and $RemoveProxyCredentials) {
            throw (Resolve-Error -ErrorInput "Parameters -ProxyUsername and -ProxyPassword are mutually exclusive with -RemoveProxyCredentials." -Category InvalidArgument)
        }
        $mutex = @(
            @('ProxySslCertificatePath', 'RemoveProxySslCertificatePath'),
            @('EnableCallhome', 'DisableCallhome'),
            @('SITenantID', 'ClearTenantID'),
            @('SIAPIKey', 'ClearTenantID'),
            @('SIAPIKey', 'ClearAPIKey')
        )
        foreach ($rule in $mutex) {
            if ($PSBoundParameters.ContainsKey($rule[0]) -and $PSBoundParameters.ContainsKey($rule[1])) {
                throw (Resolve-Error -ErrorInput "Parameters -$($rule[0]) and -$($rule[1]) are mutually exclusive." -Category InvalidArgument)
            }
        }

        $proxyConfigParams = ($ProxyUrl -or $ProxyPort -or $ProxyUsername -or $ProxyPassword -or $ProxySslCertificatePath -or $RemoveProxyCredentials -or $RemoveProxySslCertificatePath)
        if ($proxyConfigParams -and $RemoveProxy) {
            throw (Resolve-Error -ErrorInput "Parameters for proxy configuration and removal are mutually exclusive." -Category InvalidArgument)
        }

        # --- Handle Proxy Configuration ---
        if (($proxyConfigParams -or $RemoveProxy) -and $PSCmdlet.ShouldProcess("Proxy", "Configure")) {
            $proxyChanged = $false
            $proxyInfo = $null

            # --- Fetch current state ---
            $proxyData = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsproxy" -CmdArgs ("-gui")
            if ($proxyData.err) {
                throw (Resolve-Error -ErrorInput $proxyData -Category InvalidOperation)
            }
            $proxyInfo = $proxyData

            $isProxyEnabled = ($proxyData.enabled -eq "yes")

            # --- Handle disable case ---
            if ($RemoveProxy) {
                if ($isProxyEnabled) {
                    Write-IBMSVLog -Level DEBUG -Message "Removing proxy configuration."
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "rmproxy"
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                    $proxyChanged = $true
                    Write-IBMSVLog -Level INFO -Message "Proxy disabled."
                }
                else {
                    Write-IBMSVLog -Level INFO -Message "Proxy already disabled. No action required."
                }
            }
            else {
                # --- Handle enable/configure case ---
                if (-not $isProxyEnabled) {
                    if (-not $ProxyUrl -or -not $ProxyPort) {
                        throw (Resolve-Error -ErrorInput "Proxy URL and Port must be specified to enable/create proxy." -Category InvalidArgument)
                    }
                    if (-not $ProxyUsername -and $ProxyPassword) {
                        throw (Resolve-Error -ErrorInput "CMMVC5731E Parameter -ProxyPassword is invalid without -ProxyUsername." -Category InvalidArgument)
                    }
                }
                $opts = @{}

                if ($PSBoundParameters.ContainsKey('ProxyUrl') -and $ProxyUrl -ne $proxyData.url) {
                    $opts.url = $ProxyUrl
                }
                if ($PSBoundParameters.ContainsKey('ProxyPort') -and $ProxyPort -ne [int]$proxyData.port) {
                    $opts.port = $ProxyPort
                }
                if ($PSBoundParameters.ContainsKey('ProxyUsername') -and $ProxyUsername -ne $proxyData.username) {
                    $opts.username = $ProxyUsername
                }
                if ($PSBoundParameters.ContainsKey('ProxyPassword')) {
                    $opts.password = (New-Object PSCredential "user", $ProxyPassword).GetNetworkCredential().Password
                }
                if ($PSBoundParameters.ContainsKey('ProxySslCertificatePath')) {
                    $opts.sslcert = $ProxySslCertificatePath
                }

                if ($RemoveProxyCredentials -and $proxyData.username) {
                    $opts.nousername = $true
                }
                if ($RemoveProxySslCertificatePath -and $proxyData.certificate -ne "") {
                    $opts.nosslcert = $true
                }

                if ($opts.Count -eq 0) {
                    Write-IBMSVLog -Level INFO -Message "No changes required for proxy configuration."
                }
                else {
                    if ($isProxyEnabled) {
                        Write-IBMSVLog -Level DEBUG -Message "Modifying existing proxy."
                        $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chproxy" -CmdOpts $opts
                        if ($result.err) {
                            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                        }
                    }
                    else {
                        Write-IBMSVLog -Level DEBUG -Message "Creating proxy configuration."
                        $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "mkproxy" -CmdOpts $opts
                        if ($result.err) {
                            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                        }
                    }
                    $proxyChanged = $true
                    Write-IBMSVLog -Level INFO -Message "Proxy configuration updated successfully."
                }
            }
        }


        # --- Handle Callhome Configuration ---
        $callhomeConfigParams = ($EnableCallhome -or $DisableCallhome -or $SITenantID -or $ClearTenantID -or $SIAPIKey -or $ClearAPIKey)
        if ($callhomeConfigParams -and $PSCmdlet.ShouldProcess("Cloud Callhome", "Configure")) {
            $callhomeChanged = $false
            $callhomeInfo = $null

            # --- Fetch current state ---
            $callhomeData = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lscloudcallhome" -CmdArgs ("-gui")
            if ($callhomeData.err) {
                throw (Resolve-Error -ErrorInput $callhomeData -Category InvalidOperation)
            }

            $callhomeInfo = $callhomeData

            if ($SIAPIKey) {
                if ($callhomeData.si_tenant_id -eq '' -and -not $SITenantID) {
                    throw (Resolve-Error -ErrorInput "CMMVC1476E To set the API key, the Storage Insight tenant ID must be configured." -Category InvalidArgument)
                }
            }
            $isCallhomeEnabled = ($callhomeData.status -eq "enabled")

            # --- Handle disable case ---
            if ($DisableCallhome) {
                if ($isCallhomeEnabled) {
                    Write-IBMSVLog -Level DEBUG -Message "Disabling cloud callhome "
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chcloudcallhome" -CmdOpts @{ disable = $true }
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                    $callhomeChanged = $true
                    Write-IBMSVLog -Level INFO -Message "Cloud callhome disabled."

                    Start-Sleep -Seconds 5
                }
                else {
                    Write-IBMSVLog -Level INFO -Message "Cloud callhome already disabled. No action required."
                }
            }

            if ($PSBoundParameters.ContainsKey('SITenantID') -and $SITenantID -ne $callhomeData.si_tenant_id) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chcloudcallhome" -CmdOpts @{ sitenantid = $SITenantID }
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                $callhomeChanged = $true
            }
            if ($PSBoundParameters.ContainsKey('ClearTenantID') -and $callhomeData.si_tenant_id -ne "") {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chcloudcallhome" -CmdOpts @{ cleartenant = $true }
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                $callhomeChanged = $true
            }
            if ($PSBoundParameters.ContainsKey('SIAPIKey')) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chcloudcallhome" -CmdOpts @{ siapikey = $SIAPIKey }
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                $callhomeChanged = $true
            }
            if ($PSBoundParameters.ContainsKey('ClearAPIKey') -and $callhomeData.apikey_configured -eq "yes") {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chcloudcallhome" -CmdOpts @{ clearsiapikey = $true }
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                $callhomeChanged = $true
            }

            if ($EnableCallhome) {
                if (-not $isCallhomeEnabled) {
                    Write-IBMSVLog -Level DEBUG -Message "Enabling cloud callhome "
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chcloudcallhome" -CmdOpts @{ enable = $true }
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }

                    $cloudStatus = $null; $attempts = 0; $maxAttempts = 10; $sleep = 2

                    while ($attempts -lt $maxAttempts) {
                        $attempts++

                        Write-Progress -Activity "Enabling Cloud Callhome" `
                            -Status "Attempt $attempts/$maxAttempts" `
                            -PercentComplete (($attempts / $maxAttempts) * 100)

                        Start-Sleep -Seconds $sleep

                        $callhomeResult = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lscloudcallhome" -CmdArgs ("-gui")
                        if ($callhomeResult.err) {
                            throw (Resolve-Error -ErrorInput $callhomeResult -Category InvalidOperation)
                        }
                        $cloudStatus = $callhomeResult.status

                        Write-IBMSVLog -Level DEBUG -Message "Attempt $attempts/$maxAttempts , status = '$cloudStatus'"

                        if ($cloudStatus -eq 'enabled') { break }
                    }

                    Write-Progress -Activity "Enabling Cloud Callhome" -Completed

                    if ($cloudStatus -eq 'enabled') {
                        Write-IBMSVLog -Level INFO -Message "Cloud callhome enabled successfully."
                    }
                    else {
                        Write-IBMSVLog -Level INFO -Message "Callhome with Cloud is enabled. Please check the status manually."
                    }
                }
                else {
                    Write-IBMSVLog -Level INFO -Message "Cloud callhome already enabled. Sending cloud callhome connection test..."
                    $testOpts = @{ connectiontest = $true }
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "sendcloudcallhome" -CmdOpts $testOpts
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                }
                $callhomeChanged = $true
            }
        }

        $ProxyOut = if ($proxyChanged) {
            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsproxy"
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            $result
        }
        else {
            $proxyInfo
        }
        $callhomeOut = if ($callhomeChanged) {
            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lscloudcallhome"
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            $result
        }
        else {
            $callhomeInfo
        }
        return [PSCustomObject]@{
            Proxy    = $ProxyOut
            Callhome = $callhomeOut
        }
    }
}
