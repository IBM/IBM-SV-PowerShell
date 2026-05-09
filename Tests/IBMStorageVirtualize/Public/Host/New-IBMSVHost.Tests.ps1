Describe "New-IBMSVHost" {
    BeforeEach {
        $script:count = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:count++

            if ($Cmd -eq "lshost") {
                if ($script:count -eq 1) {
                    return $null
                }
                return [pscustomobject]@{ name='pwsh_host'; id='0' }
            }
            if ($Cmd -eq 'mkhost') {
                return [pscustomobject]@{ id='0'; msg='created' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw when duplicate FCWWPNs are passed" {
        { New-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251EE6:210100E08B251EE6' -Protocol 'fcscsi' } | Should -Throw "Duplicate FCWWPN values found: 210100E08B251EE6"
    }

    It "Should throw when multiple initiators are provided (validation enforcement)" {
        { New-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251EE6' -IscsiName "iqn.localhost.hostid.7f000001" } | Should -Throw "You must specify exactly one initiator parameter: -SasWWPN, -FCWWPN, -IscsiName, -Nqn, -FDMIName."
    }

    It "Should throw when no initiators are provided (validation enforcement)" {
        { New-IBMSVHost -Name 'pwsh_host'} | Should -Throw "You must specify exactly one initiator parameter: -SasWWPN, -FCWWPN, -IscsiName, -Nqn, -FDMIName."
    }

    It "Should throw error when HostCluster and OwnershipGroup are both specified" {
        { New-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251EE6' -HostCluster 'pwsh_hc' -OwnershipGroup 'pwsh_og'} | Should -Throw "Parameters -HostCluster and -OwnershipGroup are mutually exclusive."
    }

    It "Should throw error when Partition and SasWWPN are both specified" {
        { New-IBMSVHost -Name 'pwsh_host' -SasWWPN '210100E08B251EE6' -Partition 'pwsh_ptn' } | Should -Throw "Parameters -Partition and -SasWWPN are mutually exclusive."
    }

    It "Should throw error when Partition and IOGrp are both specified" {
        { New-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251EE6' -Partition 'pwsh_ptn' -IOGrp 'io_grp0' } | Should -Throw "Parameters -Partition and -IOGrp are mutually exclusive."
    }

    It "Should throw error when Partition and Site are both specified" {
        { New-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251EE6' -Partition 'pwsh_ptn' -Site 'Site1' } | Should -Throw "Parameters -Partition and -Site are mutually exclusive."
    }

    It "Should throw error when -Nqn used without -Protocol" {
        { New-IBMSVHost -Name 'pwsh_host' -Nqn 'nqn.2014-08.org.nvmexpress:example' } | Should -Throw "Parameters -Nqn is invalid without -Protocol."
    }

    It "Should throw error when -Location used without -Partition" {
        { New-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251EE6' -Location 'pwsh_system' } | Should -Throw "Parameters -Location is invalid without -Partition."
    }

    It "Should throw error when -Nqn used with invalid -Protocol" {
        { New-IBMSVHost -Name 'pwsh_host' -Nqn 'nqn.2014-08.org.nvmexpress:example' -Protocol 'fcscsi' } | Should -Throw "If -Nqn is specified, -Protocol must be one of: tcpnvme, fcnvme, rdmanvme, nvme."
        { New-IBMSVHost -Name 'pwsh_host' -Nqn 'nqn.2014-08.org.nvmexpress:example' -Protocol 'sas' } | Should -Throw "If -Nqn is specified, -Protocol must be one of: tcpnvme, fcnvme, rdmanvme, nvme."
        { New-IBMSVHost -Name 'pwsh_host' -Nqn 'nqn.2014-08.org.nvmexpress:example' -Protocol 'iscsi' } | Should -Throw "If -Nqn is specified, -Protocol must be one of: tcpnvme, fcnvme, rdmanvme, nvme."
    }

    It "Should not call API to create host when -WhatIf is specified" {
        { New-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251EE6' -WhatIf } | Should -Not -Throw
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should create a FC host" {
        $result = New-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251EE6' -Protocol 'fcscsi'
        $result.name | Should -Be 'pwsh_host'
        $result.id   | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lshost" -and $CmdArgs -contains "pwsh_host" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkhost" -and
                $CmdOpts.name -eq "pwsh_host" -and
                $CmdOpts.fcwwpn -eq "210100E08B251EE6" -and
                $CmdOpts.protocol -eq "fcscsi" -and
                $CmdOpts.force -eq $true
            }
    }

    It "Should be idempotent and returns existing host without calling mkhost" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq 'lshost') {
                return [PSCustomObject]@{ name='pwsh_fc_host'; id='1' }
            }

            return $null
        } -ModuleName IBMStorageVirtualize

        $res = New-IBMSVHost -Name 'pwsh_fc_host' -FCWWPN '2100000E1EC2301A' -Protocol 'fcscsi'
        $res.name | Should -Be 'pwsh_fc_host'
        $res.id | Should -Be '1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'lshost' }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'mkhost' }
    }

    It "Should create a tcpnvme host" {
        $result = New-IBMSVHost -Name 'pwsh_host' -Protocol 'tcpnvme' -Nqn 'nqn.2014-08.org.nvmexpress:uuid:449f8291-9c1e-446c-95c1-0942f55fa208'
        $result.name | Should -Be 'pwsh_host'
        $result.id   | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lshost" -and $CmdArgs -contains "pwsh_host" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkhost" -and
                $CmdOpts.name -eq "pwsh_host" -and
                $CmdOpts.nqn -eq "nqn.2014-08.org.nvmexpress:uuid:449f8291-9c1e-446c-95c1-0942f55fa208" -and
                $CmdOpts.protocol -eq "tcpnvme" -and
                $CmdOpts.force -eq $true
            }
    }

    It "Should create a fcnvme host" {
        $result = New-IBMSVHost -Name 'pwsh_host' -Protocol 'fcnvme' -Nqn 'nqn.2014-08.org.nvmexpress:NVMf:uuid:644f51bf-8432-4f59-bb13-5ada20c06397'
        $result.name | Should -Be 'pwsh_host'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lshost" -and $CmdArgs -contains "pwsh_host" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkhost" -and
                $CmdOpts.name -eq "pwsh_host" -and
                $CmdOpts.nqn -eq "nqn.2014-08.org.nvmexpress:NVMf:uuid:644f51bf-8432-4f59-bb13-5ada20c06397" -and
                $CmdOpts.protocol -eq "fcnvme" -and
                $CmdOpts.force -eq $true
            }
    }

    It "Should create a fdmi host" {
        $result = New-IBMSVHost -Name 'pwsh_host' -FDMIName '78F1CV1-1' -Protocol 'fcscsi'
        $result.name | Should -Be 'pwsh_host'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lshost" -and $CmdArgs -contains "pwsh_host" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkhost" -and
                $CmdOpts.name -eq "pwsh_host" -and
                $CmdOpts.fdminame -eq "78F1CV1-1" -and
                $CmdOpts.protocol -eq "fcscsi" -and
                $CmdOpts.force -eq $true
            }
    }

    It "Should create an iscsi host" {
        $result = New-IBMSVHost -Name 'pwsh_host' -IscsiName 'iqn.1' -Protocol 'iscsi' -PortSet 'pwsh_ps0'
        $result.name | Should -Be 'pwsh_host'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lshost" -and $CmdArgs -contains "pwsh_host" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkhost" -and
                $CmdOpts.name -eq "pwsh_host" -and
                $CmdOpts.iscsiname -eq "iqn.1" -and
                $CmdOpts.portset -eq "pwsh_ps0" -and
                $CmdOpts.protocol -eq "iscsi" -and
                $CmdOpts.force -eq $true
            }
    }

    It "Should create a fcscsi host" {
        $result = New-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251EE6' -Protocol 'fcscsi' -PortSet 'pwsh_ps0'
        $result.name | Should -Be 'pwsh_host'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lshost" -and $CmdArgs -contains "pwsh_host" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkhost" -and
                $CmdOpts.name -eq "pwsh_host" -and
                $CmdOpts.fcwwpn -eq "210100E08B251EE6" -and
                $CmdOpts.portset -eq "pwsh_ps0" -and
                $CmdOpts.protocol -eq "fcscsi" -and
                $CmdOpts.force -eq $true
            }
    }

    It "Should create a SAS host" {
        $result = New-IBMSVHost -Name 'pwsh_host' -SasWWPN '5000C50085A1B2C3' -Protocol 'sas'
        $result.name | Should -Be 'pwsh_host'
        $result.id   | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lshost" -and $CmdArgs -contains "pwsh_host" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkhost" -and
                $CmdOpts.name -eq "pwsh_host" -and
                $CmdOpts.fcwwpn -eq "5000C50085A1B2C3" -and
                $CmdOpts.protocol -eq "sas"
                $CmdOpts.force -eq $true
            }
    }

    It "Should create a host with location and partition successfully" {
        $result = New-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251EE6' -Partition 'pwsh_ptn' -Location 'pwsh_system'
        $result.name | Should -Be 'pwsh_host'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lshost" -and $CmdArgs -contains "pwsh_host" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkhost" -and
                $CmdOpts.name -eq "pwsh_host" -and
                $CmdOpts.fcwwpn -eq "210100E08B251EE6" -and
                $CmdOpts.partition -eq "pwsh_ptn" -and
                $CmdOpts.location -eq "pwsh_system" -and
                $CmdOpts.force -eq $true
            }
    }

    It "Should create host with additional parameters (Site, HostCluster, PortSet, etc.) to REST correctly" {
        $result = New-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251EE6' -Protocol 'fcscsi' -Type 'generic' -Site 'site1' -HostCluster 'pwsh_hc0' -Portset 'pwsh_ps0' -AutoStorageDiscovery 'yes'
        $result.name | Should -Be 'pwsh_host'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lshost" -and $CmdArgs -contains "pwsh_host" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkhost" -and
                $CmdOpts.name -eq "pwsh_host" -and
                $CmdOpts.fcwwpn -eq "210100E08B251EE6" -and
                $CmdOpts.protocol -eq "fcscsi" -and
                $CmdOpts.type -eq "generic" -and
                $CmdOpts.site -eq "site1" -and
                $CmdOpts.hostcluster -eq "pwsh_hc0" -and
                $CmdOpts.portset -eq "pwsh_ps0" -and
                $CmdOpts.autostoragediscovery -eq "yes" -and
                $CmdOpts.force -eq $true
            }
    }

    It "Should throw error when REST API call fails" {
       Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsvdisk") {
                return $null
            }

            if ($Cmd -eq "mkhost") {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/mkhost"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { New-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251EE6' } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/mkhost"
    }

}

