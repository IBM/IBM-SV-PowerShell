Describe "Remove-IBMSVPool Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdiskgrp") {
                return [pscustomobject]@{ name = 'pwsh_pool'; id = '0'; status = 'online' }
            }
            if ($Cmd -eq 'rmmdiskgrp') {
                return [pscustomobject]@{ message = 'Pool removed successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should not call API to remove pool when -WhatIf is specified" {
        Remove-IBMSVPool -Name "pwsh_pool" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should not attempt to delete pool when it does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdiskgrp") { return $null }
        } -ModuleName IBMStorageVirtualize

        Remove-IBMSVPool -Name "pwsh_pool" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsmdiskgrp" -and $CmdArgs -contains "pwsh_pool" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmmdiskgrp" }
    }

    It "Should remove pool successfully" {
        Remove-IBMSVPool -Name "pwsh_pool" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsmdiskgrp" -and $CmdArgs -contains "pwsh_pool" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmmdiskgrp" -and $CmdArgs -contains "pwsh_pool" }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsmdiskgrp") {
                return [pscustomobject]@{ name = 'pwsh_pool'; id = '0'; status = 'online' }
            }
            if ($Cmd -eq "rmmdiskgrp") {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/rmmdiskgrp/pwsh_pool"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVPool -Name "pwsh_pool" -Confirm:$false } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/rmmdiskgrp/pwsh_pool"
    }
}
