Describe "New-IBMSVReplicationPolicy Tests" {
    BeforeEach {
        $script:callCount = 0
    }

    It "Should throw an InvalidArgument error for the 'async-dr' topology" {
        { New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "async-dr" -RpoAlert 60 } | Should -Throw "Partition must be accompanied by 'async-dr'."
        { New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "async-dr" -Partition "ptn" } | Should -Throw "Parameter -RpoAlert is required when the topology is set to '2-site-async-dr' or 'async-dr'."

        { New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "async-dr" -Location1System "cluster_A" -Location1IOGrp 0 -Location2System "cluster_B" -Location2IOGrp 0 -Partition "ptn" -RpoAlert 60 } | Should -Throw "For topology 'async-dr', the following parameters are invalid: -Location1System, -Location1IOGrp, -Location2System, -Location2IOGrp."
        { New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "async-dr" -Snapshots "yes" -Partition "ptn" -RpoAlert 60 } | Should -Throw "Parameter -Snapshots is only valid for topology '2-site-ha'."
    }

    It "Should throw an InvalidArgument error for the '2-site-ha' topology" {
        { New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "2-site-ha" } | Should -Throw "For topology '2-site-ha', the following parameters are required: -Location1System, -Location1IOGrp, -Location2System, -Location2IOGrp."

        { New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "2-site-ha" -Partition "ptn" -Location1System "cluster_A" -Location1IOGrp 0 -Location2System "cluster_B" -Location2IOGrp 0 -RpoAlert 60 } | Should -Throw "Parameter -Partition is only valid for topology 'async-dr'."
        # { New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "2-site-ha" -RpoAlert 60 "yes" -Location1IOGrp 0 -Location1System "cluster_A" -Location2IOGrp 0 -Location2System "cluster_B" -RpoAlert 60 } | Should -Throw "Parameter -Snapshots is only valid for topology '2-site-ha'."
    }

    It "Should throw an InvalidArgument error for the '2-site-async-dr' topology" {
        { New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "2-site-async-dr" -RpoAlert 60 } | Should -Throw "For topology '2-site-async-dr', the following parameters are required: -Location1System, -Location1IOGrp, -Location2System, -Location2IOGrp."

        { New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "2-site-async-dr" -Location1IOGrp 0 -Location1System "cluster_A" -Location2IOGrp 0 -Location2System "cluster_B" } | Should -Throw "Parameter -RpoAlert is required when the topology is set to '2-site-async-dr' or 'async-dr'."

        { New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "2-site-async-dr" -Partition "ptn" -Location1IOGrp 0 -Location1System "cluster_A" -Location2IOGrp 0 -Location2System "cluster_B" -RpoAlert 60 } | Should -Throw "Parameter -Partition is only valid for topology 'async-dr'."
        { New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "2-site-async-dr" -Snapshots "yes" -Location1IOGrp 0 -Location1System "cluster_A" -Location2IOGrp 0 -Location2System "cluster_B" -RpoAlert 60 } | Should -Throw "Parameter -Snapshots is only valid for topology '2-site-ha'."
    }

    It "Should not call API to create replication policy when -WhatIf is specified" {
        Mock Invoke-IBMSVRestRequest {} -ModuleName IBMStorageVirtualize

        New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "2-site-async-dr" -Location1System "cluster_A" -Location1IOGrp 0 -Location2System "cluster_B" -Location2IOGrp 0 -RpoAlert 60 -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should create a 2-site-async-dr replication policy" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsreplicationpolicy") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                return [pscustomobject]@{
                    name = 'pwsh_rp0'
                    id = '0'
                    topology = '2-site-async-dr'
                    location1_system_name = 'cluster_A'
                    location1_iogrp_id = '0'
                    location2_system_name = 'cluster_B'
                    location2_iogrp_id = '0'
                    rpo_alert = '60'
                }
            }

            if ($Cmd -eq "mkreplicationpolicy") {
                return [pscustomobject]@{ id = '0'; message = 'Replication policy created successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "2-site-async-dr" -Location1System "cluster_A" -Location1IOGrp 0 -Location2System "cluster_B" -Location2IOGrp 0 -RpoAlert 60
        $result.name | Should -Be 'pwsh_rp0'
        $result.id | Should -Be '0'
        $result.topology | Should -Be '2-site-async-dr'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsreplicationpolicy" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkreplicationpolicy" -and
                $CmdOpts.name -eq "pwsh_rp0" -and
                $CmdOpts.topology -eq "2-site-async-dr" -and
                $CmdOpts.location1system -eq "cluster_A" -and
                $CmdOpts.location1iogrp -eq 0 -and
                $CmdOpts.location2system -eq "cluster_B" -and
                $CmdOpts.location2iogrp -eq 0 -and
                $CmdOpts.rpoalert -eq 60
            }
    }

    It "Should create a 2-site-ha replication policy with required parameters" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsreplicationpolicy") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                return [pscustomobject]@{
                    name = 'pwsh_rp0'
                    id = '1'
                    topology = '2-site-ha'
                    location1_system_name = 'cluster_A'
                    location1_iogrp_id = '0'
                    location2_system_name = 'cluster_B'
                    location2_iogrp_id = '0'
                }
            }

            if ($Cmd -eq "mkreplicationpolicy") {
                return [pscustomobject]@{ id = '1'; message = 'Replication policy created successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "2-site-ha" -Location1System "cluster_A" -Location1IOGrp 0 -Location2System "cluster_B" -Location2IOGrp 0
        $result.name | Should -Be 'pwsh_rp0'
        $result.id | Should -Be '1'
        $result.topology | Should -Be '2-site-ha'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsreplicationpolicy" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkreplicationpolicy" -and
                $CmdOpts.name -eq "pwsh_rp0" -and
                $CmdOpts.topology -eq "2-site-ha" -and
                $CmdOpts.location1system -eq "cluster_A" -and
                $CmdOpts.location1iogrp -eq 0 -and
                $CmdOpts.location2system -eq "cluster_B" -and
                $CmdOpts.location2iogrp -eq 0
            }
    }

    It "Should create a 2-site-ha replication policy with Snapshots enabled" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsreplicationpolicy") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                return [pscustomobject]@{
                    name = 'pwsh_rp0'
                    id = '2'
                    topology = '2-site-ha'
                    location1_system_name = 'cluster_A'
                    location1_iogrp_id = '0'
                    location2_system_name = 'cluster_B'
                    location2_iogrp_id = '0'
                    snapshots = 'yes'
                }
            }

            if ($Cmd -eq "mkreplicationpolicy") {
                return [pscustomobject]@{ id = '2'; message = 'Replication policy created successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "2-site-ha" -Location1System "cluster_A" -Location1IOGrp 0 -Location2System "cluster_B" -Location2IOGrp 0 -Snapshots "yes"
        $result.name | Should -Be 'pwsh_rp0'
        $result.snapshots | Should -Be 'yes'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsreplicationpolicy" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkreplicationpolicy" -and
                $CmdOpts.name -eq "pwsh_rp0" -and
                $CmdOpts.topology -eq "2-site-ha" -and
                $CmdOpts.location1system -eq "cluster_A" -and
                $CmdOpts.location1iogrp -eq 0 -and
                $CmdOpts.location2system -eq "cluster_B" -and
                $CmdOpts.location2iogrp -eq 0
                $CmdOpts.snapshots -eq "yes"
            }
    }

    It "Should create an async-dr replication policy with required parameters" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsreplicationpolicy") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                return [pscustomobject]@{
                    name = 'pwsh_rp0'
                    id = '3'
                    topology = 'async-dr'
                    partition_name = 'ptn0'
                    rpo_alert = '60'
                }
            }

            if ($Cmd -eq "mkreplicationpolicy") {
                return [pscustomobject]@{ id = '3'; message = 'Replication policy created successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "async-dr" -Partition "ptn0" -RpoAlert 60
        $result.name | Should -Be 'pwsh_rp0'
        $result.id | Should -Be '3'
        $result.topology | Should -Be 'async-dr'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsreplicationpolicy" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkreplicationpolicy" -and
                $CmdOpts.name -eq "pwsh_rp0" -and
                $CmdOpts.topology -eq "async-dr" -and
                $CmdOpts.partition -eq "ptn0" -and
                $CmdOpts.rpoalert -eq 60
            }
    }

    It "Should be idempotent when replication policy already exists" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsreplicationpolicy") {
                return [pscustomobject]@{
                    name = 'pwsh_rp0'
                    id = '3'
                    topology = 'async-dr'
                    partition_name = 'ptn0'
                    rpo_alert = '60'
                }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVReplicationPolicy -Name "pwsh_rp0" -Topology "async-dr" -Partition "ptn0" -RpoAlert 60
        $result.name | Should -Be 'pwsh_rp0'
        $result.id | Should -Be '3'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsreplicationpolicy" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkreplicationpolicy" }
    }
}
