Describe "New-IBMSVSnapshot Tests" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd, $CmdOpts)

            $script:callCount++

            if ($Cmd -eq "lsvolumegroupsnapshot") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                return [pscustomobject]@{
                    id = '0'
                    name = 'pwsh_snap0'
                    volume_group_id = '0'
                    volume_group_name = $CmdOpts.volumegroup
                }
            }

            if ($Cmd -eq "lsvolumesnapshot") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                return [pscustomobject]@{
                    snapshot_id = '0'
                    snapshot_name = 'pwsh_snap0'
                    volume_id = '0'
                    volume_name = 'pwsh_vol0'
                    volume_group_name = ''
                }
            }

            if ($Cmd -eq "addsnapshot") {
                return [pscustomobject]@{ id = '0'; message = 'Snapshot created successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when VolumeGroup and Volumes are both specified" {
        { New-IBMSVSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -Volumes "pwsh_vol0,pwsh_vol1" -Pool "pwsh_pool0" } | Should -Throw "Parameters -VolumeGroup, -Volumes are mutually exclusive."
    }

    It "Should throw error when neither VolumeGroup nor Volumes are specified" {
        { New-IBMSVSnapshot -Name "pwsh_snap0" -Pool "pwsh_pool0" } | Should -Throw "Either -VolumeGroup or -Volumes must be specified."
    }

    It "Should throw error when RetentionDays and RetentionMinutes are both specified" {
        { New-IBMSVSnapshot -Name "pwsh_snap0" -Volumes "pwsh_vol0" -Pool "pwsh_pool0" -RetentionDays 7 -RetentionMinutes 60 } | Should -Throw "Parameters -RetentionDays, -RetentionMinutes are mutually exclusive."
    }

    It "Should throw error when Safeguarded is set without retention parameter" {
        { New-IBMSVSnapshot -Name "pwsh_snap0" -Volumes "pwsh_vol0" -Pool "pwsh_pool0" -Safeguarded } | Should -Throw "The -RetentionDays parameter is required when the -Safeguarded parameter is specified."
    }

    It "Should not call API to create snapshot when -WhatIf is specified" {
        New-IBMSVSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should create a volume snapshot with required parameters" {
        $result = New-IBMSVSnapshot -Name "pwsh_snap0" -Volumes "pwsh_vol0"
        $result.snapshot_name | Should -Be 'pwsh_snap0'
        $result.snapshot_id | Should -Be '0'
        $result.volume_name | Should -Be 'pwsh_vol0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumesnapshot" -and $CmdOpts.filtervalue -eq "snapshot_name=pwsh_snap0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "addsnapshot" -and
                $CmdOpts.name -eq "pwsh_snap0" -and
                $CmdOpts.volumes -eq "pwsh_vol0"
            }
    }

    It "Should be idempotent when volume snapshot already exists" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsvolumesnapshot") {
                return [pscustomobject]@{
                    snapshot_id = '0'
                    snapshot_name = 'pwsh_snap0'
                    volume_id = '0'
                    volume_name = 'pwsh_vol0'
                    volume_group_name = ''
                }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVSnapshot -Name "pwsh_snap0" -Volumes "pwsh_vol0"
        $result.snapshot_name | Should -Be 'pwsh_snap0'
        $result.snapshot_id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumesnapshot" -and $CmdOpts.filtervalue -eq "snapshot_name=pwsh_snap0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "addsnapshot" }
    }

    It "Should create a volumegroup snapshot with required parameters" {
        $result = New-IBMSVSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0"
        $result.name | Should -Be 'pwsh_snap0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.snapshot -eq "pwsh_snap0" -and $CmdOpts.volumegroup -eq "pwsh_vg0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "addsnapshot" -and
                $CmdOpts.name -eq "pwsh_snap0" -and
                $CmdOpts.volumegroup -eq "pwsh_vg0"
            }
    }

    It "Should be idempotent when volumegroup snapshot already exists" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvolumegroupsnapshot") {
                return [pscustomobject]@{
                    name = 'pwsh_snap0'
                    id = '0'
                    volume_group_name = 'pwsh_vg0'
                }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0"
        $result.name | Should -Be 'pwsh_snap0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.snapshot -eq "pwsh_snap0" -and $CmdOpts.volumegroup -eq "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "addsnapshot" }
    }

    It "Should create a volume snapshot with multiple volumes as array" {
        $volumes = @("pwsh_vol0", "pwsh_vol1")
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:callCount++
            if ($Cmd -eq "lsvolumesnapshot") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                $result = @()
                for ($i = 0; $i -lt $volumes.Count; $i++) {
                    $result += [pscustomobject]@{
                        snapshot_id = '0'
                        snapshot_name = 'pwsh_snap0'
                        volume_id = $i
                        volume_name = $volumes[$i]
                        volume_group_name = ''
                    }
                }
                return $result
            }

            if ($Cmd -eq "addsnapshot") {
                return [pscustomobject]@{ id = '0'; message = 'Snapshot created successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVSnapshot -Name "pwsh_snap0" -Volumes $volumes
        $result.Count | Should -Be 2
        $result[0].snapshot_name | Should -Be 'pwsh_snap0'
        $result[0].volume_name | Should -Be 'pwsh_vol0'
        $result[1].snapshot_name | Should -Be 'pwsh_snap0'
        $result[1].volume_name | Should -Be 'pwsh_vol1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumesnapshot" -and $CmdOpts.filtervalue -eq "snapshot_name=pwsh_snap0"  }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "addsnapshot" -and
                $CmdOpts.name -eq "pwsh_snap0" -and
                $CmdOpts.volumes -eq "pwsh_vol0:pwsh_vol1"
            }
    }

    It "Should create a volume snapshot with multiple volumes as colon-separated string" {
        $volumes = "pwsh_vol0:pwsh_vol1"
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:callCount++
            if ($Cmd -eq "lsvolumesnapshot") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                $volumes = $volumes -split ":"
                $result = @()
                for ($i = 0; $i -lt $volumes.Count; $i++) {
                    $result += [pscustomobject]@{
                        snapshot_id = '0'
                        snapshot_name = 'pwsh_snap0'
                        volume_id = $i
                        volume_name = $volumes[$i]
                        volume_group_name = ''
                    }
                }
                return $result
            }

            if ($Cmd -eq "addsnapshot") {
                return [pscustomobject]@{ id = '0'; message = 'Snapshot created successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVSnapshot -Name "pwsh_snap0" -Volumes $volumes
        $result.Count | Should -Be 2
        $result[0].snapshot_name | Should -Be 'pwsh_snap0'
        $result[0].volume_name | Should -Be 'pwsh_vol0'
        $result[1].snapshot_name | Should -Be 'pwsh_snap0'
        $result[1].volume_name | Should -Be 'pwsh_vol1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumesnapshot" -and $CmdOpts.filtervalue -eq "snapshot_name=pwsh_snap0"  }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "addsnapshot" -and
                $CmdOpts.name -eq "pwsh_snap0" -and
                $CmdOpts.volumes -eq "pwsh_vol0:pwsh_vol1"
            }
    }

    It "Should create a volumegroup snapshot with all parameters" {
        $result = New-IBMSVSnapshot -Name "pwsh_snap0" -VolumeGroup "pwsh_vg0" -Pool "pwsh_pool0" -IgnoreLegacy -Safeguarded -RetentionDays 30
        $result.name | Should -Be 'pwsh_snap0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" -and $CmdOpts.snapshot -eq "pwsh_snap0" -and $CmdOpts.volumegroup -eq "pwsh_vg0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "addsnapshot" -and
                $CmdOpts.name -eq "pwsh_snap0" -and
                $CmdOpts.volumegroup -eq "pwsh_vg0" -and
                $CmdOpts.pool -eq "pwsh_pool0" -and
                $CmdOpts.ignorelegacy -eq $true -and
                $CmdOpts.safeguarded -eq $true -and
                $CmdOpts.retentiondays -eq 30
            }
    }

    It "Should create a volume snapshot with all parameters" {
        $result = New-IBMSVSnapshot -Name "pwsh_snap0" -Volumes "pwsh_vol0:pwsh_vol1" -Pool "pwsh_pool0" -IgnoreLegacy -RetentionMinutes 60
        $result.snapshot_name | Should -Be 'pwsh_snap0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumesnapshot" -and $CmdOpts.filtervalue -eq "snapshot_name=pwsh_snap0"  }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "addsnapshot" -and
                $CmdOpts.name -eq "pwsh_snap0" -and
                $CmdOpts.volumes -eq "pwsh_vol0:pwsh_vol1" -and
                $CmdOpts.pool -eq "pwsh_pool0" -and
                $CmdOpts.ignorelegacy -eq $true -and
                $CmdOpts.retentionminutes -eq 60
            }
    }
}
