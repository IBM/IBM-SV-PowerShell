Describe "Set-IBMSVSnapshot Tests" {
    BeforeEach {
        $script:callCount = 0
    }

    It "Should not call API to update snapshot when -WhatIf is specified for volumegroup snapshot" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroupsnapshot') {
                return @{
                    name = 'pwsh_snap0'
                    volume_group_name = 'pwsh_vg0'
                    owner_name = ''
                }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVSnapshot -Name 'pwsh_snap0' -VolumeGroup 'pwsh_vg0' -OwnershipGroup 'pwsh_og0' -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chsnapshot' }
    }

    Context "VolumeGroup Snapshots" {
        It "Should throw error when volumegroup snapshot does not exist" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lsvolumegroupsnapshot') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVSnapshot -Name 'pwsh_snap0' -VolumeGroup 'pwsh_vg0' } | Should -Throw "Snapshot 'pwsh_snap0' does not exist in volume group 'pwsh_vg0'."
        }

        Context "Rename Functionality" {
            It "Should throw error when both volumegroup snapshots does not exist" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd)
                    if ($Cmd -eq 'lsvolumegroupsnapshot') {
                        return $null
                    }
                } -ModuleName IBMStorageVirtualize

                { Set-IBMSVSnapshot -Name 'pwsh_snap0' -NewName 'pwsh_snap1' -VolumeGroup 'pwsh_vg0' } | Should -Throw "Snapshot 'pwsh_snap0' does not exist in volume group 'pwsh_vg0'."
            }

            It "Should rename the volumegroup snapshot when NewName is different" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd)
                    $script:callCount++
                    if ($Cmd -eq 'lsvolumegroupsnapshot') {
                        if ($script:callCount -eq 1) {
                            return @{
                                name = 'pwsh_snap0'
                                volume_group_name = 'pwsh_vg0'
                            }
                        }
                        if ($script:callCount -eq 2) {
                            return $null
                        }
                    }
                } -ModuleName IBMStorageVirtualize

                Set-IBMSVSnapshot -Name 'pwsh_snap0' -NewName 'pwsh_snap1' -VolumeGroup 'pwsh_vg0'

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0:volume_group_name=pwsh_vg0" }

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap1:volume_group_name=pwsh_vg0" }

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq 'chsnapshot' -and
                        $CmdOpts.name -eq 'pwsh_snap1' -and
                        $CmdOpts.snapshot -eq 'pwsh_snap0' -and
                        $CmdOpts.volumegroup -eq 'pwsh_vg0'
                    }
            }

            It "Should not throw error if -Name volumegroup snapshot does not exist but -NewName volumegroup snapshot exists and proceed to update other params on -NewName volumegroup snapshot" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd)
                    $script:callCount++
                    if ($Cmd -eq 'lsvolumegroupsnapshot') {
                        if ($script:callCount -eq 1) {
                            return $null
                        }
                        if ($script:callCount -eq 2) {
                            return @{
                                name = 'pwsh_snap1'
                                volume_group_name = 'pwsh_vg0'
                                owner_name = ''
                            }
                        }
                    }
                } -ModuleName IBMStorageVirtualize

                Set-IBMSVSnapshot -Name 'pwsh_snap0' -NewName 'pwsh_snap1' -VolumeGroup 'pwsh_vg0' -OwnershipGroup 'pwsh_og0'

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0:volume_group_name=pwsh_vg0" }

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap1:volume_group_name=pwsh_vg0" }

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq 'chsnapshot' -and
                        $CmdOpts.ownershipgroup -eq 'pwsh_og0' -and
                        $CmdOpts.snapshot -eq 'pwsh_snap1' -and
                        $CmdOpts.volumegroup -eq 'pwsh_vg0'
                    }
            }

            It "Should throw error if both -Name volumegroup snapshot and -NewName volumegroup snapshot exist" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd)
                    $script:callCount++
                    if ($Cmd -eq 'lsvolumegroupsnapshot') {
                        if ($script:callCount -eq 1) {
                            return @{
                                name = 'pwsh_snap0'
                                volume_group_name = 'pwsh_vg0'
                            }
                        }
                        if ($script:callCount -eq 2) {
                            return @{
                                name = 'pwsh_snap1'
                                volume_group_name = 'pwsh_vg0'
                            }
                        }
                    }
                } -ModuleName IBMStorageVirtualize

                { Set-IBMSVSnapshot -Name 'pwsh_snap0' -NewName 'pwsh_snap1' -VolumeGroup 'pwsh_vg0' } | Should -Throw "Both 'pwsh_snap0' and 'pwsh_snap1' exist. Cannot rename, cannot proceed with other updates."
            }
        }

        It "Should update ownership group for volumegroup snapshot" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lsvolumegroupsnapshot') {
                    return @{
                        name = 'pwsh_snap0'
                        volume_group_name = 'pwsh_vg0'
                        owner_name = 'pwsh_og0'
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVSnapshot -Name 'pwsh_snap0' -VolumeGroup 'pwsh_vg0' -OwnershipGroup 'pwsh_og1'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0:volume_group_name=pwsh_vg0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chsnapshot' -and
                    $CmdOpts.ownershipgroup -eq 'pwsh_og1' -and
                    $CmdOpts.snapshot -eq 'pwsh_snap0' -and
                    $CmdOpts.volumegroup -eq 'pwsh_vg0'
                }
        }

        It "Should rename and update ownership group for volumegroup snapshot" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                $script:callCount++
                if ($Cmd -eq 'lsvolumegroupsnapshot') {
                    if ($script:callCount -eq 1) {
                        return @{
                            name = 'pwsh_snap0'
                            volume_group_name = 'pwsh_vg0'
                            owner_name = 'pwsh_og0'
                        }
                    }
                    if ($script:callCount -eq 2) {
                        return $null
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVSnapshot -Name 'pwsh_snap0' -NewName 'pwsh_snap1' -VolumeGroup 'pwsh_vg0' -OwnershipGroup 'pwsh_og1'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0:volume_group_name=pwsh_vg0" }

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap1:volume_group_name=pwsh_vg0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chsnapshot' -and
                    $CmdOpts.name -eq 'pwsh_snap1' -and
                    $CmdOpts.ownershipgroup -eq 'pwsh_og1' -and
                    $CmdOpts.snapshot -eq 'pwsh_snap0' -and
                    $CmdOpts.volumegroup -eq 'pwsh_vg0'
                }
        }

        It "Should be idempotent when no changes are required for volumegroup snapshot" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lsvolumegroupsnapshot') {
                    return @{
                        name = 'pwsh_snap0'
                        volume_group_name = 'pwsh_vg0'
                        owner_name = 'pwsh_og0'
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVSnapshot -Name 'pwsh_snap0' -NewName 'pwsh_snap0' -VolumeGroup 'pwsh_vg0' -OwnershipGroup 'pwsh_og0'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsvolumegroupsnapshot' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chsnapshot' }
        }
    }

    Context "Volume-based Snapshots" {
        It "Should throw error when volume snapshot does not exist" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lsvolumegroupsnapshot') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVSnapshot -Name 'pwsh_snap0' } | Should -Throw "Snapshot 'pwsh_snap0' does not exist."
        }

        Context "Rename Functionality" {
            It "Should throw error when both volume snapshots does not exist" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd)
                    if ($Cmd -eq 'lsvolumegroupsnapshot') {
                        return $null
                    }
                } -ModuleName IBMStorageVirtualize

                { Set-IBMSVSnapshot -Name 'pwsh_snap0' -NewName 'pwsh_snap1' } | Should -Throw "Snapshot 'pwsh_snap0' does not exist."
            }

            It "Should rename the volume snapshot when NewName is different" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd)
                    $script:callCount++
                    if ($Cmd -eq 'lsvolumegroupsnapshot') {
                        if ($script:callCount -eq 1) {
                            return @{
                                name = 'pwsh_snap0'
                                parent_uid = '0'
                                volume_group_name = ''
                            }
                        }
                        if ($script:callCount -eq 2) {
                            return $null
                        }
                    }
                } -ModuleName IBMStorageVirtualize

                Set-IBMSVSnapshot -Name 'pwsh_snap0' -NewName 'pwsh_snap1'

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0" }

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap1" }

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq 'chsnapshot' -and
                        $CmdOpts.name -eq 'pwsh_snap1' -and
                        $CmdOpts.snapshot -eq 'pwsh_snap0' -and
                        $CmdOpts.parentuid -eq '0'
                    }
            }

            It "Should not throw error if -Name snapshot does not exist but -NewName snapshot exists for volume snapshot" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd)
                    $script:callCount++
                    if ($Cmd -eq 'lsvolumegroupsnapshot') {
                        if ($script:callCount -eq 1) {
                            return $null
                        }
                        if ($script:callCount -eq 2) {
                            return @{
                                name = 'pwsh_snap1'
                                parent_uid = '0'
                                volume_group_name = ''
                                owner_name = 'pwsh_og0'
                            }
                        }
                    }
                } -ModuleName IBMStorageVirtualize

                Set-IBMSVSnapshot -Name 'pwsh_snap0' -NewName 'pwsh_snap1' -OwnershipGroup 'pwsh_og1'

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0" }

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap1" }

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq 'chsnapshot' -and
                        $CmdOpts.ownershipgroup -eq 'pwsh_og1' -and
                        $CmdOpts.snapshot -eq 'pwsh_snap1' -and
                        $CmdOpts.parentuid -eq '0'
                    }
            }

            It "Should throw error if both -Name snapshot and -NewName snapshot exist for volume snapshot" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd)
                    $script:callCount++
                    if ($Cmd -eq 'lsvolumegroupsnapshot') {
                        if ($script:callCount -eq 1) {
                            return @{
                                name = 'pwsh_snap0'
                                parent_uid = '0'
                                volume_group_name = ''
                            }
                        }
                        if ($script:callCount -eq 2) {
                            return @{
                                name = 'pwsh_snap1'
                                parent_uid = '1'
                                volume_group_name = ''
                            }
                        }
                    }
                } -ModuleName IBMStorageVirtualize

                { Set-IBMSVSnapshot -Name 'pwsh_snap0' -NewName 'pwsh_snap1' } | Should -Throw "Both 'pwsh_snap0' and 'pwsh_snap1' exist. Cannot rename, cannot proceed with other updates."
            }
        }

        It "Should update ownership group for volume snapshot" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lsvolumegroupsnapshot') {
                    return @(
                        @{
                            name = 'pwsh_snap0'
                            parent_uid = '0'
                            volume_group_name = ''
                            owner_name = 'pwsh_og0'
                        }
                    )
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVSnapshot -Name 'pwsh_snap0' -OwnershipGroup 'pwsh_og1'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chsnapshot' -and
                    $CmdOpts.ownershipgroup -eq 'pwsh_og1' -and
                    $CmdOpts.snapshot -eq 'pwsh_snap0' -and
                    $CmdOpts.parentuid -eq '0'
                }
        }

        It "Should rename and update ownership group for volume snapshot" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                $script:callCount++
                if ($Cmd -eq 'lsvolumegroupsnapshot') {
                    if ($script:callCount -eq 1) {
                        return @(
                            @{
                                name = 'pwsh_snap0'
                                parent_uid = '0'
                                volume_group_name = ''
                                owner_name = 'pwsh_og0'
                            }
                        )
                    }
                    if ($script:callCount -eq 2) {
                        return $null
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVSnapshot -Name 'pwsh_snap0' -NewName 'pwsh_snap1' -OwnershipGroup 'pwsh_og1'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap0" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.filtervalue -eq "name=pwsh_snap1" }

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq 'chsnapshot' -and
                    $CmdOpts.name -eq 'pwsh_snap1' -and
                    $CmdOpts.ownershipgroup -eq 'pwsh_og1' -and
                    $CmdOpts.snapshot -eq 'pwsh_snap0' -and
                    $CmdOpts.parentuid -eq '0'
                }
        }

        It "Should be idempotent when no changes are required for volume snapshot" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lsvolumegroupsnapshot') {
                    return @{
                        name = 'pwsh_snap0'
                        parent_uid = '0'
                        volume_group_name = ''
                        owner_name = 'pwsh_og0'
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVSnapshot -Name 'pwsh_snap0' -NewName 'pwsh_snap0' -OwnershipGroup 'pwsh_og0'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsvolumegroupsnapshot' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chsnapshot' }
        }
    }
}
