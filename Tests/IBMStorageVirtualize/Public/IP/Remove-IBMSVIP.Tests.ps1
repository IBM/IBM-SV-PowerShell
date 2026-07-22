Describe "Remove-IBMSVIP Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsip") {
                return @(
                    [pscustomobject]@{
                        id = '0'
                        IP_address = '1.1.1.11'
                        portset_id = '0'
                        portset_name = 'pwsh_portset0'
                    },
                    [pscustomobject]@{
                        id = '1'
                        IP_address = '1.1.1.11'
                        portset_id = '1'
                        portset_name = 'pwsh_portset1'
                    }
                    [pscustomobject]@{
                        id = '2'
                        IP_address = '1.1.1.12'
                        portset_id = '0'
                        portset_name = 'pwsh_portset2'
                    }
                )
            }

            if ($Cmd -eq "rmip") {
                return $null
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when multiple IPs found without Portset specifed" {
        { Remove-IBMSVIP -IPAddress "1.1.1.11" -Confirm:$false } | Should -Throw "Multiple IP addresses found with '1.1.1.11'. Please specify -Portset to identify the target."
    }

    It "Should not remove IP when -WhatIf is specified" {
        Remove-IBMSVIP -IPAddress "1.1.1.11" -Portset "" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should remove an IP address" {
        Remove-IBMSVIP -IPAddress "1.1.1.12" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsip" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmip" -and $CmdArgs -eq '2' }
    }

    It "Should remove an IP address with specific portset" {
        Remove-IBMSVIP -IPAddress "1.1.1.11" -Portset "pwsh_portset1" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsip" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmip" -and $CmdArgs -eq '1' }
    }

    It "Should be idempotent when IP address does not exist" {
        Remove-IBMSVIP -IPAddress "1.1.1.13" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsip" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmip" }
    }

    It "Should be idempotent when IP address does not exist on specified portset" {
        Remove-IBMSVIP -IPAddress "1.1.1.12" -Portset "pwsh_portset0" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsip" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmip" }
    }
}
