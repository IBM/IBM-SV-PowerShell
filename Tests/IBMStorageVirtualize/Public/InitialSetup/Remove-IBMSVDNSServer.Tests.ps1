Describe "Remove-IBMSVDNSServer" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsdnsserver") {
                return [pscustomobject]@{ name='pwsh_dns0'; IP_address='1.1.1.11' }
            }
            if ($Cmd -eq 'rmdnsserver') {
                return [pscustomobject]@{ message = 'DNS server removed successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should not call API to remove DNS server when -WhatIf is specified" {
        Remove-IBMSVDNSServer -Name "pwsh_dns0" -Confirm:$false -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should not throw error when DNS server does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsdnsserver") { return $null }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVDNSServer -Name "pwsh_dns0" -Confirm:$false } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" -and $CmdArgs -contains "pwsh_dns0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmdnsserver" }
    }

    It "Should remove the DNS server" {
        Remove-IBMSVDNSServer -Name "pwsh_dns0" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" -and $CmdArgs -contains "pwsh_dns0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmdnsserver" -and $CmdArgs -contains "pwsh_dns0" }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsdnsserver") {
                return [pscustomobject]@{ name='pwsh_dns0'; IP_address='1.1.1.11' }
            }
            if ($Cmd -eq 'rmdnsserver') {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/rmdnserver/pwsh_dns"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVDNSServer -Name "pwsh_dns0" -Confirm:$false } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/rmdnserver/pwsh_dns"
    }
}
