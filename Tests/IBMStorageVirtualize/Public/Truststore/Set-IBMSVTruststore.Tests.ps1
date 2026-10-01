Describe "Set-IBMSVTruststore Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd, $CmdArgs)
            if ($Cmd -eq "lstruststore") {
                return [pscustomobject]@{
                    id = '1'
                    name = $CmdArgs
                    vasa = 'off'
                    restapi = 'off'
                    ipsec = 'off'
                    email = 'off'
                    snmp = 'off'
                    syslog = 'off'
                }
            }
            if ($Cmd -eq "chtruststore") {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        $script:callCount = 0
    }

    It "Should throw error when -Export is used with other modification parameters" {
        { Set-IBMSVTruststore -Name "pwsh_ts0" -Export -RestAPI "on" } | Should -Throw "-Export is mutually exclusive with other parameters."
    }

    It "Should throw error when -RemoteTruststoreName is used without -RemoteCluster" {
        { Set-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" } | Should -Throw "-RemoteTruststoreName is not applicable when -RemoteCluster is not specified."
    }

    It "Should throw error when truststore doesn't exist on local cluster" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lstruststore") {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVTruststore -Name "trust_nonexistent" -RestAPI "on" } | Should -Throw "Truststore 'trust_nonexistent' does not exist on cluster*."
    }

    It "Should throw error when truststore doesn't exist on remote cluster" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lstruststore") {
                if ($script:callCount -eq 1) {
                    return [pscustomobject]@{ id = '1'; name = 'pwsh_ts0' }
                }
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Vasa "on" } | Should -Throw "Truststore 'pwsh_ts1' does not exist on secondary cluster '10.10.10.20'."
    }

    It "Should not call API to modify truststore when -WhatIf is specified" {
        Set-IBMSVTruststore -Name "pwsh_ts0" -RestAPI "on" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chtruststore" }
    }

    Context "Single Cluster Modification" {
        It "Should export truststore certificate" {
            Set-IBMSVTruststore -Name "pwsh_ts0" -Export

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "chtruststore" -and
                    $CmdOpts.export -eq $true -and
                    $CmdArgs -eq "pwsh_ts0"
                }
        }

        It "Should enable RestAPI on local cluster" {
            Set-IBMSVTruststore -Name "pwsh_ts0" -RestAPI "on"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "chtruststore" -and
                    $CmdOpts.restapi -eq "on" -and
                    $CmdArgs -eq "pwsh_ts0"
                }
        }

        It "Should update multiple properties at once" {
            Set-IBMSVTruststore -Name "pwsh_ts0" -Vasa "on" -RestAPI "on" -IpSec "on" -Email "on" -SNMP "on" -Syslog "on"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "chtruststore" -and
                    $CmdOpts.vasa -eq "on" -and
                    $CmdOpts.restapi -eq "on" -and
                    $CmdOpts.ipsec -eq "on" -and
                    $CmdOpts.email -eq "on" -and
                    $CmdOpts.snmp -eq "on" -and
                    $CmdOpts.syslog -eq "on" -and
                    $CmdArgs -eq "pwsh_ts0"
                }
        }
    }

    Context "Dual Cluster Modification" {
        It "Should export truststore certificate from both clusters" {
            Set-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Export

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "chtruststore" -and $CmdOpts.export -eq $true -and $CmdArgs -eq "pwsh_ts0" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "chtruststore" -and $CmdOpts.export -eq $true -and $CmdArgs -eq "pwsh_ts1" }
        }

        It "Should update truststores on both clusters" {
            Set-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -RestAPI "on"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lstruststore" -and $CmdArgs -eq "pwsh_ts0"}
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "lstruststore" -and $CmdArgs -eq "pwsh_ts1"}

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "chtruststore" -and $CmdOpts.restapi -eq "on" -and $CmdArgs -eq "pwsh_ts0" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "chtruststore" -and $CmdOpts.restapi -eq "on" -and $CmdArgs -eq "pwsh_ts1" }
        }

        It "Should update multiple properties at once" {
            Set-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Vasa "on" -RestAPI "on" -IpSec "on" -Email "on" -SNMP "on" -Syslog "on"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "chtruststore" -and
                    $CmdOpts.vasa -eq "on" -and
                    $CmdOpts.restapi -eq "on" -and
                    $CmdOpts.ipsec -eq "on" -and
                    $CmdOpts.email -eq "on" -and
                    $CmdOpts.snmp -eq "on" -and
                    $CmdOpts.syslog -eq "on" -and
                    $CmdArgs -eq "pwsh_ts0"
                }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "10.10.10.20" -and
                    $Cmd -eq "chtruststore" -and
                    $CmdOpts.vasa -eq "on" -and
                    $CmdOpts.restapi -eq "on" -and
                    $CmdOpts.ipsec -eq "on" -and
                    $CmdOpts.email -eq "on" -and
                    $CmdOpts.snmp -eq "on" -and
                    $CmdOpts.syslog -eq "on" -and
                    $CmdArgs -eq "pwsh_ts1"
                }
        }

        It "Should be idempotent when no changes are needed" {
            Set-IBMSVTruststore -Name "pwsh_ts0" -Vasa "off" -RestAPI "off" -IpSec "off" -Email "off" -SNMP "off" -Syslog "off"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lstruststore" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "chtruststore" }
        }

        It "Should update truststore on remote cluster only when local is already configured" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd, $CmdArgs)
                $script:callCount++
                if ($Cmd -eq "lstruststore") {
                    if ($script:callCount -eq 1) {
                        return [pscustomobject]@{
                            id = '1'
                            name = $CmdArgs
                            vasa = 'off'
                            restapi = 'on'
                            ipsec = 'off'
                            email = 'off'
                            snmp = 'off'
                            syslog = 'off'
                        }
                    }
                    return [pscustomobject]@{
                        id = '1'
                        name = $CmdArgs
                        vasa = 'off'
                        restapi = 'off'
                        ipsec = 'off'
                        email = 'off'
                        snmp = 'off'
                        syslog = 'off'
                    }
                }
                if ($Cmd -eq "chtruststore") {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -RestAPI "on"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lstruststore" -and $CmdArgs -eq "pwsh_ts0" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "lstruststore" -and $CmdArgs -eq "pwsh_ts1" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -ne "10.10.10.20" -and $Cmd -eq "chtruststore" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "chtruststore" -and $CmdOpts.restapi -eq "on" -and $CmdArgs -eq "pwsh_ts1" }
        }

        It "Should use Name for RemoteTruststoreName when not provided" {
            Set-IBMSVTruststore -Name "pwsh_ts0" -RemoteCluster "10.10.10.20" -RestAPI "on"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lstruststore" -and $CmdArgs -eq "pwsh_ts0" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -ne "10.10.10.20" -and $Cmd -eq "chtruststore" -and $CmdOpts.restapi -eq "on" -and $CmdArgs -eq "pwsh_ts0" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "chtruststore" -and $CmdOpts.restapi -eq "on" -and $CmdArgs -eq "pwsh_ts0" }
        }
    }
}
