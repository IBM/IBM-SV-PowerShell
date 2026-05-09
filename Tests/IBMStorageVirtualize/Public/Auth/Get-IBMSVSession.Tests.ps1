# PSScriptAnalyzer SuppressMessageAttribute
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'Plaintext SecureString is acceptable for unit tests.'
)]
param()
Describe "Get-IBMSVSession" {
    BeforeEach {
        $script:pwsh_cred = New-Object System.Management.Automation.PSCredential ("pwsh_user", (ConvertTo-SecureString "pwsh_pass" -AsPlainText -Force))

        InModuleScope IBMStorageVirtualize {
            $script:sessions = @{}
            $script:primarysession = $null
        }
    }

    Context "Cluster lookup" {
        It "Should return session for specified cluster" {
            InModuleScope IBMStorageVirtualize -Parameters @{ cred = $script:pwsh_cred }{
                $script:sessions = @{
                    "1.1.1.11" = @{
                        Cluster = "1.1.1.11"
                        Domain = ""
                        Credential = $cred
                        Token = "abc123"
                        ValidateCerts = $false
                        Primary = $false
                        LastRestAuthTime = "01/01/2026 12:00:00 AM"
                        SVCVersion = $null
                        SecretName = $null
                        VaultName = $null
                    }
                }
                $script:primarysession = $null
            }

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result.Cluster       | Should -Be "1.1.1.11"
            $result.Domain        | Should -BeNullOrEmpty
            $result.Primary       | Should -BeFalse
            $result.ValidateCerts | Should -BeFalse
            $result.AuthType      | Should -Be "Credential (Cached)"
            $result.SVCVersion    | Should -BeNullOrEmpty
            $result.SecretName    | Should -BeNullOrEmpty
            $result.VaultName     | Should -BeNullOrEmpty
        }

        It "Should return null without error when cluster does not exist" {
            { Get-IBMSVSession -Cluster "1.1.1.11" } | Should -not -Throw
        }
    }

    Context "Primary Cluster lookup" {
        It "Should return primary session using Primary switch" {
            InModuleScope IBMStorageVirtualize -Parameters @{ cred = $script:pwsh_cred }{
                $script:sessions = @{
                    "1.1.1.11" = @{
                        Cluster = "1.1.1.11"
                        Domain = ""
                        Credential = $cred
                        Token = "abc123"
                        ValidateCerts = $false
                        Primary = $true
                        LastRestAuthTime = "01/01/2026 12:00:00 AM"
                        SVCVersion = $null
                        SecretName = $null
                        VaultName = $null
                    }
                }
                $script:primarysession = "1.1.1.11"
            }

            $result = Get-IBMSVSession -Primary
            $result.Cluster       | Should -Be "1.1.1.11"
            $result.Domain        | Should -BeNullOrEmpty
            $result.Primary       | Should -BeTrue
            $result.ValidateCerts | Should -BeFalse
            $result.AuthType      | Should -Be "Credential (Cached)"
            $result.SVCVersion    | Should -BeNullOrEmpty
            $result.SecretName    | Should -BeNullOrEmpty
            $result.VaultName     | Should -BeNullOrEmpty
        }

        It "Should return null without error when no primary session exists" {
            { Get-IBMSVSession -Primary } | Should -not -Throw
        }
    }

    Context "No cluster argument" {
        It "Should return all sessions when no parameters specified" {
            InModuleScope IBMStorageVirtualize -Parameters @{ cred = $script:pwsh_cred }{
                $script:sessions = @{
                    "1.1.1.11" = @{
                        Cluster = "1.1.1.11"
                        Domain = ""
                        Credential = $cred
                        Token = "abc123"
                        ValidateCerts = $false
                        LastRestAuthTime = "01/01/2026 12:00:00 AM"
                        Primary = $true
                        SVCVersion = $null
                        SecretName = $null
                        VaultName = $null
                    }
                    "1.1.1.12" = @{
                        Cluster = "1.1.1.12"
                        Domain = ""
                        Credential = $null
                        Token = "abc123"
                        ValidateCerts = $false
                        LastRestAuthTime = "01/01/2026 12:00:00 AM"
                        Primary = $false
                        SVCVersion = $null
                        SecretName = "test_secret"
                        VaultName = "test_vault"
                    }
                }
                $script:primarysession = "1.1.1.11"
            }

            $result = Get-IBMSVSession
            $result.Count | Should -Be 2
            ($result | Where-Object Cluster -eq "1.1.1.11").Cluster       | Should -Be "1.1.1.11"
            ($result | Where-Object Cluster -eq "1.1.1.11").Domain        | Should -BeNullOrEmpty
            ($result | Where-Object Cluster -eq "1.1.1.11").Primary       | Should -BeTrue
            ($result | Where-Object Cluster -eq "1.1.1.11").ValidateCerts | Should -BeFalse
            ($result | Where-Object Cluster -eq "1.1.1.11").AuthType      | Should -Be "Credential (Cached)"
            ($result | Where-Object Cluster -eq "1.1.1.11").SVCVersion    | Should -BeNullOrEmpty
            ($result | Where-Object Cluster -eq "1.1.1.11").SecretName    | Should -BeNullOrEmpty
            ($result | Where-Object Cluster -eq "1.1.1.11").VaultName     | Should -BeNullOrEmpty

            ($result | Where-Object Cluster -eq "1.1.1.12").Cluster       | Should -Be "1.1.1.12"
            ($result | Where-Object Cluster -eq "1.1.1.12").Domain        | Should -BeNullOrEmpty
            ($result | Where-Object Cluster -eq "1.1.1.12").Primary       | Should -BeFalse
            ($result | Where-Object Cluster -eq "1.1.1.12").ValidateCerts | Should -BeFalse
            ($result | Where-Object Cluster -eq "1.1.1.12").AuthType      | Should -Be "Secret"
            ($result | Where-Object Cluster -eq "1.1.1.12").SVCVersion    | Should -BeNullOrEmpty
            ($result | Where-Object Cluster -eq "1.1.1.12").SecretName    | Should -Be "test_secret"
            ($result | Where-Object Cluster -eq "1.1.1.12").VaultName     | Should -Be "test_vault"

        }

        It "Should return null when no sessions exist" {
            $result = Get-IBMSVSession
            $result.Count | Should -Be 0
        }
    }
}
