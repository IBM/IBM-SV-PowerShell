Describe "Set-IBMSVVolume Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return @(
                    @{
                        name = 'pwsh_vol0'
                        capacity = "1073741824"
                        cache = 'none'
                        IOPs_limit = 50
                        bandwidth_limit_MB = 10
                        udid = '1234'
                        sync_rate = '50'
                        mirror_write_priority = 'latency'
                        volume_group_name = ''
                        cloud_backup_enabled = 'no'
                        cloud_account_name = ''
                        backup_grain_size = ''
                        vdisk_UID = '60050768108101C7C0000000000001A1'
                    },
                    @{
                        se_copy = 'no'
                        compressed_copy = 'no'
                        warning = 80
                        autoexpand = 'on'
                        easy_tier = 'on'
                    }
                )
            }
            if ($Cmd -eq "lsvdiskaccess") {
                return @(
                    @{ VDisk_id = 0; VDisk_name = 'pwsh_vol0'; IO_group_id = '0'; IO_group_name = 'io_grp0' }
                )
            }

            return @{}
        } -ModuleName IBMStorageVirtualize

        Mock Get-IBMSVVersion { return "9.1.0.0" } -ModuleName IBMStorageVirtualize

        $script:count = 0
    }

    It "Should throw error when VolumeGroup and NoVolumeGroup are both specified" {
        { Set-IBMSVVolume -Name 'pwsh_vol0' -VolumeGroup pwsh_vg1 -NoVolumeGroup } | Should -Throw "Parameters -VolumeGroup and -NoVolumeGroup are mutually exclusive."
    }

    It "Should throw error when Size and Warning are both specified" {
        { Set-IBMSVVolume -Name 'pwsh_vol0' -Size 1024 -Warning "80%" } | Should -Throw "Parameters -Size and -Warning are mutually exclusive."
    }

    It "Should throw error when Unit is specified without Size or Warning" {
        { Set-IBMSVVolume -Name 'pwsh_vol0' -Unit gb } | Should -Throw "CMMVC5731E Parameter -Unit is invalid without -Size or -Warning."
    }

    It "Should throw error when CloudBackup enable is used without CloudAccountName" {
        { Set-IBMSVVolume -Name 'pwsh_vol0' -CloudBackup "enable" } | Should -Throw "Parameter -CloudAccountName is required when -CloudBackup is 'enable'."
    }

    It "Should throw error when CloudAccountName is used without enabling CloudBackup" {
        { Set-IBMSVVolume -Name 'pwsh_vol0' -CloudAccountName "test_acc" } | Should -Throw "Parameter -CloudAccountName can only be used when -CloudBackup is 'enable'."
    }

    It "Should throw error when BackupGrainsize is used without CloudBackup enable" {
        { Set-IBMSVVolume -Name 'pwsh_vol0' -BackupGrainsize 64 } | Should -Throw "Parameter -BackupGrainsize can only be used when -CloudBackup is 'enable'."
    }

    It "Should throw error when RetainBackupEnabled is used without NoVolumeGroup" {
        { Set-IBMSVVolume -Name 'pwsh_vol0' -RetainBackupEnabled } | Should -Throw "Parameter -RetainBackupEnabled requires -NoVolumeGroup."
    }

    It "Should throw error when duplicate values are provided" {
        { Set-IBMSVVolume -Name "pwsh_vol0" -IOGrp "0:1:1" } | Should -Throw "Duplicate IOGrp values found: 1"
    }

    It "Should throw error when volume does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsvdisk") { return $null }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVVolume -Name 'pwsh_vol0' } | Should -Throw "Volume 'pwsh_vol0' does not exist."
    }

    It "Should throw error when both volume and new name not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsvdisk") { return $null }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVVolume -Name 'pwsh_vol0' -NewName 'pwsh_vol1' } | Should -Throw "Volume 'pwsh_vol0' does not exist."
    }

    It "Should not call API to update volume when -WhatIf is specified" {
        Set-IBMSVVolume -Name 'pwsh_vol0' -Size 2048 -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -in @("chvolume", "chvdisk", "expandvdisksize", "shrinkvdisksize") }
    }

    It "Should rename the volume when NewName is different" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq "lsvdisk") {
                if ($script:count -eq 1) {
                    return @(
                        @{ name = 'pwsh_vol0'; id = '0'; volume_group_name = '' },
                        @{ se_copy = 'no'; compressed_copy = 'no' }
                    )
                }
                return $null
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolume -Name 'pwsh_vol0' -NewName 'pwsh_vol1' -VolumeGroup 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chvolume" }
    }

    It "Should not throw error if -Name volume does not exist but -NewName volume exists and proceed to update other params on -NewName volume" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:count++
            if ($Cmd -eq "lsvdisk") {
                if ($script:count -eq 1) { return $null }
                return @(
                    @{ name = 'pwsh_vol1'; id = '1'; volume_group_name = '' },
                    @{ se_copy = 'no'; compressed_copy = 'no' }
                )
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolume -Name 'pwsh_vol0' -NewName 'pwsh_vol1' -VolumeGroup 'pwsh_vg0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chvolume" }
    }

    It "Should throw error if both -Name volume and -NewName volume exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:count++
            if ($Cmd -eq "lsvdisk") {
                if ($script:count -eq 1) {
                    return @(
                        @{ name = 'pwsh_vol0'; id = '0' },
                        @{ se_copy = 'no'; compressed_copy = 'no' }
                    )
                }
                return @(
                    @{ name = 'pwsh_vol1'; id = '1' },
                    @{ se_copy = 'no'; compressed_copy = 'no' }
                )
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVVolume -Name 'pwsh_vol0' -NewName 'pwsh_vol1' -VolumeGroup 'pwsh_vg0' } | Should -Throw "Both 'pwsh_vol0' and 'pwsh_vol1' exist. Cannot rename, cannot proceed with other updates."
    }

    It "Should update cache and rate values" {
        Set-IBMSVVolume -Name 'pwsh_vol0' -Cache 'readwrite' -RateIOPS 100 -RateMBps 20

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 3 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chvdisk" }
    }

    It "Should throw error when Warning is used on non-thin volume" {
        { Set-IBMSVVolume -Name 'pwsh_vol0' -Warning '70%' } | Should -Throw "Parameter -Warning is applicable only for thin-provisioned and compressed volumes."
    }

    It "Should update warning percentage on thin volume" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return @(
                    @{ name = 'thinvol0'; capacity = "1073741824" },
                    @{ se_copy = 'yes'; compressed_copy = 'no'; warning = 80 }
                )
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolume -Name 'thin-vol0' -Warning '70%'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chvdisk" }
    }

    It "Should expand volume when new size is larger(using chvolume)" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return @(
                    @{ name = 'pwsh_vol0'; capacity = "1073741824" },
                    @{ se_copy = 'no'; compressed_copy = 'no' }
                )
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolume -Name 'pwsh_vol0' -Size 2 -Unit 'gb'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chvolume' -and $CmdOpts.size -eq "2" -and $CmdOpts.unit -eq "gb" -and $CmdArgs -eq "pwsh_vol0" }
    }

    It "Should expand volume when new size is larger" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return @(
                    @{ name = 'pwsh_vol0'; capacity = "1073741824" },
                    @{ se_copy = 'no'; compressed_copy = 'no' }
                )
            }
            return @{}
        } -ModuleName IBMStorageVirtualize
        Mock Get-IBMSVVersion { return "8.7.0.0" } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolume -Name 'pwsh_vol0' -Size 2 -Unit 'gb'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'expandvdisksize' -and $CmdOpts.Size -eq "1073741824" }
    }

    It "Should shrink volume when new size is smaller" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return @(
                    @{ name = 'pwsh_vol0'; capacity = 2GB },
                    @{ se_copy = 'no'; compressed_copy = 'no' }
                )
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolume -Name 'pwsh_vol0' -Size 1 -Unit 'gb'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'shrinkvdisksize' }
    }

    It "Should add IO groups" {
        Set-IBMSVVolume -Name 'pwsh_vol0' -IOGrp "0:1"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'addvdiskaccess' }
    }

    It "Should remove IO groups" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return @(
                    @{ name = 'pwsh_vol0'; capacity = "1073741824" },
                    @{ se_copy = 'no'; compressed_copy = 'no' }
                )
            }
            if ($Cmd -eq "lsvdiskaccess") {
                return @(
                    @{ VDisk_id = 0; VDisk_name = 'pwsh_vol0'; IO_group_id = '0'; IO_group_name = 'io_grp0' }
                    @{ VDisk_id = 0; VDisk_name = 'pwsh_vol0'; IO_group_id = '1'; IO_group_name = 'io_grp1' }
                )
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolume -Name 'pwsh_vol0' -IOGrp '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'rmvdiskaccess' }
    }

    It "Should add and remove IO groups to match desired state" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return @(
                    @{ name = 'pwsh_vol0'; capacity = "1073741824" },
                    @{ se_copy = 'no'; compressed_copy = 'no' }
                )
            }
            if ($Cmd -eq "lsvdiskaccess") {
                return @(
                    @{ VDisk_id = 0; VDisk_name = 'pwsh_vol0'; IO_group_id = '0'; IO_group_name = 'io_grp0' }
                    @{ VDisk_id = 0; VDisk_name = 'pwsh_vol0'; IO_group_id = '1'; IO_group_name = 'io_grp1' }
                )
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolume -Name 'pwsh_vol0' -IOGrp '1:2'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'addvdiskaccess' -and $CmdOpts.iogrp -eq 2 }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'rmvdiskaccess' -and $CmdOpts.iogrp -eq 0 }
    }

    It "Should update other parameters" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return @(
                    @{
                        name = 'pwsh_vol0'
                        udid = '1234'
                        sync_rate = '50'
                        mirror_write_priority = 'latency'
                        volume_group_name = 'pwsh_vg0'
                    },
                    @{
                        autoexpand = 'on'
                        easy_tier = 'on'
                        se_copy = 'yes'
                    }
                )
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolume -Name 'pwsh_vol0' -Udid '12345' -AutoExpand 'off' -SyncRate 60 -EasyTier 'off' -MirrorWritePriority 'redundancy' -VolumeGroup 'pwsh_vg1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 5 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chvdisk" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chvolume" }
    }

    It "Should update other parameters with uid" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return @(
                    @{
                        name = 'pwsh_vol0'
                        vdisk_UID = '60050768108101C7C0000000000001A1'
                        udid = '1234'
                        sync_rate = '50'
                        mirror_write_priority = 'latency'
                        volume_group_name = 'pwsh_vg0'
                    },
                    @{
                        autoexpand = 'on'
                        easy_tier = 'on'
                        se_copy = 'yes'
                    }
                )
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolume -Name '60050768108101C7C0000000000001A1' -Udid '12345' -AutoExpand 'off' -SyncRate 60 -EasyTier 'off' -MirrorWritePriority 'redundancy' -VolumeGroup 'pwsh_vg1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 5 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chvdisk" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chvolume" }
    }

    It "Should remove volumegroup with -RetainBackupEnabled parameter" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return @(
                    @{ name = 'pwsh_vol0'; volume_group_name = 'pwsh_vg0' },
                    @{ se_copy = 'no' }
                )
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolume -Name 'pwsh_vol0' -NoVolumeGroup -RetainBackupEnabled

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chvdisk" }
    }

    It "Should enable cloud backup with backup grainsize" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return @(
                    @{
                        name = 'pwsh_vol0'
                        cloud_backup_enabled = 'no'
                        cloud_account_name = ''
                        backup_grain_size = ''
                    },
                    @{ se_copy = 'no' }
                )
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVVolume -Name 'pwsh_vol0' -CloudBackup 'enable' -CloudAccountName 'pwsh_user0' -BackupGrainsize 256

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 3 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chvdisk" }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return @(
                    @{ name = 'pwsh_vol0'; capacity = '1073741824' },
                    @{ se_copy = 'no' }
                )
            }
            if ($Cmd -eq "chvolume") {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/chvolume/pwsh_vol"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVVolume -Name "pwsh_vol0" -Size 2048 } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/chvolume/pwsh_vol"
    }
}
