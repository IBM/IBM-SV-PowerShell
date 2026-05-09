Describe "Set-IBMSVHost" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lshost') {
                return @{
                    name = 'pwsh_host'
                    type = 'generic'
                    site_name = ''
                    status_policy = 'redundant'
                    host_cluster_name = ''
                    status_site = 'all'
                    owner_name = ''
                    auto_storage_discovery = 'no'
                    offline_alert_suppressed = 'no'
                    portset_name = 'pwsh_portset0'
                    location_system_name = ''
                    partition_name = ''
                    host_secret = 'no'
                    storage_secret = 'no'
                }
            }
            if ($Cmd -eq 'lshostiogrp') {
                return @(
                    @{ id = '0' },
                    @{ id = '1' },
                    @{ id = '2' }
                )
            }
        } -ModuleName IBMStorageVirtualize

        Mock Get-IBMSVVersion { return "9.1.0.0" } -ModuleName IBMStorageVirtualize
        $script:count = 0
    }

    Context "Parameter Validation" {
        It "Should throw error when HostSecret and NoHostSecret are both specified" {
            { Set-IBMSVHost -Name 'pwsh_host' -HostSecret 'pwsh_hs' -NoHostSecret } | Should -Throw "Parameters HostSecret, NoHostSecret are mutually exclusive."
        }

        It "Should throw error when Site and NoSite are both specified" {
            { Set-IBMSVHost -Name 'pwsh_host' -Site 'site1' -NoSite } | Should -Throw "Parameters Site, NoSite are mutually exclusive."
        }

        It "Should throw error when HostUsername and NoHostSecret are both specified" {
            { Set-IBMSVHost -Name 'pwsh_host' -HostUsername 'pwsh_user' -NoHostSecret } | Should -Throw "Parameters HostUsername, NoHostSecret are mutually exclusive."
        }

        It "Should throw error when Partition and NoPartition are both specified" {
            { Set-IBMSVHost -Name 'pwsh_host' -Partition 'pwsh_ptn' -NoPartition } | Should -Throw "Parameters Partition, NoPartition are mutually exclusive."
        }

        It "Should throw error when DraftPartition and NoDraftPartition are both specified" {
            { Set-IBMSVHost -Name 'pwsh_host' -DraftPartition 'pwsh_ptn' -NoDraftPartition } | Should -Throw "Parameters DraftPartition, NoDraftPartition are mutually exclusive."
        }

        It "Should throw error when Site and Partition are both specified" {
            { Set-IBMSVHost -Name 'pwsh_host' -Site 'site1' -Partition 'pwsh_ptn' } | Should -Throw "Parameters Site, Partition are mutually exclusive."
        }

        It "Should throw error when Partition and NoPartition are both specified" {
            { Set-IBMSVHost -Name 'pwsh_host' -Partition 'pwsh_ptn' -NoPartition } | Should -Throw "Parameters Partition, NoPartition are mutually exclusive."
        }

        It "Should throw error when Location and NoLocation are both specified" {
            { Set-IBMSVHost -Name 'pwsh_host' -Location 'pwsh_system' -NoLocation } | Should -Throw "Parameters Location, NoLocation are mutually exclusive."
        }

        It "Should throw error when StorageSecret and NoStorageSecret are both specified" {
            { Set-IBMSVHost -Name 'pwsh_host' -StorageSecret 'pwsh_hs' -NoStorageSecret } | Should -Throw "Parameters StorageSecret, NoStorageSecret are mutually exclusive."
        }

        It "Should throw error when StorageUsername and NoStorageSecret are both specified" {
            { Set-IBMSVHost -Name 'pwsh_host' -StorageUsername 'pwsh_user' -NoStorageSecret } | Should -Throw "Parameters StorageUsername, NoStorageSecret are mutually exclusive."
        }

        It "Should throw error when HostUsername is used without HostSecret" {
            { Set-IBMSVHost -Name 'pwsh_host' -HostUsername 'pwsh_user' } | Should -Throw "CMMVC1336E The -HostSecret parameter is required when the -HostUsername parameter is specified."
        }

        It "Should throw error when StorageUsername is used without StorageSecret" {
            { Set-IBMSVHost -Name 'pwsh_host' -StorageUsername 'pwsh_user' } | Should -Throw "CMMVC1278E The -StorageSecret parameter is required when the -StorageUsername parameter is specified."
        }

        It "Should not call API to update host when -WhatIf is specified" {
            Set-IBMSVHost -Name 'pwsh_host0' -Type 'adminlun' -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chhost' }
        }
    }

    Context "Rename functionality" {
        It "Should throw error when host does not exist" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') { return $null }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVHost -Name 'pwsh_host' } | Should -Throw "Host 'pwsh_host' does not exist."
        }

        It "Should throw error when both host and new name not exist" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') { return $null }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVHost -Name 'pwsh_host0' -NewName 'pwsh_host1' } | Should -Throw "Host 'pwsh_host0' does not exist."
        }

        It "Should rename the host when NewName is different" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                $script:count++
                if ($Cmd -eq 'lshost' -and $script:count -eq 1) {
                    return @{ name = 'pwsh_host0'; id = '0'; site_name = '' }
                }
                elseif ($Cmd -eq 'lshost' -and $script:count -eq 2) {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host0' -NewName 'pwsh_host1' -Site 'site1'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chhost' -and
                    $CmdOpts.name -eq 'pwsh_host1' -and
                    $CmdOpts.site -eq 'site1' -and
                    $CmdArgs -eq 'pwsh_host0'
                }
        }

        It "Should not throw error if -Name host does not exist but -NewName host exists and proceed to update other params on -NewName host" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                $script:count++
                if ($Cmd -eq 'lshost' -and $script:count -eq 1) {
                    return $null
                }
                elseif ($Cmd -eq 'lshost' -and $script:count -eq 2) {
                    return @{ name = 'pwsh_host1'; id = '1'; site_name = '' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host0' -NewName 'pwsh_host1' -Site 'site1'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chhost' -and
                    $CmdOpts.site -eq 'site1' -and
                    $CmdArgs -eq 'pwsh_host1'
                }
        }

        It "Should throw error if both -Name host and -NewName host exist" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                $script:count++
                if ($Cmd -eq 'lshost' -and $script:count -eq 1) {
                    return @{ name = 'pwsh_host0'; id = '0' }
                }
                elseif ($Cmd -eq 'lshost' -and $script:count -eq 2) {
                    return @{ name = 'pwsh_host1'; id = '1' }
                }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVHost -Name 'pwsh_host0' -NewName 'pwsh_host1' -Site 'site1' } | Should -Throw "Both 'pwsh_host0' and 'pwsh_host1' exist. Cannot rename, cannot proceed with other updates."
        }
    }

    Context "Host Identifier Update" {
        It "Should be idempotent when updating SasWWPN" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{
                        name  = 'pwsh_host'
                        nodes = @(
                            @{ SAS_WWPN = '210100E08B251DD4' }
                        )
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -SasWWPN '210100E08B251DD4'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -in @('addhostport', 'rmhostport', 'chhost') }
        }

        It "Should add SAS WWPNs when new values are provided" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{
                        name  = 'pwsh_host'
                        nodes = @(
                            @{ SAS_WWPN = '210100E08B251DD4' },
                        @{ SAS_WWPN = '210100E08B251DD5' }
                    )
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -SasWWPN '210100E08B251DD4:210100E08B251DD5:210100E08B251DD6'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'addhostport' -and $CmdOpts.saswwpn -eq '210100E08B251DD6' }
        }

        It "Should add and remove SAS WWPNs to match desired state" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{
                        name  = 'pwsh_host'
                        nodes = @(
                            @{ SAS_WWPN = '210100E08B251EE6' },
                            @{ SAS_WWPN = '210100F08C262EE7' }
                        )
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -SasWWPN "210100F08C262EE7:210100G08D273EE8"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'addhostport' -and $CmdOpts.saswwpn -eq '210100G08D273EE8'}
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'rmhostport' -and $CmdOpts.saswwpn -eq '210100E08B251EE6'}
        }

        It "Should be idempotent when updating FCWWPN" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{
                        name  = 'pwsh_host'
                        nodes = @(
                            @{ WWPN = '210100E08B251EE6' }
                        )
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251EE6'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -in @('addhostport', 'rmhostport', 'chhost') }
        }

        It "Should add new FCWWPNs when new values are provided" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{
                        name  = 'pwsh_host'
                        nodes = @(
                            @{ WWPN = '210100E08B251DD4' },
                            @{ WWPN = '210100E08B251DD5' }
                        )
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -FCWWPN '210100E08B251DD4:210100E08B251DD5:210100E08B251DD6'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'addhostport' -and $CmdOpts.fcwwpn -eq '210100E08B251DD6' }
        }

        It "Should add and remove FCWWPNs to match desired state" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{
                        name  = 'pwsh_host'
                        nodes = @(
                            @{ WWPN = '210100E08B251EE6' },
                            @{ WWPN = '210100F08C262EE7' }
                        )
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -FCWWPN "210100F08C262EE7:210100G08D273EE8"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'addhostport' -and $CmdOpts.fcwwpn -eq '210100G08D273EE8'}
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'rmhostport' -and $CmdOpts.fcwwpn -eq '210100E08B251EE6'}
        }

        It "Should be idempotent when updating Nqn" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{
                        name  = 'pwsh_host'
                        nodes = @(
                            @{ nqn = 'nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef2ffff' }
                        )
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -Nqn 'nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef2ffff'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -in @('addhostport', 'rmhostport', 'chhost') }
        }

        It "Should add new NQNs when new values are provided" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq 'lshost') {
                    return @{
                        name  = 'pwsh_host'
                        nodes = @(
                            @{ nqn = 'nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef2ffff' },
                            @{ nqn = 'nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef3ffff' }
                        )
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -Nqn 'nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef2ffff,nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef3ffff,nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef4ffff'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                 -ParameterFilter { $Cmd -eq 'addhostport' -and $CmdOpts.nqn -eq 'nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef4ffff' }
        }

        It "Should add and remove Nqns to match desired state" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{
                        name  = 'pwsh_host'
                        nodes = @(
                            @{ nqn = 'nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef2ffff' },
                            @{ nqn = 'nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef3ffff' }
                        )
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -Nqn 'nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef3ffff,nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef4ffff'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'addhostport' -and $CmdOpts.nqn -eq 'nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef4ffff'}
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'rmhostport' -and $CmdOpts.nqn -eq 'nqn.2014-08.org.nvmexpress:uuid:616d5c90-4747-11e6-9fbe-0894ef2ffff'}
        }

        It "Should be idempotent when iSCSI name already matches" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{
                        name  = 'pwsh_host'
                        nodes = @(
                            @{ iscsi_name = 'iqn.localhost.hostid.7f000001' }
                        )
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -IscsiName 'iqn.localhost.hostid.7f000001'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -in @('addhostport', 'rmhostport', 'chhost') }
        }

        It "Should add new iSCSI names when new values are provided" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{
                        name  = 'pwsh_host'
                        nodes = @(
                            @{ iscsi_name = 'iqn.localhost.hostid.7f000001' },
                            @{ iscsi_name = 'iqn.localhost.hostid.7f000002' }
                        )
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -IscsiName 'iqn.localhost.hostid.7f000001,iqn.localhost.hostid.7f000002,iqn.localhost.hostid.7f000003'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'addhostport' -and $CmdOpts.iscsiname -eq 'iqn.localhost.hostid.7f000003'}
        }

        It "Should add and remove iSCSI names to match desired state" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{
                        name  = 'pwsh_host'
                        nodes = @(
                            @{ iscsi_name = 'iqn.localhost.hostid.7f000001' },
                            @{ iscsi_name = 'iqn.localhost.hostid.7f000002' }
                        )
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -IscsiName 'iqn.localhost.hostid.7f000002,iqn.localhost.hostid.7f000003'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'addhostport' -and $CmdOpts.iscsiname -eq 'iqn.localhost.hostid.7f000003'}
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'rmhostport' -and $CmdOpts.iscsiname -eq 'iqn.localhost.hostid.7f000001'}
        }
    }

    Context "Other params" {
        It "Should add and remove IOGroups to match desired state" {
            Set-IBMSVHost -Name 'pwsh_host' -IOGrp '1:2:3'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'addhostiogrp' -and $CmdOpts.iogrp -eq '3' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'rmhostiogrp' -and $CmdOpts.iogrp -eq '0' }
        }

        It "Should update site, statuspolicy, statussite, ownershipgroup, autostoragediscovery, suppressofflinealert, portset, location" {
            Set-IBMSVHost -Name 'pwsh_host' -Site 'site1' -StatusPolicy 'complete' -StatusSite 'local' -OwnershipGroup 'pwsh_og0' -AutoStorageDiscovery 'yes' -SuppressOfflineAlert 'yes' -Portset 'pwsh_portset1' -Location 'pwsh_system0'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chhost' -and
                    $CmdOpts.site -eq 'site1' -and
                    $CmdOpts.statuspolicy -eq 'complete' -and
                    $CmdOpts.statussite -eq 'local' -and
                    $CmdOpts.ownershipgroup -eq 'pwsh_og0' -and
                    $CmdOpts.autostoragediscovery -eq 'yes' -and
                    $CmdOpts.suppressofflinealert -eq 'yes' -and
                    $CmdOpts.portset -eq 'pwsh_portset1' -and
                    $CmdOpts.location -eq 'pwsh_system0' -and
                    $CmdArgs -eq 'pwsh_host'
                }
        }

        It "Should remove site, ownershipgroup, location" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq 'lshost') {
                    return @{ name = 'pwsh_host'; site_name = 'site1'; owner_name = 'pwsh_og0'; location_system_name = 'pwsh_system0' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -NoSite -NoOwnershipGroup -NoLocation

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chhost' -and
                    $CmdOpts.nosite -eq $true -and
                    $CmdOpts.noownershipgroup -eq $true -and
                    $CmdOpts.nolocation -eq $true -and
                    $CmdArgs -eq 'pwsh_host'
                }
        }

        It "Should update partition" {
            Set-IBMSVHost -Name 'pwsh_host' -Partition 'pwsh_ptn'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                    $Cmd -eq 'chhost' -and
                    $CmdOpts.partition -eq 'pwsh_ptn' -and
                    $CmdArgs -eq 'pwsh_host'
                }
        }

        It "Should update type and ownership group" {
            Set-IBMSVHost -Name 'pwsh_host' -Type 'adminlun' -OwnershipGroup 'pwsh_og'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chhost' -and
                    $CmdOpts.type -eq 'adminlun' -and
                    $CmdArgs -eq 'pwsh_host'
                }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chhost' -and
                    $CmdOpts.ownershipgroup -eq 'pwsh_og' -and
                    $CmdArgs -eq 'pwsh_host'
                }
        }

        It "Should update name, type, hostsecret and partition" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                $script:count++
                if ($Cmd -eq 'lshost' -and $script:count -eq 1) {
                    return @{
                        name = 'pwsh_host0'
                        type = 'generic'
                        partition_name = ''
                        host_secret = 'no'
                    }
                }
                elseif ($Cmd -eq 'lshost' -and $script:count -eq 2) {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host0' -NewName 'pwsh_host1' -Type 'adminlun' -HostSecret 'pwsh_hs' -Partition 'pwsh_ptn'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chhost' -and
                    $CmdOpts.partition -eq 'pwsh_ptn' -and
                    $CmdArgs -eq 'pwsh_host0'
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chhost' -and
                    $CmdOpts.name -eq 'pwsh_host1' -and
                    $CmdOpts.type -eq 'adminlun' -and
                    $CmdOpts.hostsecret -eq 'pwsh_hs' -and
                    $CmdArgs -eq 'pwsh_host0'
                }

        }

        It "Should update hostsecret and storagesecret" {
            Set-IBMSVHost -Name 'pwsh_host' -HostSecret 'pwsh_hs' -StorageSecret 'pwsh_ss'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chhost' -and
                    $CmdOpts.hostsecret -eq 'pwsh_hs' -and
                    $CmdOpts.storagesecret -eq 'pwsh_ss' -and
                    $CmdArgs -eq 'pwsh_host'
                }
            }

        It "Should remove draft partition" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{ name = 'pwsh_host'; draft_partition_name = 'pwsh_ptn' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -NoDraftPartition

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chhost' -and
                    $CmdOpts.nodraftpartition -eq $true -and
                    $CmdArgs -eq 'pwsh_host'
                }
        }
    }

    Context "HostCluster membership"{

        It "Should add host to host cluster" {
            Set-IBMSVHost -Name 'pwsh_host' -HostCluster 'pwsh_hc'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'addhostclustermember' -and $CmdOpts.host -eq 'pwsh_host' -and $CmdArgs -eq 'pwsh_hc' }

        }
        It "Should be idempotent when adding host to host cluster again" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{ name = 'pwsh_host'; host_cluster_name = 'pwsh_hc' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -HostCluster 'pwsh_hc'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lshost" -and $CmdArgs -contains "pwsh_host" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -in @('addhostclustermember', 'chhost') }
        }

        It "Should removes host from host cluster" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lshost') {
                    return @{ name = 'pwsh_host'; host_cluster_name = 'pwsh_hc' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVHost -Name 'pwsh_host' -NoHostCluster

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'rmhostclustermember' -and
                    $CmdOpts.host -eq 'pwsh_host'
                    $CmdOpts.keepmappings -eq $true -and
                    $CmdArgs -eq 'pwsh_hc'
                }
        }

        It "Should be idempotent when removing host from host cluster" {
            Set-IBMSVHost -Name 'pwsh_host' -NoHostCluster

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lshost" -and $CmdArgs -contains "pwsh_host" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -in @('rmhostclustermember', 'chhost') }
        }
    }


    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            return [pscustomobject]@{
                url  = "https://1.1.1.1:7443/rest/v1/chhost/pwsh_host"
                code = 500
                err  = "HTTPError failed"
                out  = @{}
                data = @{}
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVHost -Name 'pwsh_host' -Site 'site1' } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/chhost/pwsh_host"
    }
}
