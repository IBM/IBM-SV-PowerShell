# PSScriptAnalyzer SuppressMessageAttribute
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'Plaintext SecureString is acceptable for unit tests.'
)]
param()
BeforeAll {
    $script:pwsh_cred = New-Object System.Management.Automation.PSCredential ("pwsh_user", (ConvertTo-SecureString "pwsh_pass" -AsPlainText -Force))
    InModuleScope IBMStorageVirtualize {
        $script:sessions = @{}
        $script:primarysession = $null
    }

    Mock Invoke-IBMSVRestRequest {} -ModuleName IBMStorageVirtualize
    Mock Invoke-IBMSVPluginRegistration {} -ModuleName IBMStorageVirtualize
}

Describe "Connect-IBMStorageVirtualize" {

    Context "Validate" {
        BeforeEach {
            InModuleScope IBMStorageVirtualize -Parameters @{ cred = $script:pwsh_cred } {
                $script:sessions = @{
                    "1.1.1.11" = @{
                        Cluster = "1.1.1.11"
                        Domain = "flashsystem.com"
                        Credential = $script:pwsh_cred
                        ValidateCerts = $false
                        Primary = $true
                        SVCVersion = $null
                        Token = "abc123"
                        AutoAddHostKey = $false
                        SecretName = $null
                        VaultName = $null
                        Username = $null
                    }
                    "1.1.1.12" = @{
                        Cluster = "1.1.1.12"
                        Domain = "flashsystem.com"
                        Credential = $script:pwsh_cred
                        ValidateCerts = $false
                        Primary = $false
                        SVCVersion = $null
                        Token = "xyz789"
                        LastRestAuthTime = Get-Date
                        AutoAddHostKey = $false
                        SecretName = $null
                        VaultName = $null
                        Username = $null
                    }
                }
                $script:primarysession = "1.1.1.11"
            }

            Mock Invoke-RestMethod {} -ModuleName IBMStorageVirtualize
        }

        It "Should throw error when attempting to set different cluster as primary while primary already exists" {
            InModuleScope IBMStorageVirtualize {
                $script:sessions = @{}
                $script:primarysession = $null
            }
            Mock Invoke-RestMethod { return @{ token = "abc123" } } -ModuleName IBMStorageVirtualize

            Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -Credential $script:pwsh_cred -Primary
            { Connect-IBMStorageVirtualize -Cluster "1.1.1.13" -Credential $script:pwsh_cred -Primary } | Should -Throw "'1.1.1.11' is currently set as primary cluster. Please disconnect primary session before setting '1.1.1.13' as a primary cluster."
        }

        It "Should throw error when authentication fails" {
            InModuleScope IBMStorageVirtualize -Parameters @{ cred = $script:pwsh_cred }{
                $script:sessions = @{}
                $script:primarysession = $null
            }
            Mock Invoke-RestMethod { throw "Error" } -ModuleName IBMStorageVirtualize

            { Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -Credential $script:pwsh_cred } | Should -Throw
        }

        It "Should throw error when neither Credential, SecretName is provided" {
            InModuleScope IBMStorageVirtualize {
                $script:sessions = @{}
                $script:primarysession = $null
            }

            { Connect-IBMStorageVirtualize -Cluster "1.1.1.11" } | Should -Throw "Either -Credential or -SecretName must be specified."
        }
    }

    Context "Basic Successful Connect" {
        BeforeEach {
            InModuleScope IBMStorageVirtualize {
                $script:sessions = @{}
                $script:primarysession = $null
            }
            Mock Invoke-RestMethod { return @{ token = "abc123" } } -ModuleName IBMStorageVirtualize
        }

        It "Should create and stores session with correct properties" {
            Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -Credential $script:pwsh_cred

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result.Cluster           | Should -Be "1.1.1.11"
            $result.Domain            | Should -BeNullOrEmpty
            $result.Primary           | Should -BeFalse
            $result.ValidateCerts     | Should -BeFalse
            $result.AuthType          | Should -Be "Credential (Not Cached)"
            $result.AutoAddHostKey    | Should -BeFalse
        }

        It "Should construct FQDN correctly when Domain parameter is provided" {
            Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -Domain example.com -Credential $script:pwsh_cred

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result.Cluster           | Should -Be "1.1.1.11"
            $result.Domain            | Should -Be "example.com"
            $result.Primary           | Should -BeFalse
            $result.ValidateCerts     | Should -BeFalse
            $result.AuthType          | Should -Be "Credential (Not Cached)"
            $result.AutoAddHostKey    | Should -BeFalse
        }

        It "Should create and marks session as primary when Primary switch is specified" {
            Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -Credential $script:pwsh_cred -Primary

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result.Cluster           | Should -Be "1.1.1.11"
            $result.Domain            | Should -BeNullOrEmpty
            $result.Primary           | Should -BeTrue
            $result.ValidateCerts     | Should -BeFalse
            $result.AuthType          | Should -Be "Credential (Not Cached)"
            $result.AutoAddHostKey    | Should -BeFalse

            $result2 = Get-IBMSVSession -Primary
            $result2 | Should -BeLike $result
        }
    }

    Context "Certificate Validation" {
        BeforeEach {
            InModuleScope IBMStorageVirtualize {
                $script:sessions = @{}
                $script:primarysession = $null
            }
            Mock Invoke-RestMethod { return @{ token = "abc123" } } -ModuleName IBMStorageVirtualize
        }

        It "Should disable certificate validation by default" {
            Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -Credential $script:pwsh_cred

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result.Cluster           | Should -Be "1.1.1.11"
            $result.Domain            | Should -BeNullOrEmpty
            $result.Primary           | Should -BeFalse
            $result.ValidateCerts     | Should -BeFalse
            $result.AuthType          | Should -Be "Credential (Not Cached)"
            $result.AutoAddHostKey    | Should -BeFalse
        }

        It "Should enable certificate validation when ValidateCerts switch is specified" {
            Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -Credential $script:pwsh_cred -ValidateCerts

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result.Cluster           | Should -Be "1.1.1.11"
            $result.Domain            | Should -BeNullOrEmpty
            $result.Primary           | Should -BeFalse
            $result.ValidateCerts     | Should -BeTrue
            $result.AuthType          | Should -Be "Credential (Not Cached)"
            $result.AutoAddHostKey    | Should -BeFalse
        }
    }

    Context "Credential Caching" {
        BeforeEach {
            InModuleScope IBMStorageVirtualize {
                $script:sessions = @{}
                $script:primarysession = $null
            }
            Mock Invoke-RestMethod { return @{ token = "abc123" } } -ModuleName IBMStorageVirtualize
        }

        It "Should not cache credential by default" {
            Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -Credential $script:pwsh_cred

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result.Credential | Should -BeNullOrEmpty
            $result.SecretName | Should -BeNullOrEmpty
            $result.AuthType   | Should -Be "Credential (Not Cached)"
        }

        It "Should cache credential when AllowCredentialCaching is specified" {
            Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -Credential $script:pwsh_cred -AllowCredentialCaching

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result.Credential | Should -BeNullOrEmpty
            $result.SecretName | Should -BeNullOrEmpty
            $result.AuthType | Should -Be "Credential (Cached)"
        }
    }

    Context "Secret-based Authentication" {
        BeforeEach {
            InModuleScope IBMStorageVirtualize {
                $script:sessions = @{}
                $script:primarysession = $null
            }
            Mock Invoke-RestMethod { return @{ token = "abc123" } } -ModuleName IBMStorageVirtualize
        }

        It "Should throw error when SecretManagement module is not available" {
            Mock Get-Command { return $null } -ModuleName IBMStorageVirtualize -ParameterFilter { $Name -eq 'Get-Secret' }

            { Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -SecretName "test-secret" } | Should -Throw "SecretManagement module not available. Install: Install-Module Microsoft.PowerShell.SecretManagement"
        }

        It "Should retrieve credential from default vault when SecretName is provided" {
            Mock Get-Command { return @{ Name = 'Get-Secret' } } -ModuleName IBMStorageVirtualize -ParameterFilter { $Name -eq 'Get-Secret' }
            Mock Get-Secret { return $script:pwsh_cred } -ModuleName IBMStorageVirtualize

            Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -SecretName "test-secret"

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result.AuthType | Should -Be "Secret"
            $result.SecretName | Should -Be "test-secret"
            $result.VaultName | Should -BeNullOrEmpty
        }

        It "Should retrieve credential from specific vault when VaultName is provided" {
            Mock Get-Command { return @{ Name = 'Get-Secret' } } -ModuleName IBMStorageVirtualize -ParameterFilter { $Name -eq 'Get-Secret' }
            Mock Get-Secret { return $script:pwsh_cred } -ModuleName IBMStorageVirtualize

            Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -SecretName "test-secret" -VaultName "MyVault"

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result.AuthType | Should -Be "Secret"
            $result.SecretName | Should -Be "test-secret"
            $result.VaultName | Should -Be "MyVault"
        }

        It "Should throw error when secret is not a PSCredential" {
            Mock Get-Command { return @{ Name = 'Get-Secret' } } -ModuleName IBMStorageVirtualize -ParameterFilter { $Name -eq 'Get-Secret' }
            Mock Get-Secret { return "not-a-credential" } -ModuleName IBMStorageVirtualize

            { Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -SecretName "test-secret" } | Should -Throw "Secret 'test-secret' is not a PSCredential."
        }

        It "Should throw error when secret does not exist" {
            Mock Get-Command { return @{ Name = 'Get-Secret' } } -ModuleName IBMStorageVirtualize -ParameterFilter { $Name -eq 'Get-Secret' }
            Mock Get-Secret { throw "Secret not found" } -ModuleName IBMStorageVirtualize

            { Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -SecretName "nonexistent-secret" } | Should -Throw "Failed to retrieve secret*"
        }

        It "Should throw error when SecretStore is locked" {
            Mock Get-Command { return @{ Name = 'Get-Secret' } } -ModuleName IBMStorageVirtualize -ParameterFilter { $Name -eq 'Get-Secret' }
            Mock Get-Secret { throw "The secret vault MyVault is locked" } -ModuleName IBMStorageVirtualize

            { Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -SecretName "test-secret" } | Should -Throw "SecretStore is locked. Run Unlock-SecretStore or configure non-interactive mode."
        }

        It "Should store SecretName and VaultName in session for token refresh" {
            Mock Get-Command { return @{ Name = 'Get-Secret' } } -ModuleName IBMStorageVirtualize -ParameterFilter { $Name -eq 'Get-Secret' }
            Mock Get-Secret { return $script:pwsh_cred } -ModuleName IBMStorageVirtualize

            Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -SecretName "test-secret" -VaultName "MyVault"

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result.AuthType   | Should -Be "Secret"
            $result.SecretName | Should -Be "test-secret"
            $result.VaultName  | Should -Be "MyVault"
        }
    }

    Context "Plugin Registration" {
        BeforeEach {
            InModuleScope IBMStorageVirtualize {
                $script:sessions = @{}
                $script:primarysession = $null
            }
            Mock Invoke-RestMethod { return @{ token = "abc123" } } -ModuleName IBMStorageVirtualize
        }

        It "Should call plugin registration when credential is provided" {
            Mock Invoke-IBMSVPluginRegistration { return @{} } -ModuleName IBMStorageVirtualize

            Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -Credential $script:pwsh_cred

            Should -Invoke Invoke-IBMSVPluginRegistration -ModuleName IBMStorageVirtualize -Times 1 -Exactly
        }

        It "Should not fail if plugin registration returns error" {
            Mock Invoke-IBMSVPluginRegistration { return @{ err = "Plugin registration failed" } } -ModuleName IBMStorageVirtualize

            { Connect-IBMStorageVirtualize -Cluster "1.1.1.11" -Credential $script:pwsh_cred } | Should -Not -Throw
        }
    }
}
