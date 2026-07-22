Describe "Set-IBMSVIP Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsip") {
                return @(
                    [pscustomobject]@{
                        id = '1'
                        node_id = '1'
                        node_name = 'node1'
                        port_id = '2'
                        portset_id = '0'
                        portset_name = 'portset0'
                        IP_address = '1.1.1.11'
                        prefix = '24'
                        vlan = ''
                        gateway = ''
                    }
                    [pscustomobject]@{
                        id = '2'
                        node_id = '1'
                        node_name = 'node1'
                        port_id = '2'
                        portset_id = '0'
                        portset_name = 'portset1'
                        IP_address = '1.1.1.12'
                        prefix = '24'
                        vlan = '50'
                        gateway = '1.1.1.1'
                    }
                )
            }

            if ($Cmd -eq "chip") {
                return $null
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when Gateway and ResetGateway are both specified" {
        { Set-IBMSVIP -IPAddress "1.1.1.11" -Gateway "10.1.1.1" -ResetGateway } | Should -Throw "Parameters -Gateway and -ResetGateway are mutually exclusive."
    }

    It "Should throw error when Vlan and ResetVlan are both specified" {
        { Set-IBMSVIP -IPAddress "1.1.1.11" -Vlan 100 -ResetVlan } | Should -Throw "Parameters -Vlan and -ResetVlan are mutually exclusive."
    }

    It "Should throw error when IP address does not exist" {
        { Set-IBMSVIP -IPAddress "1.1.1.13" -SubnetPrefix 24 } | Should -Throw "IP address '1.1.1.13' does not exist."
    }

    It "Should throw error when IP address does not exist on specified portset" {
        { Set-IBMSVIP -IPAddress "1.1.1.11" -SubnetPrefix 24 -Portset "portset1" } | Should -Throw "IP address '1.1.1.11' with portset 'portset1' does not exist."
    }

    It "Should throw error when both IP and new IP addresses exit" {
        { Set-IBMSVIP -IPAddress "1.1.1.11" -NewIPAddress "1.1.1.12" -SubnetPrefix 20 } | Should -Throw "Both IP '1.1.1.11' and '1.1.1.12' exist. Cannot update IP address."
    }

    It "Should not update IP when -WhatIf is specified" {
        Set-IBMSVIP -IPAddress "1.1.1.11" -SubnetPrefix 20 -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chip" }
    }

    It "Should continue updating NewIPAddres propereties when old IP does not exist but new IP exists" {
        Set-IBMSVIP -IPAddress "1.1.1.13" -NewIPAddress "1.1.1.12" -SubnetPrefix 28

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chip" -and
                $CmdOpts.ip -eq "1.1.1.12" -and
                $CmdOpts.prefix -eq 28 -and
                $CmdArgs -eq '2'
            }
    }

    It "Should update/change IP address to new IP address" {
        Set-IBMSVIP -IPAddress "1.1.1.11" -NewIPAddress "1.1.1.13"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsip" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chip" -and
                $CmdOpts.ip -eq "1.1.1.13" -and
                $CmdOpts.prefix -eq 24 -and
                $CmdArgs -eq '1'
            }
    }

    It "Should update/change IP address to new IP address and retain existing gateway and vlan" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsip") {
                return @(
                    [pscustomobject]@{
                        id = '1'
                        node_id = '1'
                        node_name = 'node1'
                        port_id = '2'
                        portset_id = '0'
                        portset_name = 'portset0'
                        IP_address = '1.1.1.11'
                        prefix = '24'
                        vlan = '50'
                        gateway = '1.1.1.1'
                    }
                )
            }

            if ($Cmd -eq "chip") {
                return $null
            }
        } -ModuleName IBMStorageVirtualize
        Set-IBMSVIP -IPAddress "1.1.1.11" -NewIPAddress "1.1.1.13"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsip" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chip" -and
                $CmdOpts.ip -eq "1.1.1.13" -and
                $CmdOpts.prefix -eq 24 -and
                $CmdOpts.gw -eq "1.1.1.1" -and
                $CmdOpts.vlan -eq 50 -and
                $CmdArgs -eq '1'
            }
    }

    It "Should update subnet prefix and vlan" {
        Set-IBMSVIP -IPAddress "1.1.1.11" -SubnetPrefix 28 -Vlan 70

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chip" -and
                $CmdOpts.ip -eq "1.1.1.11" -and
                $CmdOpts.prefix -eq 28 -and
                $CmdOpts.vlan -eq 70 -and
                $CmdArgs -eq '1'
            }
    }


    It "Should reset both gateway and VLAN" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsip") {
                return @(
                    [pscustomobject]@{
                        id = '1'
                        node_id = '1'
                        node_name = 'node1'
                        port_id = '2'
                        portset_id = '0'
                        portset_name = 'portset0'
                        IP_address = '1.1.1.11'
                        prefix = '24'
                        vlan = '50'
                        gateway = '1.1.1.1'
                    }
                )
            }
            if ($Cmd -eq "chip") {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVIP -IPAddress "1.1.1.11" -ResetGateway -ResetVlan

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chip" -and
                $CmdOpts.ip -eq "1.1.1.11" -and
                $CmdOpts.prefix -eq '24' -and
                -not $CmdOpts.ContainsKey('gw') -and
                -not $CmdOpts.ContainsKey('vlan') -and
                $CmdArgs -eq '1'
            }
    }

    It "Should update multiple properties of Ip at once" {
        Set-IBMSVIP -IPAddress "1.1.1.11" -NewIPAddress "1.1.1.13" -SubnetPrefix 28 -Gateway "1.1.1.1" -Vlan 70

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chip" -and
                $CmdOpts.ip -eq "1.1.1.13" -and
                $CmdOpts.prefix -eq 28 -and
                $CmdOpts.gw -eq "1.1.1.1" -and
                $CmdOpts.vlan -eq 70 -and
                $CmdArgs -eq '1'
            }
    }

    It "Should be idempotent when no changes are required" {
        Set-IBMSVIP -IPAddress "1.1.1.13" -NewIPAddress "1.1.1.12" -SubnetPrefix 24 -Gateway "1.1.1.1" -Vlan 50

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsip" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chip" }
    }
}
