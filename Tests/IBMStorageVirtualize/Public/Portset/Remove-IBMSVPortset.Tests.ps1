Describe "Remove-IBMSVPortset Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsportset') {
                return [pscustomobject]@{ name='pwsh_ps0'; id='0'; type='host' }
            }
            if ($Cmd -eq 'rmportset') {
                return $null
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should not call API to remove portset when -WhatIf is specified" {
        Remove-IBMSVPortset -Name "pwsh_ps0" -Confirm:$false -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should remove the portset" {
        Remove-IBMSVPortset -Name "pwsh_ps0" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsportset" -and $CmdArgs -contains "pwsh_ps0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmportset" -and $CmdArgs -eq "pwsh_ps0" }
    }

    It "Should be idempotent when portset does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsportset') {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        Remove-IBMSVPortset -Name "pwsh_ps0" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsportset" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'rmportset' }
    }
}
