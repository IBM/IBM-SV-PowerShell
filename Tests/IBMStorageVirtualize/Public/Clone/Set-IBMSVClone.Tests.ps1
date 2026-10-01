Describe "Set-IBMSVClone" {

    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd, $CmdOpts, $CmdArgs)

            switch ($Cmd) {
                "lsvdisk" {
                    return @(
                        [pscustomobject]@{ name = 'vol_thinclone0'; volume_type = 'thinclone' }
                        [pscustomobject]@{ name = 'vol_thinclone1'; volume_type = 'thinclone' }
                        [pscustomobject]@{ name = 'vol_clone';      volume_type = 'clone' }
                        [pscustomobject]@{ name = 'vol_standard';   volume_type = '' }
                    )
                }
                "lsvolumegroup" {
                    if ($CmdArgs -contains "vg_thinclone") {
                        return [pscustomobject]@{ name = 'vg_thinclone'; volume_group_type = 'thinclone' }
                    }
                    if ($CmdArgs -contains "vg_clone") {
                        return [pscustomobject]@{ name = 'vg_clone'; volume_group_type = 'clone' }
                    }
                    return $null
                }
                "converttoclone" {
                    return $null
                }
            }
        } -ModuleName IBMStorageVirtualize
    }

    Context "Parameter Validation" {

        It "Should throw error when neither -Volumes nor -VolumeGroup is specified" {
            { Set-IBMSVClone -Type clone } | Should -Throw "Either -Volumes or -VolumeGroup parameter must be specified."
        }

        It "Should throw error when both -Volumes and -VolumeGroup are specified" {
            { Set-IBMSVClone -Type clone -Volumes "vol_thinclone0" -VolumeGroup "vg_thinclone" } | Should -Throw "Parameters -Volumes and -VolumeGroup are mutually exclusive."
        }

        It "Should throw error when a non-existent volume is specified" {
            { Set-IBMSVClone -Type clone -Volumes "nonexistent_vol" } | Should -Throw "The following volume(s) do not exist: nonexistent_vol"
        }

        It "Should throw error when multiple non-existent volumes are specified" {
            { Set-IBMSVClone -Type clone -Volumes "nonexistent_vol0","nonexistent_vol1" } | Should -Throw "The following volume(s) do not exist: nonexistent_vol0, nonexistent_vol1"
        }

        It "Should throw error when a mix of existing and non-existent volumes is specified" {
            { Set-IBMSVClone -Type clone -Volumes "vol_thinclone0","nonexistent_vol" } | Should -Throw "The following volume(s) do not exist: nonexistent_vol"
        }

        It "Should throw error when a non-existent VolumeGroup is specified" {
            { Set-IBMSVClone -Type clone -VolumeGroup "nonexistent_vg" } | Should -Throw "VolumeGroup 'nonexistent_vg' does not exist."
        }

        It "Should not call converttoclone when -WhatIf is specified (volume path)" {
            Set-IBMSVClone -Type clone -Volumes "vol_thinclone0" -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "converttoclone" }
        }

        It "Should not call converttoclone when -WhatIf is specified (volumegroup path)" {
            Set-IBMSVClone -Type clone -VolumeGroup "vg_thinclone" -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "converttoclone" }
        }
    }

    Context "Volume Thinclone to Clone Conversion" {

        It "Should convert a single thinclone volume to clone" {
            Set-IBMSVClone -Type clone -Volumes "vol_thinclone0"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvdisk" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "converttoclone" -and
                    $CmdOpts.volumes -eq "vol_thinclone0"
                }
        }

        It "Should convert multiple thinclone volumes to clone (array syntax)" {
            Set-IBMSVClone -Type clone -Volumes "vol_thinclone0","vol_thinclone1"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvdisk" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "converttoclone" -and
                    $CmdOpts.volumes -eq "vol_thinclone0:vol_thinclone1"
                }
        }

        It "Should convert multiple thinclone volumes to clone (colon-separated string)" {
            Set-IBMSVClone -Type clone -Volumes "vol_thinclone0:vol_thinclone1"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvdisk" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "converttoclone" -and
                    $CmdOpts.volumes -eq "vol_thinclone0:vol_thinclone1"
                }
        }

        It "Should convert only thinclone volumes when a mixed list is provided (clone skipped)" {
            Set-IBMSVClone -Type clone -Volumes "vol_thinclone0","vol_clone","vol_thinclone1"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "converttoclone" -and
                    $CmdOpts.volumes -eq "vol_thinclone0:vol_thinclone1"
                }
        }

        It "Should convert only thinclone volumes when a mixed list is provided (standard vol skipped)" {
            Set-IBMSVClone -Type clone -Volumes "vol_thinclone0","vol_standard"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "converttoclone" -and
                    $CmdOpts.volumes -eq "vol_thinclone0"
                }
        }

        It "Should not call converttoclone when volume is already a clone" {
            Set-IBMSVClone -Type clone -Volumes "vol_clone"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvdisk" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "converttoclone" }
        }

        It "Should not call converttoclone when volume has standard type (empty volume_type)" {
            Set-IBMSVClone -Type clone -Volumes "vol_standard"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvdisk" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "converttoclone" }
        }

        It "Should not call converttoclone when all specified volumes are already clones or standard" {
            Set-IBMSVClone -Type clone -Volumes "vol_clone","vol_standard"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvdisk" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "converttoclone" }
        }
    }

    Context "VolumeGroup Thinclone to Clone Conversion" {
        It "Should convert a thinclone volumegroup to clone" {
            Set-IBMSVClone -Type clone -VolumeGroup "vg_thinclone"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroup" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "converttoclone" -and
                    $CmdOpts.volumegroup -eq "vg_thinclone"
                }
        }

        It "Should not call converttoclone when volumegroup is already a clone" {
            Set-IBMSVClone -Type clone -VolumeGroup "vg_clone"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroup" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "converttoclone" }
        }
    }
}
