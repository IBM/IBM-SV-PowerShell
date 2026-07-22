Describe "Remove-IBMSVSnapshot" {
    Context "VolumeGroup Snapshot" {
        BeforeEach {
            $script:callCount = 0
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                $script:callCount++
                if ($Cmd -eq 'lsvolumegroupsnapshot') {
                    if ($script:callCount -eq 1) {
                        return [pscustomobject]@{
                            name = 'pwsh_snap0'
                            volume_group_name = 'pwsh_vg0'
                        }
                    }
                    else {
                        return $null
                    }
                }
                if ($Cmd -eq 'rmsnapshot') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize
        }

        It "Should not call API to remove snapshot when -WhatIf is specified for volumegroup snapshot" {
            Remove-IBMSVSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -Confirm:$false -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }

        It "Should not throw error when volumegroup snapshot does not exist" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lsvolumegroupsnapshot') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            { Remove-IBMSVSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -Confirm:$false } | Should -Not -Throw

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0:volume_group_name=pwsh_vg0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'rmsnapshot' }
        }

        It "Should remove volumegroup snapshot successfully" {
            Remove-IBMSVSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0:volume_group_name=pwsh_vg0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "rmsnapshot" -and $CmdOpts.snapshot -eq "pwsh_snap0" -and $CmdOpts.volumegroup -eq "pwsh_vg0" }
        }

        It "Should warn when snapshot enters dependent_deleting state" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq 'lsvolumegroupsnapshot') {
                    return [pscustomobject]@{
                        name = 'pwsh_snap0'
                        volume_group_name = 'pwsh_vg0'
                        state = 'dependent_deleting'
                    }
                }

                if ($Cmd -eq 'rmsnapshot') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            Remove-IBMSVSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0:volume_group_name=pwsh_vg0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "rmsnapshot" -and $CmdOpts.snapshot -eq "pwsh_snap0" -and $CmdOpts.volumegroup -eq "pwsh_vg0" }
        }
    }

    Context "Volume Snapshot" {
        BeforeEach {
            $script:callCount = 0
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                $script:callCount++
                if ($Cmd -eq 'lsvolumegroupsnapshot') {
                    if ($script:callCount -eq 1) {
                        return [pscustomobject]@{
                            name = 'pwsh_snap0'
                            parent_uid = '0'
                            volume_group_name = ''
                        }
                    }
                    else {
                        return $null
                    }
                }
                if ($Cmd -eq 'rmsnapshot') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize
        }

        It "Should not call API to remove snapshot when -WhatIf is specified for volume snapshot" {
            Remove-IBMSVSnapshot -Name "pwsh_snap0" -Confirm:$false -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }

        It "Should not throw error when volume snapshot does not exist" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lsvolumegroupsnapshot') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            { Remove-IBMSVSnapshot -Name "pwsh_snap0" -Confirm:$false } | Should -Not -Throw

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'rmsnapshot' }
        }

        It "Should remove volume snapshot successfully" {
            Remove-IBMSVSnapshot -Name "pwsh_snap0" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "rmsnapshot" -and $CmdOpts.snapshot -eq "pwsh_snap0" -and $CmdOpts.parentuid -eq "0" }
        }
    }
}
