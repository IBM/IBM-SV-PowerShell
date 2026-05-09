Describe "Remove-IBMSVHost" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lshost') {
                return [pscustomobject]@{ name='pwsh_host'; id='0' }
            }
            if ($Cmd -eq 'rmhost') {
                return @{}
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should not call API to remove host when -WhatIf is specified" {
        Remove-IBMSVHost -Name "pwsh_host" -Confirm:$false -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should not throw error when host does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lshost') {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVHost -Name "pwsh_host" -Confirm:$false } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lshost" -and $CmdArgs -contains "pwsh_host" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'rmhost' }
    }

    It "Should remove the host" {
        Remove-IBMSVHost -Name "pwsh_host" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lshost" -and $CmdArgs -contains "pwsh_host" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmhost" -and $CmdArgs -eq "pwsh_host" }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lshost') {
                return [pscustomobject]@{ name='pwsh_host'; id='0' }
            }
            if ($Cmd -eq 'rmhost') {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/rmhost/pwsh_host"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVHost -Name "pwsh_host" -Confirm:$false } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/rmhost/pwsh_host"
    }
}
