# PSScriptAnalyzer SuppressMessageAttribute
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'Plaintext SecureString is acceptable for unit tests.'
)]
param()
Describe "Set-IBMSVCloudCallhome" {
    BeforeAll {
        $script:proxyPass = ConvertTo-SecureString "password1234" -AsPlainText -Force
    }
    BeforeEach {
        $script:callCount = 0
    }

    Context "Create Proxy Server" {
        It "Should throw error when enabling a proxy server without required params" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsproxy") { return @{ enabled = 'no'; url = ''; port = ''; username = ''; password_set = ''; certificate = '' } }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVCloudCallhome -ProxyUsername "pwsh_user0" } | Should -Throw "Proxy URL and Port must be specified to enable/create proxy."
        }

        It "Should throw error when ProxyPassword is used without ProxyUsername" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsproxy") { return @{ enabled = 'no'; url = ''; port = ''; username = ''; password_set = ''; certificate = '' } }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVCloudCallhome -ProxyUrl "http://proxy.example.ibm.com" -ProxyPort 8080 -ProxyPassword $script:proxyPass } | Should -Throw "CMMVC5731E Parameter -ProxyPassword is invalid without -ProxyUsername."
        }

        It "Should not call API to create proxy when -WhatIf is specified" {
            Set-IBMSVCloudCallhome -ProxyUrl "http://proxy.example.ibm.com" -ProxyPort 8080 -WhatIf
        }

        It "Should create a proxy server with url and port" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lsproxy") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ enabled = 'no'; url = ''; port = '0'; username = ""; password_set = 'no'; certificate = '' } }
                    return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = ""; password_set = 'no'; certificate = '' }
                }
            } -ModuleName IBMStorageVirtualize

            $result = Set-IBMSVCloudCallhome -ProxyUrl "http://proxy.example.ibm.com" -ProxyPort 8080
            $result.Proxy.enabled | Should -Be 'yes'
            $result.Proxy.url | Should -Be "http://proxy.example.ibm.com"
            $result.Proxy.port | Should -Be "8080"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsproxy' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'mkproxy' -and $CmdOpts.url -eq 'http://proxy.example.ibm.com' -and $CmdOpts.port -eq 8080 }
        }

        It "Should create a proxy server with url, port, username and password" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lsproxy") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ enabled = 'no'; url = ''; port = '0'; username = ""; password_set = 'no'; certificate = '' } }
                    return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '' }
                }
            } -ModuleName IBMStorageVirtualize

            $result = Set-IBMSVCloudCallhome -ProxyUrl "http://proxy.example.ibm.com" -ProxyPort 8080 -ProxyUsername "pwsh_user0" -ProxyPassword $script:proxyPass
            $result.Proxy.enabled | Should -Be 'yes'
            $result.Proxy.url | Should -Be "http://proxy.example.ibm.com"
            $result.Proxy.port | Should -Be "8080"
            $result.Proxy.username | Should -Be "pwsh_user0"
            $result.Proxy.password_set | Should -Be "yes"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'mkproxy' -and $CmdOpts.url -eq 'http://proxy.example.ibm.com' -and $CmdOpts.port -eq 8080 -and $CmdOpts.username -eq 'pwsh_user0' }
        }

        It "Should create a proxy server with url, port and sslCertificatePath" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lsproxy") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ enabled = 'no'; url = ''; port = '0'; username = ""; password_set = 'no'; certificate = '' } }
                    return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = ""; password_set = 'no'; certificate = '1 fields' }
                }
            } -ModuleName IBMStorageVirtualize

            $result = Set-IBMSVCloudCallhome -ProxyUrl "http://proxy.example.ibm.com" -ProxyPort 8080 -ProxySslCertificatePath "/proxy-cert.pem"
            $result.Proxy.enabled | Should -Be 'yes'
            $result.Proxy.url | Should -Be "http://proxy.example.ibm.com"
            $result.Proxy.port | Should -Be "8080"
            $result.Proxy.certificate | Should -Be "1 fields"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'mkproxy' -and $CmdOpts.sslcert -eq '/proxy-cert.pem' }
        }

        It "Should create a proxy server with url, port, username, password and sslCertificatePath" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lsproxy") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ enabled = 'no'; url = ''; port = '0'; username = ""; password_set = 'no'; certificate = '' } }
                    return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '1 fields' }
                }
            } -ModuleName IBMStorageVirtualize

            $result = Set-IBMSVCloudCallhome -ProxyUrl "http://proxy.example.ibm.com" -ProxyPort 8080 -ProxyUsername "pwsh_user0" -ProxyPassword $script:proxyPass -ProxySslCertificatePath "/proxy-cert.pem"
            $result.Proxy.url | Should -Be "http://proxy.example.ibm.com"
            $result.Proxy.port | Should -Be "8080"
            $result.Proxy.username | Should -Be "pwsh_user0"
            $result.Proxy.password_set | Should -Be "yes"
            $result.Proxy.certificate | Should -Be "1 fields"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'mkproxy' }
        }

        It "Should throw error when REST API call fails during proxy creation" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lsproxy") { return @{ enabled = 'no' } }
                if ($Cmd -eq "mkproxy") {
                    return [pscustomobject]@{ url = "https://1.1.1.1:7443/rest/v1/mkproxy"; code = 500; err = "HTTPError failed"; out = @{}; data = @{} }
                }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVCloudCallhome -ProxyUrl "http://proxy.example.ibm.com" -ProxyPort 8080 } | Should -Throw
        }
    }

    Context "Modify Proxy Server" {
        It "Should throw error when ProxySslCertificatePath and RemoveProxySslCertificatePath are both specified" {
            { Set-IBMSVCloudCallhome -ProxySslCertificatePath "/proxy-cert.pem" -RemoveProxySslCertificatePath } | Should -Throw "Parameters -ProxySslCertificatePath and -RemoveProxySslCertificatePath are mutually exclusive."
        }

        It "Should throw error when ProxyUsername and RemoveProxyCredentials are both specified" {
            { Set-IBMSVCloudCallhome -ProxyUsername "pwsh_user0" -RemoveProxyCredentials } | Should -Throw "Parameters -ProxyUsername and -ProxyPassword are mutually exclusive with -RemoveProxyCredentials."
        }

        It "Should throw error when ProxyPassword and RemoveProxyCredentials are both specified" {
            { Set-IBMSVCloudCallhome -ProxyPassword $script:proxyPass -RemoveProxyCredentials } | Should -Throw "Parameters -ProxyUsername and -ProxyPassword are mutually exclusive with -RemoveProxyCredentials."
        }

        It "Should update proxy server url and port" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsproxy") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '' }}
                    return @{ enabled = 'yes'; url = 'http://proxy1.example.ibm.com'; port = '8081'; username = "pwsh_user0"; password_set = 'yes'; certificate = '' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -ProxyUrl "http://proxy1.example.ibm.com" -ProxyPort 8081

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsproxy' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chproxy' -and $CmdOpts.url -eq 'http://proxy1.example.ibm.com' -and $CmdOpts.port -eq 8081 }
        }

        It "Should update proxy server username and password" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsproxy") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '' }}
                    return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user1"; password_set = 'yes'; certificate = '' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -ProxyUsername "pwsh_user1" -ProxyPassword $script:proxyPass

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chproxy' -and $CmdOpts.username -eq 'pwsh_user1' }
        }

        It "Should update proxy server ssl certificate path" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsproxy") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '' }}
                    return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '1 fields' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -ProxySslCertificatePath "/proxy-cert.pem"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chproxy' -and $CmdOpts.sslcert -eq '/proxy-cert.pem' }
        }

        It "Should remove proxy server credentials" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsproxy") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '' }}
                    return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = ""; password_set = 'no'; certificate = '' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -RemoveProxyCredentials

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chproxy' -and $CmdOpts.nousername -eq $true }
        }

        It "Should remove proxy server ssl certificate path" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsproxy") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '1 fields' }}
                    return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -RemoveProxySslCertificatePath

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chproxy' -and $CmdOpts.nosslcert -eq $true }
        }

        It "Should update proxy server with multiple params" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsproxy") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '' }}
                    return @{ enabled = 'yes'; url = 'http://proxy1.example.ibm.com'; port = '8081'; username = "pwsh_user1"; password_set = 'yes'; certificate = '1 fields' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -ProxyUrl "http://proxy1.example.ibm.com" -ProxyPort 8081 -ProxyUsername "pwsh_user1" -ProxyPassword $script:proxyPass -ProxySslCertificatePath "/proxy-cert.pem"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chproxy' -and
                    $CmdOpts.url -eq 'http://proxy1.example.ibm.com' -and
                    $CmdOpts.port -eq 8081 -and
                    $CmdOpts.username -eq 'pwsh_user1' -and
                    $CmdOpts.sslcert -eq '/proxy-cert.pem'
               }
        }

        It "Should be idempotent when proxy values already match" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsproxy") {
                    return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -ProxyUrl "http://proxy.example.ibm.com" -ProxyPort 8080 -ProxyUsername "pwsh_user0"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsproxy' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chproxy' }
        }
    }

    Context "Remove Proxy Server" {
        It "Should throw error when proxy configuration parameter and RemoveProxy are specified" {
            { Set-IBMSVCloudCallhome -ProxyUrl "http://proxy1.example.ibm.com" -RemoveProxy } | Should -Throw "Parameters for proxy configuration and removal are mutually exclusive."
        }

        It "Should not call API to remove proxy when -WhatIf is specified" {
            Mock Invoke-IBMSVRestRequest {} -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -RemoveProxy -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chproxy' }
        }

        It "Should remove proxy when proxy server exists" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsproxy") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '' }}
                    return @{ enabled = 'no'; url = ''; port = '0'; username = ""; password_set = 'no'; certificate = '' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -RemoveProxy

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsproxy' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'rmproxy' }
        }

        It "Should be idempotent when proxy is already disabled" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsproxy") {
                    return @{ enabled = 'no' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -RemoveProxy

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsproxy' }
        }
    }

    Context "Enable Cloud Callhome" {
        It "Should throw error when EnableCallhome and DisableCallhome are both specified" {
            { Set-IBMSVCloudCallhome -EnableCallhome -DisableCallhome } | Should -Throw "Parameters -EnableCallhome and -DisableCallhome are mutually exclusive."
        }

        It "Should throw error when SITenantID and ClearTenantID are both specified" {
            { Set-IBMSVCloudCallhome -SITenantID "tenantid-12345678" -ClearTenantID } | Should -Throw "Parameters -SITenantID and -ClearTenantID are mutually exclusive."
        }

        It "Should throw error when SIAPIKey and ClearAPIKey are both specified" {
            { Set-IBMSVCloudCallhome -SIAPIKey "apikey-12345678" -ClearAPIKey } | Should -Throw "Parameters -SIAPIKey and -ClearAPIKey are mutually exclusive."
        }

        It "Should throw error when SIAPIKey and ClearTenantID are both specified" {
            { Set-IBMSVCloudCallhome -SIAPIKey "apikey-12345678" -ClearTenantID } | Should -Throw "Parameters -SIAPIKey and -ClearTenantID are mutually exclusive."
        }

        It "Should throw error when setting API key without tenant ID configured" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lscloudcallhome") {
                    return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = ''; apikey_configured = 'no' }
                }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVCloudCallhome -SIAPIKey "pwsh" } | Should -Throw "CMMVC1476E To set the API key, the Storage Insight tenant ID must be configured."
        }

        It "Should not call API to enable callhome when -WhatIf is specified" {
            Mock Invoke-IBMSVRestRequest {} -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -EnableCallhome -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' }
        }

        It "Should set SI tenant ID" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lscloudcallhome") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = ''; apikey_configured = 'no' } }
                    return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'no' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -SITenantID "tenantid-12345678"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lscloudcallhome' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.sitenantid -eq 'tenantid-12345678' }
        }

        It "Should set SI tenant ID and API key together" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lscloudcallhome") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = ''; apikey_configured = 'no' } }
                    return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -SITenantID "tenantid-12345678" -SIAPIKey "pwsh"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lscloudcallhome' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.sitenantid -eq 'tenantid-12345678' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.siapikey -eq 'pwsh' }
        }

        It "Should clear SI tenant ID and API key together" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lscloudcallhome") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' } }
                    return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = ''; apikey_configured = 'no' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -ClearTenantID -ClearAPIKey

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.cleartenant -eq $true }
        }

        It "Should update SI tenant ID and clear API key" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lscloudcallhome") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = ''; apikey_configured = 'yes' } }
                    return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'no' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -SITenantID "tenantid-12345678" -ClearAPIKey

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.sitenantid -eq 'tenantid-12345678'}
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.clearsiapikey -eq $true}
        }

        It "Should be idempotent when SI tenant ID already matches" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lscloudcallhome") {
                    return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'no' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -SITenantID "tenantid-12345678"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lscloudcallhome' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' }
        }

        It "Should be idempotent when ClearTenantID and tenant ID is already empty" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lscloudcallhome") {
                    return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = ''; apikey_configured = 'no' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -ClearTenantID

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lscloudcallhome' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' }
        }

        It "Should be idempotent when ClearAPIKey and API key is already not configured" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lscloudcallhome") {
                    return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = ''; apikey_configured = 'no' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -ClearAPIKey

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lscloudcallhome' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' }
        }

        It "Should enable cloudcallhome when currently disabled" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lscloudcallhome") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' } }
                    return @{ status = 'enabled'; connection = 'active'; error_sequence_number = ''; last_success = '260101000001'; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -EnableCallhome

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lscloudcallhome' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.enable -eq $true }
        }

        It "Should trigger connection test when cloudcallhome is already enabled" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lscloudcallhome") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { @{ status = 'enabled'; connection = 'active'; error_sequence_number = ''; last_success = '260101000001'; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' } }
                    return @{ status = 'enabled'; connection = 'active'; error_sequence_number = ''; last_success = '260101000001'; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -EnableCallhome

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lscloudcallhome' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'sendcloudcallhome' -and $CmdOpts.connectiontest -eq $true }
        }

        It "Should enable cloudcallhome with tenant ID and API key" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                $script:callCount++

                if ($Cmd -eq "lscloudcallhome") {
                    if ($script:callCount -eq 1) { return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = ''; apikey_configured = 'no' } }
                    return @{ status = 'enabled'; connection = 'active'; error_sequence_number = ''; last_success = '260101000001'; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -SITenantID "tenantid-12345678" -SIAPIKey "pwsh" -EnableCallhome

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lscloudcallhome' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.sitenantid -eq 'tenantid-12345678' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.siapikey -eq 'pwsh' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.enable -eq $true }
        }

        It "Should throw error when REST API call fails during enable" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lscloudcallhome") {
                    return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' }
                }
                if ($Cmd -eq "chcloudcallhome") {
                    return [pscustomobject]@{ url = "https://1.1.1.1:7443/rest/v1/chcloudcallhome"; code = 500; err = "HTTPError failed"; out = @{}; data = @{} }
                }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVCloudCallhome -EnableCallhome } | Should -Throw
        }
    }

    Context "Disable Cloud Callhome" {
        It "Should disable cloudcallhome when currently enabled" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lscloudcallhome") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ status = 'enabled'; connection = 'active'; error_sequence_number = ''; last_success = '260101000001'; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' } }
                    return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -DisableCallhome

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lscloudcallhome' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.disable -eq $true }
        }

        It "Should be idempotent when cloudcallhome is already disabled" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lscloudcallhome") {
                    return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -DisableCallhome

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lscloudcallhome' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' }
        }

        It "Should not call API to disable callhome when -WhatIf is specified" {
            Mock Invoke-IBMSVRestRequest {} -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -DisableCallhome -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' }
        }

        It "Should disable cloudcallhome and clear tenant ID" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lscloudcallhome") {
                    $script:callCount++
                    if ($script:callCount -eq 1) { return @{ status = 'enabled'; connection = 'active'; error_sequence_number = ''; last_success = '260101000001'; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' } }
                    return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = ''; apikey_configured = 'no' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -DisableCallhome -ClearTenantID

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 4 -ModuleName IBMStorageVirtualize
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.disable -eq $true }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.cleartenant -eq $true }
        }
    }

    Context "Proxy and Callhome configuration together" {
        It "Should create proxy server and enable callhome" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                $script:callCount++
                if ($Cmd -eq "lsproxy") {
                    if ($script:callCount -eq 1) {
                        return @{ enabled = 'no'; url = ''; port = '0'; username = ""; password_set = 'no'; certificate = '' }
                    }
                    return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user"; password_set = 'yes'; certificate = '' }
                }
                if ($Cmd -eq "lscloudcallhome") {
                    if ($script:callCount -eq 3) {
                        return @{ status = 'disabled'; connection = ''; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = ''; apikey_configured = 'no' }
                    }
                    return @{ status = 'enabled'; connection = 'active'; error_sequence_number = ''; last_success = '260101000001'; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -ProxyUrl "http://proxy.example.ibm.com" -ProxyPort 8080 -ProxyUsername "pwsh_user" -ProxyPassword $script:proxyPass -SITenantID "tenantid-12345678" -SIAPIKey "pwsh" -EnableCallhome

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'mkproxy' -and $CmdOpts.url -eq 'http://proxy.example.ibm.com' -and $CmdOpts.port -eq 8080 -and $CmdOpts.username -eq 'pwsh_user'}
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.sitenantid -eq 'tenantid-12345678' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.siapikey -eq 'pwsh' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.enable -eq $true }
        }

        It "Should be idempotent when proxy and callhome already match desired state" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsproxy") {
                    return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '' }
                }
                if ($Cmd -eq "lscloudcallhome") {
                    return @{ status = 'enabled'; connection = 'active'; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -ProxyUrl "http://proxy.example.ibm.com" -ProxyPort 8080 -ProxyUsername "pwsh_user0" -SITenantID "tenantid-12345678" -EnableCallhome

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsproxy' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lscloudcallhome' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'sendcloudcallhome' }
        }

        It "Should remove proxy and callhome configuration" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lsproxy") {
                    return @{ enabled = 'yes'; url = 'http://proxy.example.ibm.com'; port = '8080'; username = "pwsh_user0"; password_set = 'yes'; certificate = '' }
                }
                if ($Cmd -eq "lscloudcallhome") {
                    return @{ status = 'enabled'; connection = 'active'; error_sequence_number = ''; last_success = ''; last_failure = ''; si_tenant_id = 'tenantid-12345678'; apikey_configured = 'yes' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVCloudCallhome -RemoveProxy -ClearTenantID -DisableCallhome

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsproxy' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lscloudcallhome' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'rmproxy' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.disable -eq $true }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chcloudcallhome' -and $CmdOpts.cleartenant -eq $true }
        }
    }
}
