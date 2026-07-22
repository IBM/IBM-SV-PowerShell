Describe "Restore-IBMSVFromSnapshot Tests" {
    Context "Parameter Validation" {
        It "Should not call API when -WhatIf is specified" {
            Mock Invoke-IBMSVRestRequest {
                return [pscustomobject]@{
                    name = 'pwsh_snap0'
                    volume_group_name = 'pwsh_vg0'
                    ha_state = 'local'
                }
            } -ModuleName IBMStorageVirtualize

            Restore-IBMSVFromSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "lsvolumegroupsnapshot" -and
                    $CmdOpts.filtervalue -eq "name=pwsh_snap0:volume_group_name=pwsh_vg0"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "restorefromsnapshot" }
        }
    }

    Context "VolumeGroup Snapshot Restore" {
        BeforeEach {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lsvolumegroupsnapshot") {
                    return [pscustomobject]@{
                        name = 'pwsh_snap0'
                        volume_group_name = 'pwsh_vg0'
                        ha_state = 'local'
                        parent_uid = '1'
                    }
                }

                if ($Cmd -eq "restorefromsnapshot") {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize
        }

        It "Should throw error when snapshot does not exist in volume group" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsvolumegroupsnapshot") {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            { Restore-IBMSVFromSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -Confirm:$false } | Should -Throw "Snapshot 'pwsh_snap0' does not exist in volume group 'pwsh_vg0'."
        }

        It "Should restore entire volume group snapshot successfully" {
            Restore-IBMSVFromSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0:volume_group_name=pwsh_vg0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "restorefromsnapshot" -and
                    $CmdOpts.snapshot -eq "pwsh_snap0" -and
                    $CmdOpts.volumegroup -eq "pwsh_vg0" -and
                    $CmdOpts.resyncrestoredvolumes -eq $true
                }
        }

        It "Should restore single volume from volume group snapshot" {
            Restore-IBMSVFromSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -Volumes "pwsh_vol0" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0:volume_group_name=pwsh_vg0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "restorefromsnapshot" -and
                    $CmdOpts.snapshot -eq "pwsh_snap0" -and
                    $CmdOpts.volumegroup -eq "pwsh_vg0" -and
                    $CmdOpts.volumes -eq "pwsh_vol0" -and
                    $CmdOpts.resyncrestoredvolumes -eq $true
                }
        }

        It "Should restore multiple volumes from volume group snapshot as array" {
            $volumes = @("pwsh_vol0", "pwsh_vol1", "pwsh_vol2")
            Restore-IBMSVFromSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -Volumes $volumes -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0:volume_group_name=pwsh_vg0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "restorefromsnapshot" -and
                    $CmdOpts.snapshot -eq "pwsh_snap0" -and
                    $CmdOpts.volumegroup -eq "pwsh_vg0" -and
                    $CmdOpts.volumes -eq "pwsh_vol0:pwsh_vol1:pwsh_vol2" -and
                    $CmdOpts.resyncrestoredvolumes -eq $true
                }
        }
    }

    Context "Independent Volume Snapshot Restore" {
        BeforeEach {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lsvolumegroupsnapshot") {
                    return [pscustomobject]@{
                        name = 'pwsh_snap0'
                        volume_group_name = ''
                        ha_state = 'local'
                        parent_uid = '1'
                    }
                }

                if ($Cmd -eq "restorefromsnapshot") {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize
        }

        It "Should throw error when independent snapshot does not exist" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsvolumegroupsnapshot") {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            { Restore-IBMSVFromSnapshot -Name "pwsh_snap0" -Confirm:$false } | Should -Throw "Snapshot 'pwsh_snap0' does not exist."
        }

        It "Should restore independent snapshot using fetched parent UID" {
            Restore-IBMSVFromSnapshot -Name "pwsh_snap0" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "lsvolumegroupsnapshot" -and
                    $CmdOpts.filtervalue -eq "name=pwsh_snap0"
                }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "restorefromsnapshot" -and
                    $CmdOpts.snapshot -eq "pwsh_snap0" -and
                    $CmdOpts.parentuid -eq "1" -and
                    $CmdOpts.resyncrestoredvolumes -eq $true
                }
        }

        It "Should restore specific volumes from independent snapshot" {
            Restore-IBMSVFromSnapshot -Name "pwsh_snap0" -Volumes "pwsh_vol0:pwsh_vol1" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "lsvolumegroupsnapshot" -and
                    $CmdOpts.filtervalue -eq "name=pwsh_snap0"
                }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "restorefromsnapshot" -and
                    $CmdOpts.snapshot -eq "pwsh_snap0" -and
                    $CmdOpts.parentuid -eq "1" -and
                    $CmdOpts.volumes -eq "pwsh_vol0:pwsh_vol1" -and
                    $CmdOpts.resyncrestoredvolumes -eq $true
                }
        }
    }

    Context "Highly Available Snapshot Validation" {
        BeforeEach {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lsvolumegroupsnapshot") {
                    return [pscustomobject]@{
                        name = 'pwsh_snap0'
                        volume_group_name = 'pwsh_vg0'
                        ha_state = 'highly_available'
                        parent_uid = '60050768108101C7C0000000000004E2'
                    }
                }

                if ($Cmd -eq "restorefromsnapshot") {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize
        }

        It "Should restore entire highly available snapshot successfully" {
            Restore-IBMSVFromSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "restorefromsnapshot" -and
                    $CmdOpts.snapshot -eq "pwsh_snap0" -and
                    $CmdOpts.volumegroup -eq "pwsh_vg0" -and
                    $CmdOpts.ContainsKey('resyncrestoredvolumes') -eq $false
                }
        }

        It "Should restore single volume from highly available snapshot" {
            Restore-IBMSVFromSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -Volumes "pwsh_vol0" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "restorefromsnapshot" -and
                    $CmdOpts.snapshot -eq "pwsh_snap0" -and
                    $CmdOpts.volumegroup -eq "pwsh_vg0" -and
                    $CmdOpts.volumes -eq "pwsh_vol0" -and
                    $CmdOpts.ContainsKey('resyncrestoredvolumes') -eq $false
                }
        }

        It "Should throw error when multiple volumes as array specified for highly available snapshot" {
            $volumes = @("pwsh_vol0", "pwsh_vol1", "pwsh_vol2")
            { Restore-IBMSVFromSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -Volumes $volumes -Confirm:$false } | Should -Throw "CMMVC1301E The command failed because highly available snapshot restore is only permitted on the whole snapshot or specifying a single volume"
        }
    }
}
