Describe "Remove-IBMSVReplicationPolicy Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsreplicationpolicy') {
                return [pscustomobject]@{ name = 'pwsh_rp0'; id = '0'; topology = '2-site-async-dr' }
            }

            if ($Cmd -eq 'rmreplicationpolicy') {
                return $null
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should not call API to remove replication policy when -WhatIf is specified" {
        Remove-IBMSVReplicationPolicy -Name "pwsh_rp0" -Confirm:$false -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should not throw error when replication policy does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsreplicationpolicy') {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVReplicationPolicy -Name "pwsh_rp0" -Confirm:$false } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsreplicationpolicy" -and $CmdArgs -eq "pwsh_rp0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'rmreplicationpolicy' }
    }

    It "Should remove replication policy successfully" {
        Remove-IBMSVReplicationPolicy -Name "pwsh_rp0" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsreplicationpolicy" -and $CmdArgs -eq "pwsh_rp0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmreplicationpolicy" -and $CmdArgs -eq "pwsh_rp0" }
    }
}

