Describe "Set-IBMSVSnapshotPolicy Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd, $CmdArgs)

            if ($Cmd -eq 'lssnapshotpolicy') {
                if ($CmdArgs -eq 'pwsh_sp0') {
                    return [pscustomobject]@{
                        name = 'pwsh_sp0'
                        id = '0'
                        schedule_id = '1'
                        backup_unit = 'day'
                        backup_interval = '1'
                        backup_start_time = '210228180000'
                        retention_days = '15'
                    }
                }
                if ($CmdArgs -eq 'pwsh_sp1') {
                    return $null
                }
                return $null
            }

            if ($Cmd -eq 'chsnapshotpolicy') {
                return $null
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should not call API to update snapshot policy when -WhatIf is specified" {
        Set-IBMSVSnapshotPolicy -Name "pwsh_sp0" -NewName "pwsh_sp1" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chsnapshotpolicy' }
    }

    It "Should not throw error when NewName is same as Name" {
        { Set-IBMSVSnapshotPolicy -Name "pwsh_sp0" -NewName "pwsh_sp0" } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chsnapshotpolicy' }
    }

    It "Should be idempotent when NewName already exists and Name does not exist" {
        { Set-IBMSVSnapshotPolicy -Name "pwsh_sp2" -NewName "pwsh_sp0" } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lssnapshotpolicy" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chsnapshotpolicy' }
    }

    It "Should rename snapshot policy successfully" {
        Set-IBMSVSnapshotPolicy -Name "pwsh_sp0" -NewName "pwsh_sp1"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lssnapshotpolicy" -and $CmdArgs -eq "pwsh_sp0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lssnapshotpolicy" -and $CmdArgs -eq "pwsh_sp1" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "chsnapshotpolicy" -and
                $CmdOpts.name -eq "pwsh_sp1" -and
                $CmdArgs -eq "pwsh_sp0"
            }
    }

    It "Should throw error when both Name and NewName exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd, $CmdArgs)

            if ($Cmd -eq 'lssnapshotpolicy') {
                if ($CmdArgs -eq 'pwsh_sp0') {
                    return [pscustomobject]@{ name = 'pwsh_sp0'; id = '0' }
                }
                if ($CmdArgs -eq 'pwsh_sp1') {
                    return [pscustomobject]@{ name = 'pwsh_sp1'; id = '1' }
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVSnapshotPolicy -Name "pwsh_sp0" -NewName "pwsh_sp1" } | Should -Throw "Both 'pwsh_sp0' and 'pwsh_sp1' exist. Cannot rename."
    }
}
