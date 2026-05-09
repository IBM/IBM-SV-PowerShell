Describe "Set-IBMSVDNSServer" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {} -ModuleName IBMStorageVirtualize
        $script:callCount = 0
    }

    It "Should throw error when DNS server does not exist" {
        { Set-IBMSVDNSServer -Name 'pwsh_dns0' } | Should -Throw "DNS Server 'pwsh_dns0' does not exist."

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chdnsserver" }
    }

    It "Should throw error when both DNS server and new name not exist" {
        { Set-IBMSVDNSServer -Name 'pwsh_dns0' -NewName 'pwsh_dns1' } | Should -Throw "DNS Server 'pwsh_dns0' does not exist."
    }

    It "Should rename the DNS server when NewName is different" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsdnsserver") {
                $script:callCount++
                if ($script:callCount -eq 1) { return [pscustomobject]@{ name='pwsh_dns0'; IP_address='1.1.1.11' } }
                return $null
            }
            if ($Cmd -eq 'chdnsserver') {
                return [pscustomobject]@{ message = 'DNS server updated successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVDNSServer -Name 'pwsh_dns0' -NewName 'pwsh_dns1' -IpAddress '1.1.1.12'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chdnsserver' -and
                $CmdOpts.name -eq 'pwsh_dns1' -and
                $CmdOpts.ip -eq '1.1.1.12' -and
                $CmdArgs -eq 'pwsh_dns0'
            }
    }

    It "Should not throw error if -Name DNS server does not exist but -NewName DNS server exists and proceed to update other params on -NewName DNS server" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsdnsserver") {
                $script:callCount++
                if ($script:callCount -eq 1) { return $null }
                return [pscustomobject]@{ name='pwsh_dns1'; IP_address='1.1.1.11' }
            }
            if ($Cmd -eq 'chdnsserver') {
                return [pscustomobject]@{ message = 'DNS server updated successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVDNSServer -Name 'pwsh_dns0' -NewName 'pwsh_dns1' -IpAddress '1.1.1.12'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chdnsserver' -and
                $CmdOpts.ip -eq '1.1.1.12' -and
                $CmdArgs -eq 'pwsh_dns1'
            }
    }

    It "Should throw error if both -Name DNS server and -NewName DNS server exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsdnsserver") {
                if ($script:callCount -eq 1) { return [pscustomobject]@{ name='pwsh_dns0'; IP_address='1.1.1.11' } }
                return [pscustomobject]@{ name='pwsh_dns1'; IP_address='1.1.1.12' }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVDNSServer -Name 'pwsh_dns0' -NewName 'pwsh_dns1' -IpAddress '1.1.1.13' } | Should -Throw "Both 'pwsh_dns0' and 'pwsh_dns1' exist. Cannot rename, cannot proceed with other updates."
    }

    It "Should update DNS server name" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsdnsserver") {
                $script:callCount++
                if ($script:callCount -eq 1) { return [pscustomobject]@{ name='pwsh_dns0'; IP_address='1.1.1.11' } }
                return $null
            }
            if ($Cmd -eq 'chdnsserver') {
                return [pscustomobject]@{ message = 'DNS server updated successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVDNSServer -Name 'pwsh_dns0' -NewName 'pwsh_dns1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chdnsserver' -and
                $CmdOpts.name -eq 'pwsh_dns1' -and
                $CmdArgs -eq 'pwsh_dns0'
            }
    }

    It "Should not call API to update DNS server when -WhatIf is specified" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsdnsserver") {
                return [pscustomobject]@{ name='pwsh_dns0'; IP_address='1.1.1.11' }
            }
            if ($Cmd -eq 'chdnsserver') {
                return [pscustomobject]@{ message = 'DNS server updated successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVDNSServer -Name 'pwsh_dns0' -IpAddress "1.1.1.12" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chdnsserver" }
    }

    It "Should update DNS server IP address" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsdnsserver") {
                return [pscustomobject]@{ name='pwsh_dns0'; IP_address='1.1.1.11' }
            }
            if ($Cmd -eq 'chdnsserver') {
                return [pscustomobject]@{ message = 'DNS server updated successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVDNSServer -Name 'pwsh_dns0' -IpAddress "1.1.1.12"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chdnsserver' -and
                $CmdOpts.ip -eq '1.1.1.12' -and
                $CmdArgs -eq 'pwsh_dns0'
            }
    }

    It "Should be idempotent when updating DNS server name and IP address" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsdnsserver") {
                return [pscustomobject]@{ name='pwsh_dns0'; IP_address='1.1.1.11' }
            }
            if ($Cmd -eq 'chdnsserver') {
                return [pscustomobject]@{ message = 'DNS server updated successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVDNSServer -Name 'pwsh_dns1' -NewName 'pwsh_dns1' -IpAddress "1.1.1.11"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chdnsserver" }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsdnsserver") {
                return [pscustomobject]@{ name='pwsh_dns0'; IP_address='1.1.1.11' }
            }
            if ($Cmd -eq 'chdnsserver') {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/chdnsserver/pwsh_dns"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVDNSServer -Name "pwsh_dns0" -IpAddress "1.1.1.12" } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/chdnsserver/pwsh_dns"
    }
}