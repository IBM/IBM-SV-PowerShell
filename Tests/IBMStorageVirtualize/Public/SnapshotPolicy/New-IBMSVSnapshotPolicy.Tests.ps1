Describe "New-IBMSVSnapshotPolicy Tests" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lssnapshotpolicy") {
                if ($script:callCount -eq 1) {
                    return $null
                }
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

            if ($Cmd -eq "mksnapshotpolicy") {
                return [pscustomobject]@{ id = '0'; message = 'Snapshot policy created successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when BackupStartTime format is invalid" {
        { New-IBMSVSnapshotPolicy -Name "pwsh_sp0" -BackupUnit "day" -BackupInterval 65534 -BackupStartTime "21022818" -RetentionDays 5 } | Should -Throw "Parameter -BackupStartTime must be in format YYMMDDHHMM."
    }

    It "Should accept valid Backupaunit valus" {
        $validUnits = @("minute", "hour", "day", "week", "month")
        foreach ($unit in $validUnits) {
            { New-IBMSVSnapshotPolicy -Name "pwsh_sp0" -BackupUnit $unit -BackupInterval 65534 -BackupStartTime "2102281800" -RetentionDays 5 -WhatIf } | Should -Not -Throw
        }
    }

    It "Should not call API to create snapshot policy when -WhatIf is specified" {
        New-IBMSVSnapshotPolicy -Name "pwsh_sp0" -BackupUnit "day" -BackupInterval "1" -BackupStartTime "2102281800" -RetentionDays "15" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should create a snapshot policy with daily backups" {
        $result = New-IBMSVSnapshotPolicy -Name "pwsh_sp0" -BackupUnit "day" -BackupInterval "1" -BackupStartTime "2102281800" -RetentionDays "15"
        $result.name | Should -Be 'pwsh_sp0'
        $result.id | Should -Be '0'
        $result.backup_unit | Should -Be 'day'
        $result.backup_interval | Should -Be '1'
        $result.retention_days | Should -Be '15'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lssnapshotpolicy" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mksnapshotpolicy" -and
                $CmdOpts.name -eq "pwsh_sp0" -and
                $CmdOpts.backupunit -eq "day" -and
                $CmdOpts.backupinterval -eq "1" -and
                $CmdOpts.backupstarttime -eq "2102281800" -and
                $CmdOpts.retentiondays -eq "15"
            }
    }

    It "Should be idempotent when snapshot policy already exits" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lssnapshotpolicy") {
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
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVSnapshotPolicy -Name "pwsh_sp0" -BackupUnit "day" -BackupInterval "1" -BackupStartTime "2102281800" -RetentionDays "15"
        $result.name | Should -Be 'pwsh_sp0'
        $result.id | Should -Be '0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lssnapshotpolicy" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mksnapshotpolicy" }
    }
}
