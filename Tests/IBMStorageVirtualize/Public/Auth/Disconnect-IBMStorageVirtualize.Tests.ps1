Describe "Disconnect-IBMStorageVirtualize" {

    BeforeEach {
        InModuleScope IBMStorageVirtualize {
            $script:sessions = @{}
            $script:primarysession = $null
        }
    }

    Context "Disconnect specific session" {

        It "Should remove existing session for specified cluster" {
            InModuleScope IBMStorageVirtualize {
                $script:sessions["1.1.1.11"] = @{ Token="abc123"; Primary=$false }
            }
            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result | Should -Not -BeNullOrEmpty

            Disconnect-IBMStorageVirtualize -Cluster "1.1.1.11"

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result | Should -BeNullOrEmpty
        }

        It "Should not throw error when disconnecting non-existent session" {
            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result | Should -BeNullOrEmpty

            { Disconnect-IBMStorageVirtualize -Cluster "1.1.1.11" } | Should -Not -Throw
        }

        It "Should clear primary designation when removing primary session" {
            InModuleScope IBMStorageVirtualize {
                $script:sessions["1.1.1.11"] = @{ Token="abc123"; Primary=$true }
                $script:primarysession = "1.1.1.11"
            }

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result | Should -Not -BeNullOrEmpty
            $result = Get-IBMSVSession -Primary
            $result | Should -Not -BeNullOrEmpty

            Disconnect-IBMStorageVirtualize -Cluster "1.1.1.11"

            $result = Get-IBMSVSession -Cluster "1.1.1.11"
            $result | Should -BeNullOrEmpty
            $result = Get-IBMSVSession -Primary
            $result | Should -BeNullOrEmpty
        }

        It "Should preserves primary designation when removing non-primary session" {
            InModuleScope IBMStorageVirtualize {
                $script:sessions = @{
                    "1.1.1.11" = @{ Token="abc123"; Primary=$true }
                    "1.1.1.12" = @{ Token="xyz789"; Primary=$false }
                }
                $script:primarysession = "1.1.1.11"
            }

            $result = Get-IBMSVSession -Cluster "1.1.1.12"
            $result | Should -Not -BeNullOrEmpty
            $result = Get-IBMSVSession -Primary
            $result | Should -Not -BeNullOrEmpty

            Disconnect-IBMStorageVirtualize -Cluster "1.1.1.12"

            $result = Get-IBMSVSession -Cluster "1.1.1.12"
            $result | Should -BeNullOrEmpty
            $result = Get-IBMSVSession -Primary
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Disconnect all sessions" {
        It "Should remove all sessions and clears primary designation" {
            InModuleScope IBMStorageVirtualize {
                $script:sessions = @{
                    "1.1.1.11" = @{ Token="abc123"; Primary=$true;  Cluster="1.1.1.11" }
                    "1.1.1.12" = @{ Token="xyz789"; Primary=$false; Cluster="1.1.1.12" }
                }
                $script:primarysession = "1.1.1.11"
            }

            $result = Get-IBMSVSession
            ($result | Where-Object Cluster -eq "1.1.1.11") | Should -Not -BeNullOrEmpty
            ($result | Where-Object Cluster -eq "1.1.1.12") | Should -Not -BeNullOrEmpty
            $result = Get-IBMSVSession -Primary
            $result | Should -Not -BeNullOrEmpty
            $result.Cluster | Should -Be "1.1.1.11"

            Disconnect-IBMStorageVirtualize

            $result = Get-IBMSVSession
            $result | Should -BeNullOrEmpty
            $result = Get-IBMSVSession -Primary
            $result | Should -BeNullOrEmpty
        }

        It "Should not throw error when no sessions exist" {
            $result = Get-IBMSVSession
            $result | Should -BeNullOrEmpty

            { Disconnect-IBMStorageVirtualize } | Should -Not -Throw
        }
    }
}
