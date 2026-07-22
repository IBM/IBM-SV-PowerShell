Describe "Remove-IBMSVPartition" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lspartition") {
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    id = '0'
                    replication_policy_name = ''
                }
            }
            if ($Cmd -eq 'rmpartition') {
                return $null
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when DeleteNonPreferredManagementObjects and DeletePreferredManagementObjects are both specified" {
        { Remove-IBMSVPartition -Name 'pwsh_partition0' -DeleteNonPreferredManagementObjects -DeletePreferredManagementObjects -Confirm:$false } | Should -Throw "Parameters -DeleteNonPreferredManagementObjects and -DeletePreferredManagementObjects are mutually exclusive."
    }

    It "Should not call API to remove partition when -WhatIf is specified" {
        Remove-IBMSVPartition -Name "pwsh_partition0" -Confirm:$false -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should not throw error when partition does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lspartition") { return $null }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVPartition -Name "pwsh_partition0" -Confirm:$false } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lspartition" -and $CmdArgs -contains "pwsh_partition0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmpartition" }
    }

    It "Should remove the partition" {
        Remove-IBMSVPartition -Name "pwsh_partition0" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lspartition" -and $CmdArgs -contains "pwsh_partition0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmpartition" -and $CmdArgs -contains "pwsh_partition0" }
    }

    It "Should remove partition with DeleteNonPreferredManagementObjects" {
        Remove-IBMSVPartition -Name "pwsh_partition0" -DeleteNonPreferredManagementObjects -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lspartition" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "rmpartition" -and
                $CmdOpts.deletenonpreferredmanagementobjects -eq $true -and
                $CmdArgs -contains "pwsh_partition0"
            }
    }

    It "Should remove partition with DeletePreferredManagementObjects" {
        Remove-IBMSVPartition -Name "pwsh_partition0" -DeletePreferredManagementObjects -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lspartition" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "rmpartition" -and
                $CmdOpts.deletepreferredmanagementobjects -eq $true -and
                $CmdArgs -contains "pwsh_partition0"
            }
    }

    It "Should retry if connection refused error occurred after the deletion the partition" {
        $script:rmCallCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lspartition") {
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    id = '0'
                    replication_policy_name = ''
                }
            }
            if ($Cmd -eq 'rmpartition') {
                $script:rmCallCount++
                if ($script:rmCallCount -eq 1) {
                    return [pscustomobject]@{
                        url  = "https://1.1.1.1:7443/rest/v1/rmpartition/pwsh_partition0"
                        code = -1
                        err  = "HTTPError: An error occurred while sending the request."
                        out  = "An error occurred while sending the request."
                        data = @{}
                    }
                }
                if ($script:rmCallCount -eq 2) {
                    return [pscustomobject]@{
                        url  = "https://1.1.1.1:7443/rest/v1/rmpartition/pwsh_partition0"
                        code = -1
                        err  = "HTTPError: Connection refused (1.1.1.1:7443)"
                        out  = "Connection refused (1.1.1.1:7443)"
                        data = @{}
                    }
                }
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        Remove-IBMSVPartition -Name "pwsh_partition0" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lspartition" -and $CmdArgs -contains "pwsh_partition0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 3 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmpartition" -and $CmdArgs -contains "pwsh_partition0" }
    }
}
