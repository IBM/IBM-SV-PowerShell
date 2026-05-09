Describe "New-IBMSVDNSServer" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsdnsserver") {
                if ($script:callCount -eq 1) {
                    return [pscustomobject]@{ name='pwsh_dns0'; IP_address='1.1.1.11' }
                }
                return [pscustomobject]@{ name='pwsh_dns0'; IP_address='1.1.1.11' }
            }
            if ($Cmd -eq 'mkdnsserver') {
                return [pscustomobject]@{ message = 'DNS server created successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should not call API to create DNS server when -WhatIf is specified" {
        New-IBMSVDNSServer -IpAddress "1.1.1.11" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should create a DNS server" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsdnsserver") {
                if ($script:callCount -eq 1) { return $null }
                return [pscustomobject]@{ IP_address='1.1.1.11' }
            }
            if ($Cmd -eq 'mkdnsserver') {
                return [pscustomobject]@{ message = 'DNS server created successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVDNSServer -IpAddress "1.1.1.11"
        $result.IP_address | Should -Be '1.1.1.11'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkdnsserver" -and
                $CmdOpts.ip -eq "1.1.1.11"
            }
    }

    It "Should create a DNS server with a name" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsdnsserver") {
                if ($script:callCount -eq 1) { return $null }
                return [pscustomobject]@{ name='pwsh_dns0'; IP_address='1.1.1.11' }
            }
            if ($Cmd -eq 'mkdnsserver') {
                return [pscustomobject]@{ message = 'DNS server created successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVDNSServer -IpAddress "1.1.1.11" -Name "pwsh_dns0"
        $result.IP_address | Should -Be '1.1.1.11'
        $result.name | Should -Be 'pwsh_dns0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
           -ParameterFilter {
                $Cmd -eq "mkdnsserver" -and
                $CmdOpts.ip -eq "1.1.1.11" -and
                $CmdOpts.name -eq "pwsh_dns0"
            }
    }

    It "Should throw error when creating DNS server with existing IP address" {
        { New-IBMSVDNSServer -IpAddress "1.1.1.11" -Name "pwsh_dns1" } | Should -Throw "CMMVC8720E DNS server with the IP '1.1.1.11' already exists with a different name."

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkdnsserver" }
    }

    It "Should throw error when creating DNS server with existing name" {
        { New-IBMSVDNSServer -IpAddress "1.1.1.12" -Name "pwsh_dns0" } | Should -Throw "CMMVC6035E DNS server with the name 'pwsh_dns0' already exists with a different IP address."

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkdnsserver" }
    }

    It "Should be idempotent when creating DNS server" {
        { New-IBMSVDNSServer -IpAddress "1.1.1.11" } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkdnsserver" }
    }

    It "Should be idempotent when creating DNS server with name" {
        { New-IBMSVDNSServer -IpAddress "1.1.1.11" -Name "pwsh_dns0" } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsdnsserver" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkdnsserver" }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsdnsserver") { return $null }
            if ($Cmd -eq 'mkdnsserver') {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/mkdnsserver"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { New-IBMSVDNSServer -IpAddress "1.1.1.12" -Name "pwsh_dns1" } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/mkdnsserver"
    }
}