Describe "New-IBMSVPartition" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lspartition") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    id = '0'
                }
            }

            if ($Cmd -eq "mkpartition") {
                return [pscustomobject]@{ id = '0'; message = 'Partition created successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when mutually exclusive parameter specified" {
        { New-IBMSVPartition -Name "pwsh_partition0" -ReplicationPolicy "pwsh_rp0" -ManagementPortset "pwsh_ps0" } | Should -Throw "Parameters ReplicationPolicy, ManagementPortset are mutually exclusive."
        { New-IBMSVPartition -Name "pwsh_partition0" -ReplicationPolicy "pwsh_rp0" -OwnershipGroup "pwsh_og0" } | Should -Throw "Parameters OwnershipGroup, ReplicationPolicy are mutually exclusive."
    }

    It "Should not call API to create partition when -WhatIf is specified" {
        New-IBMSVPartition -Name "pwsh_partition0" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should create a partition with required parameters" {
        $result = New-IBMSVPartition -Name "pwsh_partition0"
        $result.name | Should -Be 'pwsh_partition0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lspartition" -and $CmdArgs -contains "pwsh_partition0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkpartition" -and $CmdOpts.name -eq "pwsh_partition0" }
    }

    It "Should be idempotent when partition already exists" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lspartition") {
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    id = '0'
                    draft = 'no'
                }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVPartition -Name "pwsh_partition0"
        $result.name | Should -Be 'pwsh_partition0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lspartition" -and $CmdArgs -contains "pwsh_partition0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkpartition" }
    }

    It "Should create a draft partition" {
        $result = New-IBMSVPartition -Name "pwsh_partition0" -Draft
        $result.name | Should -Be 'pwsh_partition0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lspartition" -and $CmdArgs -contains "pwsh_partition0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkpartition" -and
                $CmdOpts.name -eq "pwsh_partition0" -and
                $CmdOpts.draft -eq $true
            }
    }

    It "Should create a partition with replication policy" {
        $result = New-IBMSVPartition -Name "pwsh_partition0" -ReplicationPolicy "pwsh_rp0"
        $result.name | Should -Be 'pwsh_partition0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lspartition" -and $CmdArgs -contains "pwsh_partition0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkpartition" -and
                $CmdOpts.name -eq "pwsh_partition0" -and
                $CmdOpts.replicationpolicy -eq "pwsh_rp0"
            }
    }

    It "Should create a partition with all portset" {
        $result = New-IBMSVPartition -Name "pwsh_partition0" -ManagementPortset "pwsh_ps0"  -OwnershipGroup "pwsh_og0" -Draft
        $result.name | Should -Be 'pwsh_partition0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lspartition" -and $CmdArgs -contains "pwsh_partition0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkpartition" -and
                $CmdOpts.name -eq "pwsh_partition0" -and
                $CmdOpts.managementportset -eq "pwsh_ps0"
                $CmdOpts.ownershipgroup -eq "pwsh_og0"
                $CmdOpts.draft -eq $true
            }
    }

    It "Should retry if connection refused error occurred after the creation of partition with all portset" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lspartition") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                if ($script:callCount -eq 3) {
                    return [pscustomobject]@{
                        url  = "https://1.1.1.1:7443/rest/v1/lspartition/pwsh_partition0"
                        code = -1
                        err  = "HTTPError: Connection refused (1.1.1.1:7443)"
                        out  = "Connection refused (1.1.1.1:7443)"
                        data = @{}
                    }
                }
                return [pscustomobject]@{
                    name = 'pwsh_partition0'
                    id = '0'
                    draft = 'yes'
                    replication_policy_name = 'pwsh_og0'
                    management_portset_name = 'pwsh_ps0'
                }
            }

            if ($Cmd -eq "mkpartition") {
                return [pscustomobject]@{ id = '0'; message = 'Partition created successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVPartition -Name "pwsh_partition0" -ManagementPortset "pwsh_ps0"  -OwnershipGroup "pwsh_og0" -Draft
        $result.name | Should -Be 'pwsh_partition0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 3 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lspartition" -and $CmdArgs -contains "pwsh_partition0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkpartition" -and
                $CmdOpts.name -eq "pwsh_partition0" -and
                $CmdOpts.managementportset -eq "pwsh_ps0"
                $CmdOpts.ownershipgroup -eq "pwsh_og0"
                $CmdOpts.draft -eq $true
            }
    }
}
