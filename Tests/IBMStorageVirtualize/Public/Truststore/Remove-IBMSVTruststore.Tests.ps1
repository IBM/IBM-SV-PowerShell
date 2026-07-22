Describe "Remove-IBMSVTruststore Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd, $CmdArgs)
            if ($Cmd -eq "lstruststore") {
                return [pscustomobject]@{
                    id = '1'
                    name = $CmdArgs
                }
            }
            if ($Cmd -eq "rmtruststore") {
                return $null
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when -RemoteTruststoreName is used without -RemoteCluster" {
        { Remove-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" } | Should -Throw "-RemoteTruststoreName is not applicable when -RemoteCluster is not specified."
    }

    It "Should not call API to remove truststore when -WhatIf is specified" {
        Remove-IBMSVTruststore -Name "pwsh_vol" -Confirm:$false -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    Context "Single Cluster Removal" {
        It "Should not throw error when truststore doesn't exist" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lstruststore") {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            { Remove-IBMSVTruststore -Name "pwsh_ts0" -Confirm:$false } | Should -Not -Throw

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lstruststore" -and $CmdArgs -contains "pwsh_ts0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "rmtruststore" }
        }

        It "Should remove truststore from local cluster only" {
            Remove-IBMSVTruststore -Name "pwsh_ts0" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lstruststore" -and $CmdArgs -contains "pwsh_ts0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "rmtruststore" -and $CmdArgs -eq "pwsh_ts0" }
        }

    }

    Context "Dual Cluster Removal" {
        It "Should not throw error when truststore doesn't exist" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lstruststore") {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            { Remove-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Confirm:$false } | Should -Not -Throw

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lstruststore" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "rmtruststore" }
        }

        It "Should remove truststores from both clusters" {
            Remove-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -ne "10.10.10.20" -and $Cmd -eq "lstruststore" -and $CmdArgs -eq "pwsh_ts0" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "lstruststore" -and $CmdArgs -eq "pwsh_ts1" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -ne "10.10.10.20" -and $Cmd -eq "rmtruststore" -and $CmdArgs -eq "pwsh_ts0" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "rmtruststore" -and $CmdArgs -eq "pwsh_ts1" }
        }

        It "Should remove truststore on remote cluster only, when local truststore doesn't exist" {
            $script:callCount = 0
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                $script:callCount++

                if ($Cmd -eq "lstruststore") {
                    if ($script:callCount -eq 2) {
                        return [pscustomobject]@{ id = '1'; name = 'pwsh_ts1' }
                    }
                    return $null
                }

                if ($Cmd -eq "rmtruststore") {
                    return [pscustomobject]@{ message = 'Success' }
                }
            } -ModuleName IBMStorageVirtualize

            { Remove-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Confirm:$false } | Should -Not -Throw

           Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -ne "10.10.10.20" -and $Cmd -eq "lstruststore" -and $CmdArgs -eq "pwsh_ts0" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "lstruststore" -and $CmdArgs -eq "pwsh_ts1" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -ne "10.10.10.20" -and $Cmd -eq "rmtruststore" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "rmtruststore" -and $CmdArgs -eq "pwsh_ts1" }
        }

        It "Should remove truststores with same name from both clusters" {
            Remove-IBMSVTruststore -Name "pwsh_ts0" -RemoteCluster "10.10.10.20" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lstruststore" -and $CmdArgs -eq "pwsh_ts0" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -ne "10.10.10.20" -and $Cmd -eq "rmtruststore" -and $CmdArgs -eq "pwsh_ts0" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "rmtruststore" -and $CmdArgs -eq "pwsh_ts0" }
        }
    }
}
