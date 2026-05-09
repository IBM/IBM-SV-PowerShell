Describe "New-IBMSVMDisk Tests" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsmdisk") {
                if ($script:callCount -eq 1) { return $null }
                return [pscustomobject]@{ name='pwsh_mdisk0'; id='1'; mdisk_grp_name='pwsh_pool0' }
            }
            if ($Cmd -eq 'mkarray' -or $Cmd -eq 'mkdistributedarray') {
                return [pscustomobject]@{ id='1'; message='MDisk created successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when neither -UseRecommendation nor -Level and -DriveCount is specified (DistributedArray)" {
        { New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0"} | Should -Throw "To create an MDisk you must specify -Level with -Drive, or -Level with -DriveCount, or -UseRecommendation."
    }

    It "Should throw error when -Level is specified without -Drive, -DriveCount, -UserRecommendation" {
        { New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level 'raid0'} | Should -Throw "Parameter -Drive or -DriveCount must be specified when -Level is specified."
    }

    It "Should throw error when -Drive is used without -Level" {
        { New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Drive "0:1:2:3" } | Should -Throw "Parameter -Level is required when using -Drive."
    }

    It "Should throw error when -Level, -StripeWidth, -RebuildAreas, or -RebuildAreasGoal are used with -UseRecommendation" {
        { New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -UseRecommendation -Level "raid0" -StripeWidth 2 -RebuildAreas 2 -RebuildAreasGoal 2 -AllowSuperior} | Should -Throw "Parameter(s) -Level, -StripeWidth, -RebuildAreas, -RebuildAreasGoal, -AllowSuperior cannot be used with -UseRecommendation."
    }

    It "Should throw error when neither -UseRecommendation nor -Level is specified" {
        { New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -DriveCount 2} | Should -Throw "Parameter(s) -Level required when not using -UseRecommendation."
    }

    It "Should throw error when duplicate Drive values are provided" {
        { New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid1" -Drive "0:1:2:1" } | Should -Throw "Duplicate Drive values found: 1"
    }

    It "Should not call API to create MDisk when -WhatIf is specified" {
        New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid5" -DriveCount 6 -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should be idempotent when MDisk already exists" {
        Mock Invoke-IBMSVRestRequest {
            return [pscustomobject]@{ name='pwsh_mdisk0'; id='1'; mdisk_grp_name='pwsh_pool0' }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid5" -DriveCount 6
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsmdisk" -and $CmdArgs -contains "pwsh_mdisk0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -in @('mkarray', 'mkdistributedarray') }
    }

    It "Should create a distributed array MDisk with required parameters" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid5" -DriveCount 6
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsmdisk" -and $CmdArgs -contains "pwsh_mdisk0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkdistributedarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid5" -and
                $CmdOpts.drivecount -eq 6 -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a distributed array MDisk with DriveClass parameter" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid5" -DriveCount 6 -DriveClass 1
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkdistributedarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid5" -and
                $CmdOpts.driveclass -eq 1 -and
                $CmdOpts.drivecount -eq 6 -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a distributed array MDisk with StripeWidth parameter" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid5" -DriveCount 6 -DriveClass 0 -StripeWidth 4
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkdistributedarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid5" -and
                $CmdOpts.driveclass -eq 0 -and
                $CmdOpts.drivecount -eq 6 -and
                $CmdOpts.stripewidth -eq 4 -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a distributed array MDisk with RebuildAreas parameter" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid5" -DriveCount 6 -DriveClass 0 -RebuildAreas 2
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkdistributedarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid5" -and
                $CmdOpts.driveclass -eq 0 -and
                $CmdOpts.drivecount -eq 6 -and
                $CmdOpts.rebuildareas -eq 2 -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a distributed array MDisk with RebuildAreasGoal parameter" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid5" -DriveCount 6 -DriveClass 0 -RebuildAreasGoal 2
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkdistributedarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid5" -and
                $CmdOpts.driveclass -eq 0 -and
                $CmdOpts.drivecount -eq 6 -and
                $CmdOpts.rebuildareasgoal -eq 2 -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a distributed array MDisk with AllowSuperior parameter" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid5" -DriveCount 6 -DriveClass 0 -AllowSuperior
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkdistributedarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid5" -and
                $CmdOpts.driveclass -eq 0 -and
                $CmdOpts.drivecount -eq 6 -and
                $CmdOpts.allowsuperior -eq $true -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a distributed array MDisk with SlowWritePriority parameter" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid5" -DriveCount 6 -DriveClass 0 -SlowWritePriority "latency"
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkdistributedarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid5" -and
                $CmdOpts.driveclass -eq 0 -and
                $CmdOpts.drivecount -eq 6 -and
                $CmdOpts.slowwritepriority -eq "latency" -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a distributed array MDisk with Encrypt parameter" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid5" -DriveCount 6 -DriveClass 0 -Encrypt "yes"
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkdistributedarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid5" -and
                $CmdOpts.driveclass -eq 0 -and
                $CmdOpts.drivecount -eq 6 -and
                $CmdOpts.encrypt -eq "yes" -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a distributed array MDisk with multiple parameters" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid5" -DriveCount 6 -DriveClass 0 -StripeWidth 4 -RebuildAreas 2 -RebuildAreasGoal 2 -AllowSuperior -SlowWritePriority "latency" -Encrypt "yes"
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkdistributedarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid5" -and
                $CmdOpts.drivecount -eq 6 -and
                $CmdOpts.driveclass -eq 0 -and
                $CmdOpts.stripewidth -eq 4 -and
                $CmdOpts.rebuildareas -eq 2 -and
                $CmdOpts.rebuildareasgoal -eq 2 -and
                $CmdOpts.allowsuperior -eq $true -and
                $CmdOpts.slowwritepriority -eq "latency" -and
                $CmdOpts.encrypt -eq "yes" -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a traditional array MDisk with Drive parameter" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid1" -Drive "0:1:2:3"
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid1" -and
                $CmdOpts.drive -eq "0:1:2:3" -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a traditional array MDisk with Drive and SpareGoal parameters" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid1" -Drive "0:1:2:3" -SpareGoal 1
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid1" -and
                $CmdOpts.drive -eq "0:1:2:3" -and
                $CmdOpts.sparegoal -eq 1 -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a traditional array MDisk with Drive and SlowWritePriority parameters" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid1" -Drive "0:1:2:3" -SlowWritePriority "latency"
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid1" -and
                $CmdOpts.drive -eq "0:1:2:3" -and
                $CmdOpts.slowwritepriority -eq "latency" -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a traditional array MDisk with Drive and Encrypt parameters" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid1" -Drive "0:1:2:3" -Encrypt "yes"
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid1" -and
                $CmdOpts.drive -eq "0:1:2:3" -and
                $CmdOpts.encrypt -eq "yes" -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a traditional array MDisk with multiple parameters" {
        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid1" -Drive "0:1:2:3" -SpareGoal 1 -SlowWritePriority "latency" -Encrypt "yes"
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.level -eq "raid1" -and
                $CmdOpts.drive -eq "0:1:2:3" -and
                $CmdOpts.sparegoal -eq 1 -and
                $CmdOpts.slowwritepriority -eq "latency" -and
                $CmdOpts.encrypt -eq "yes" -and
                $CmdOpts.strip -eq 256 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a distributed array MDisk using UseRecommendation" {
        Mock Get-IBMSVArrayRecommendation {
            return @([pscustomobject]@{ drive_count=6; drive_class_id=0; raid_level='raid5'; strip_size=256; stripe_width=4; rebuild_areas=2 })
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -UseRecommendation
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Get-IBMSVArrayRecommendation -Times 1 -ModuleName IBMStorageVirtualize
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkdistributedarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.drivecount -eq 6 -and
                $CmdOpts.driveclass -eq 0 -and
                $CmdOpts.level -eq "raid5" -and
                $CmdOpts.strip -eq 256 -and
                $CmdOpts.stripewidth -eq 4 -and
                $CmdOpts.rebuildareas -eq 2 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should create a distributed array MDisk using UseRecommendation with DriveCount" {
        Mock Get-IBMSVArrayRecommendation {
            return @([pscustomobject]@{ drive_count=3; drive_class_id=0; raid_level='raid1'; strip_size=256; stripe_width=2; rebuild_areas=1 })
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -UseRecommendation -DriveCount 3
        $result.name | Should -Be 'pwsh_mdisk0'

        Assert-MockCalled Get-IBMSVArrayRecommendation -Times 1 -ModuleName IBMStorageVirtualize
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkdistributedarray" -and
                $CmdOpts.name -eq "pwsh_mdisk0" -and
                $CmdOpts.drivecount -eq 3 -and
                $CmdOpts.driveclass -eq 0 -and
                $CmdOpts.level -eq "raid1" -and
                $CmdOpts.strip -eq 256 -and
                $CmdOpts.stripewidth -eq 2 -and
                $CmdOpts.rebuildareas -eq 1 -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should throw error when UseRecommendation returns no recommendations" {
        Mock Get-IBMSVArrayRecommendation { return @() } -ModuleName IBMStorageVirtualize

        { New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -UseRecommendation } | Should -Throw "No array recommendations available for the specified parameters."
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsmdisk") {
                return $null
            }

            if ($Cmd -eq "mkdistributedarray") {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/mkdistributedarray/pwsh_pool"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { New-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Level "raid5" -DriveCount 6 } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/mkdistributedarray/pwsh_pool"
    }
}
