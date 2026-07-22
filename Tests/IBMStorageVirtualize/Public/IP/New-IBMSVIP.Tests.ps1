Describe "New-IBMSVIP Tests" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsip") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                return @(
                    [pscustomobject]@{
                        id = '0'
                        node_id = '1'
                        node_name = 'node1'
                        port_id = '1'
                        portset_id = '0'
                        portset_name = 'pwsh_portset0'
                        IP_address = '1.1.1.11'
                        prefix = '20'
                        vlan = ''
                        gateway = '1.1.1.1'
                    }
                )
            }

            if ($Cmd -eq "mkip") {
                return [pscustomobject]@{ id = '0'; message = 'IP Address, id [0], successfully created' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when neither Portset nor Node/Port is specified" {
        { New-IBMSVIP -IPAddress "1.1.1.11" -SubnetPrefix 24 } | Should -Throw "Specify -Portset for creating management IP, or specify atleast one of -Node or -Port."
    }

    It "Should throw error when Port is specified without Node" {
        { New-IBMSVIP -IPAddress "1.1.1.11" -SubnetPrefix 24 -Port 1 } | Should -Throw "Parameter -Port requires -Node to be specified."
    }

    It "Should throw error when ShareIP is specified without Portset" {
        { New-IBMSVIP -IPAddress "1.1.1.11" -SubnetPrefix 24 -Node "node1" -Port 1 -ShareIP } | Should -Throw "Parameter -ShareIP requires -Portset to be specified."
    }

    It "Should not create IP when -WhatIf is specified" {
        New-IBMSVIP -IPAddress "1.1.1.11" -SubnetPrefix 20 -Node "node1" -Port 1 -Gateway "1.1.1.1" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should create an IP address with Node and Port" {
        $result = New-IBMSVIP -IPAddress "1.1.1.11" -SubnetPrefix 20 -Node "node1" -Port 1 -Gateway "1.1.1.1"
        $result.IP_address | Should -Be '1.1.1.11'
        $result.prefix | Should -Be '20'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsip" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkip" -and
                $CmdOpts.ip -eq "1.1.1.11" -and
                $CmdOpts.prefix -eq 20 -and
                $CmdOpts.node -eq "node1" -and
                $CmdOpts.port -eq 1 -and
                $CmdOpts.gw -eq "1.1.1.1"
            }
    }

    It "Should create a IP address with Portset" {
        $result = New-IBMSVIP -IPAddress "1.1.1.11" -SubnetPrefix 20 -Portset "pwsh_portset0"
        $result.IP_address | Should -Be '1.1.1.11'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkip" -and
                $CmdOpts.ip -eq "1.1.1.11" -and
                $CmdOpts.prefix -eq 20 -and
                $CmdOpts.portset -eq "pwsh_portset0"
            }
    }

    It "Should create a shared IP address" {
        $result = New-IBMSVIP -IPAddress "1.1.1.11" -SubnetPrefix 20 -Portset "pwsh_portset0" -ShareIP
        $result.IP_address | Should -Be '1.1.1.11'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkip" -and
                $CmdOpts.ip -eq "1.1.1.11" -and
                $CmdOpts.prefix -eq 20 -and
                $CmdOpts.portset -eq "pwsh_portset0" -and
                $CmdOpts.shareip -eq $true
            }
    }

    It "Should create an IP address with all parameters" {
        $result = New-IBMSVIP -IPAddress "1.1.1.11" -SubnetPrefix 20 -Node "node1" -Port 1 -Gateway "1.1.1.1" -Vlan 100 -Portset "pwsh_portset0"
        $result.IP_address | Should -Be '1.1.1.11'
        $result.prefix | Should -Be '20'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsip" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkip" -and
                $CmdOpts.ip -eq "1.1.1.11" -and
                $CmdOpts.prefix -eq 20 -and
                $CmdOpts.node -eq "node1" -and
                $CmdOpts.port -eq 1 -and
                $CmdOpts.gw -eq "1.1.1.1" -and
                $CmdOpts.vlan -eq 100
            }
    }

    It "Should be idempotent when IP already exists on the specified portset" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsip") {
                return @(
                    [pscustomobject]@{
                        id = '0'
                        node_id = '1'
                        node_name = 'node1'
                        port_id = '1'
                        portset_id = '0'
                        portset_name = 'pwsh_portset0'
                        IP_address = '1.1.1.11'
                        prefix = '20'
                        vlan = ''
                        gateway = ''
                    }
                )
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVIP -IPAddress "1.1.1.11" -SubnetPrefix 20 -Portset "pwsh_portset0"
        $result.IP_address | Should -Be '1.1.1.11'
        $result.prefix | Should -Be '20'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsip" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkip" }
    }
}
