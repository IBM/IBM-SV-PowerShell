Describe "New-IBMSVClone" {

    # ── Shared mock helpers ───────────────────────────────────────────────────
    # $script:callCount is reset in BeforeEach so the "first call = not found,
    # second call = return object" pattern used across this project works reliably.

    BeforeEach {
        $script:callCount = 0

        Mock Invoke-IBMSVRestRequest {
            param($Cmd, $CmdOpts, $CmdArgs)
            $script:callCount++

            switch ($Cmd) {
                "lsvdisk" {
                    if ($script:callCount -eq 1) { return $null }
                    return [pscustomobject]@{
                        id          = '10'
                        name        = 'pwsh_clone_vol0'
                        volume_type = 'clone'
                    }
                }
                "lsvolumegroup" {
                    if ($script:callCount -eq 1) { return $null }
                    return [pscustomobject]@{
                        id                = '5'
                        name              = 'pwsh_clone_vg0'
                        volume_group_type = 'clone'
                    }
                }
                "lsvolumesnapshot" {
                    return [pscustomobject]@{
                        snapshot_name    = 'pwsh_snap0'
                        volume_name      = 'pwsh_vol0'
                        parent_uid       = 'uid-001'
                        volume_group_name = ''
                    }
                }
                "lsvolumegroupsnapshot" {
                    return [pscustomobject]@{
                        name              = 'pwsh_snap0'
                        volume_group_name = 'pwsh_vg0'
                        parent_uid        = 'uid-002'
                    }
                }
                "mkvolume" {
                    return [pscustomobject]@{ id = '10' }
                }
                "mkvolumegroup" {
                    return [pscustomobject]@{ id = '5' }
                }
            }
        } -ModuleName IBMStorageVirtualize
    }

    # ── Parameter Validation ──────────────────────────────────────────────────
    Context "Parameter Validation" {

        It "Should throw error when -Partition and -DraftPartition are both specified" {
            { New-IBMSVClone -Name "pwsh_clone_vg0" -Type "clone" -Snapshot "pwsh_snap0" -Partition "ptn1" -DraftPartition "draft_ptn1" } | Should -Throw "Parameters -Partition and -DraftPartition are mutually exclusive."
        }

        It "Should throw error when PreferredNode is provided without single IOGrp" {
            { New-IBMSVClone -Name "pwsh_clone_vg0" -Type "clone" -Snapshot "pwsh_snap0" -IOGrp "io_grp1:io_grp2" -PreferredNode "node1" } | Should -Throw "Parameter -PreferredNode is only valid with a single iogrp."
        }

        It "Should throw error when -Pool is missing for a volume clone" {
            { New-IBMSVClone -Name "pwsh_clone_vol0" -Type "clone" -Snapshot "pwsh_snap0" -FromSourceVolumes "pwsh_vol0" } | Should -Throw "Parameter -Pool is required for volume clone creation."
        }

        It "Should throw error when -Partition is used on a volume clone path" {
            { New-IBMSVClone -Name "pwsh_clone_vol0" -Type "clone" -Snapshot "pwsh_snap0" -FromSourceVolumes "pwsh_vol0" -Pool "pool0" -Partition "ptn1" } | Should -Throw "Volume clone operation does not support the parameter(s): -Partition."
        }

        It "Should throw error when multiple VG-only params are used on a volume clone path" {
            { New-IBMSVClone -Name "pwsh_clone_vol0" -Type "clone" -Snapshot "pwsh_snap0" -FromSourceVolumes "pwsh_vol0" -Pool "pool0" -DraftPartition "draft_ptn1" -OwnershipGroup "og1" -IgnoreUserFCMaps } | Should -Throw "Volume clone operation does not support the parameter(s): -DraftPartition, -OwnershipGroup, -IgnoreUserFCMaps."
        }

        It "Should throw error when -VolumeGroup is used on a volumegroup clone path" {
            { New-IBMSVClone -Name "pwsh_clone_vg0" -Type "clone" -Snapshot "pwsh_snap0" -VolumeGroup "vg1" } | Should -Throw "Volumegroup clone operation does not support the parameter(s): -VolumeGroup."
        }

        It "Should throw error when both -VolumeGroup and -PreferredNode are used on a volumegroup clone path" {
            { New-IBMSVClone -Name "pwsh_clone_vg0" -Type "clone" -Snapshot "pwsh_snap0" -VolumeGroup "vg1" -IOGrp "io_grp0" -PreferredNode "node1" } | Should -Throw "Volumegroup clone operation does not support the parameter(s): -VolumeGroup, -PreferredNode."
        }

        It "Should not call any API when -WhatIf is specified (volume path)" {
            New-IBMSVClone -Name "pwsh_clone_vol0" -Type "clone" -Snapshot "pwsh_snap0" -FromSourceVolumes "pwsh_vol0" -Pool "pool0" -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }

        It "Should not call any API when -WhatIf is specified (volumegroup path)" {
            New-IBMSVClone -Name "pwsh_clone_vg0" -Type "clone" -Snapshot "pwsh_snap0" -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }
    }

    Context "Volume Clone" {
        It "Should create a volume clone with required parameters" {
            $result = New-IBMSVClone -Name "pwsh_clone_vol0" -Type "clone" -Snapshot "pwsh_snap0" -FromSourceVolumes "pwsh_vol0" -Pool "pool0"
            $result.name        | Should -Be 'pwsh_clone_vol0'
            $result.volume_type | Should -Be 'clone'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvdisk" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumesnapshot" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "mkvolume" -and
                    $CmdOpts.name              -eq "pwsh_clone_vol0" -and
                    $CmdOpts.type              -eq "clone" -and
                    $CmdOpts.snapshot          -eq "pwsh_snap0" -and
                    $CmdOpts.fromsourcevolume  -eq "pwsh_vol0" -and
                    $CmdOpts.pool              -eq "pool0" -and
                    $CmdOpts.fromsourceuid     -eq "uid-001"
                }
        }

        It "Should create a volume thinclone with required parameters" {
            $result = New-IBMSVClone -Name "pwsh_clone_vol0" -Type "thinclone" -Snapshot "pwsh_snap0" -FromSourceVolumes "pwsh_vol0" -Pool "pool0"
            $result.name | Should -Be 'pwsh_clone_vol0'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvdisk" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumesnapshot" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "mkvolume" -and
                    $CmdOpts.name              -eq "pwsh_clone_vol0" -and
                    $CmdOpts.type              -eq "thinclone"
                    $CmdOpts.snapshot          -eq "pwsh_snap0" -and
                    $CmdOpts.fromsourcevolume  -eq "pwsh_vol0" -and
                    $CmdOpts.pool              -eq "pool0" -and
                    $CmdOpts.fromsourceuid     -eq "uid-001"
                }
        }

        It "Should use fromsourcegroup when volumegroup snapshot is used for volume clone" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                $script:callCount++
                if ($Cmd -eq "lsvdisk") {
                    if ($script:callCount -eq 1) { return $null }
                    return [pscustomobject]@{ id = '0'; name = 'pwsh_clone_vol0'; volume_group_type = 'clone' }
                }
                if ($Cmd -eq "lsvolumesnapshot") {
                    return [pscustomobject]@(
                        [pscustomobject]@{ name = 'pwsh_snap0'; volume_name = "pwsh_vol0"; volume_group_name = 'pwsh_vg0'; parent_uid = 'uid-003' }
                        [pscustomobject]@{ name = 'pwsh_snap0'; volume_name = "pwsh_vol1"; volume_group_name = 'pwsh_vg0'; parent_uid = 'uid-003' }
                        [pscustomobject]@{ name = 'pwsh_snap0'; volume_name = "pwsh_vol2"; volume_group_name = 'pwsh_vg0'; parent_uid = 'uid-003' }
                    )
                }
                if ($Cmd -eq "mkvolume") { return [pscustomobject]@{ id = '0' } }
            } -ModuleName IBMStorageVirtualize

            New-IBMSVClone -Name "pwsh_clone_vol0" -Type "clone" -Snapshot "pwsh_snap0" -FromSourceVolumes "pwsh_vol0" -Pool "pool0"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvdisk" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumesnapshot" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "mkvolume" -and
                    $CmdOpts.name             -eq "pwsh_clone_vol0" -and
                    $CmdOpts.type             -eq "clone" -and
                    $CmdOpts.snapshot         -eq "pwsh_snap0" -and
                    $CmdOpts.fromsourcevolume -eq 'pwsh_vol0' -and
                    $CmdOpts.pool             -eq 'pool0' -and
                    $CmdOpts.fromsourcegroup  -eq 'pwsh_vg0' -and
                    -not $CmdOpts.ContainsKey('fromsourceuid')
                }
        }

        It "Should create a volume clone with all optional parameters" {
            $result = New-IBMSVClone -Name "pwsh_clone_vol0" -Type "clone" -Snapshot "pwsh_snap0" -FromSourceVolumes "pwsh_vol0" -Pool "pool0" -IOGrp "io_grp0" -VolumeGroup "vg1" -PreferredNode "node1"
            $result.name | Should -Be 'pwsh_clone_vol0'
            
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvdisk" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumesnapshot" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "mkvolume" -and
                    $CmdOpts.name             -eq "pwsh_clone_vol0" -and
                    $CmdOpts.type             -eq "clone" -and
                    $CmdOpts.snapshot         -eq "pwsh_snap0" -and
                    $CmdOpts.fromsourcevolume -eq "pwsh_vol0" -and
                    $CmdOpts.pool             -eq "pool0" -and
                    $CmdOpts.iogrp            -eq "io_grp0" -and
                    $CmdOpts.volumegroup      -eq "vg1" -and
                    $CmdOpts.preferrednode    -eq "node1" -and
                    $CmdOpts.fromsourceuid    -eq "uid-001"
                }
        }

        It "Should be idempotent when volume clone already exists" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsvdisk") {
                    return [pscustomobject]@{ id = '10'; name = 'pwsh_clone_vol0'; volume_type = 'clone' }
                }
            } -ModuleName IBMStorageVirtualize

            $result = New-IBMSVClone -Name "pwsh_clone_vol0" -Type "clone" -Snapshot "pwsh_snap0" -FromSourceVolumes "pwsh_vol0" -Pool "pool0"
            $result.name | Should -Be 'pwsh_clone_vol0'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvdisk" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -in ("lsvolumesnapshot", "mkvolume") }
        }

        It "Should throw error when snapshot does not exist for volume clone" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsvdisk")           { return $null }
                if ($Cmd -eq "lsvolumesnapshot")  { return $null }
            } -ModuleName IBMStorageVirtualize

            { New-IBMSVClone -Name "pwsh_clone_vol0" -Type "clone" -Snapshot "no_snap" -FromSourceVolumes "pwsh_vol0" -Pool "pool0" } | Should -Throw "Snapshot 'no_snap' does not exist."
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -in ("lsvdisk", "lsvolumesnapshot") }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "mkvolume" }
        }

        It "Should throw error when mkvolume REST call fails" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                $script:callCount++
                if ($Cmd -eq "lsvdisk")           { if ($script:callCount -eq 1) { return $null } }
                if ($Cmd -eq "lsvolumesnapshot")  {
                    return [pscustomobject]@{ snapshot_name = 'pwsh_snap0'; parent_uid = 'uid-001'; volume_group_name = '' }
                }
                if ($Cmd -eq "mkvolume") {
                    return [pscustomobject]@{
                        url  = "https://1.1.1.1:7443/rest/v1/mkvolume"
                        code = 500; err = "HTTPError failed"; out = @{}; data = @{}
                    }
                }
            } -ModuleName IBMStorageVirtualize

            { New-IBMSVClone -Name "pwsh_clone_vol0" -Type "clone" -Snapshot "pwsh_snap0" -FromSourceVolumes "pwsh_vol0" -Pool "pool0" } | Should -Throw
        }
    }

    Context "VolumeGroup Clone" {
        It "Should default to volumegroup clone when -FromSourceVolumes is not specified" {
            $result = New-IBMSVClone -Name "pwsh_clone_vg0" -Type "clone" -Snapshot "pwsh_snap0"
            $result.name              | Should -Be 'pwsh_clone_vg0'
            $result.volume_group_type | Should -Be 'clone'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroup" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "mkvolumegroup" -and
                    $CmdOpts.name     -eq "pwsh_clone_vg0" -and
                    $CmdOpts.type     -eq "clone" -and
                    $CmdOpts.snapshot -eq "pwsh_snap0" -and
                    $CmdOpts.fromsourcegroup -eq "pwsh_vg0"
                }
        }

        It "Should create a volumegroup thinclone" {
            $result = New-IBMSVClone -Name "pwsh_clone_vg0" -Type "thinclone" -Snapshot "pwsh_snap0"
            $result.name | Should -Be 'pwsh_clone_vg0'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroup" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "mkvolumegroup" -and
                    $CmdOpts.name     -eq "pwsh_clone_vg0" -and
                    $CmdOpts.type     -eq "thinclone" -and
                    $CmdOpts.snapshot -eq "pwsh_snap0" -and
                    $CmdOpts.fromsourcegroup -eq "pwsh_vg0"
                }
        }

        It "Should use fromsourceuid when snapshot has no volume_group_name(using volume or multivolume snashot for clone)" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                $script:callCount++
                if ($Cmd -eq "lsvolumegroup") {
                    if ($script:callCount -eq 1) { return $null }
                    return [pscustomobject]@{ id = '5'; name = 'pwsh_clone_vg0'; volume_group_type = 'clone' }
                }
                if ($Cmd -eq "lsvolumegroupsnapshot") {
                    return [pscustomobject]@{ name = 'pwsh_snap0'; volume_group_name = ''; parent_uid = 'uid-003' }
                }
                if ($Cmd -eq "mkvolumegroup") { return [pscustomobject]@{ id = '5' } }
            } -ModuleName IBMStorageVirtualize

            New-IBMSVClone -Name "pwsh_clone_vg0" -Type "thinclone" -Snapshot "pwsh_snap0"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroup" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "mkvolumegroup" -and
                    $CmdOpts.name     -eq "pwsh_clone_vg0" -and
                    $CmdOpts.type     -eq "thinclone" -and
                    $CmdOpts.snapshot -eq "pwsh_snap0" -and
                    $CmdOpts.fromsourceuid -eq 'uid-003' -and
                    -not $CmdOpts.ContainsKey('fromsourcegroup')
                }
        }

        It "Should create a volumegroup clone with all optional parameters" {
            $result = New-IBMSVClone -Name "pwsh_clone_vg0" -Type "thinclone" -Snapshot "pwsh_snap0" `
                -Pool "pool0" -IOGrp "io_grp0" -Partition "ptn1" -OwnershipGroup "grp1" -IgnoreUserFCMaps
            $result.name | Should -Be 'pwsh_clone_vg0'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroup" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "mkvolumegroup" -and
                    $CmdOpts.name              -eq "pwsh_clone_vg0" -and
                    $CmdOpts.type              -eq "thinclone" -and
                    $CmdOpts.snapshot          -eq "pwsh_snap0" -and
                    $CmdOpts.pool              -eq "pool0" -and
                    $CmdOpts.iogroup           -eq "io_grp0" -and
                    $CmdOpts.partition         -eq "ptn1" -and
                    $CmdOpts.ownershipgroup    -eq "grp1" -and
                    $CmdOpts.ignoreuserfcmaps  -eq $true -and
                    $CmdOpts.fromsourcegroup   -eq "pwsh_vg0"
                }
        }

        It "Should create a volumegroup clone with -DraftPartition parameter" {
            New-IBMSVClone -Name "pwsh_clone_vg0" -Type "clone" -Snapshot "pwsh_snap0" `
                -DraftPartition "draft_ptn1"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroup" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "mkvolumegroup" -and
                    $CmdOpts.draftpartition -eq "draft_ptn1"
                }
        }

        It "Should be idempotent when volumegroup clone already exists" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsvolumegroup") {
                    return [pscustomobject]@{ id = '5'; name = 'pwsh_clone_vg0'; volume_group_type = 'clone' }
                }
            } -ModuleName IBMStorageVirtualize

            $result = New-IBMSVClone -Name "pwsh_clone_vg0" -Type "clone" -Snapshot "pwsh_snap0"
            $result.name | Should -Be 'pwsh_clone_vg0'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroup" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -in ("lsvolumegroupsnapshot", "mkvolumegroup") }
        }

        It "Should throw error when snapshot does not exist for volumegroup clone" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsvolumegroup")          { return $null }
                if ($Cmd -eq "lsvolumegroupsnapshot")  { return $null }
            } -ModuleName IBMStorageVirtualize

            { New-IBMSVClone -Name "pwsh_clone_vg0" -Type "clone" -Snapshot "no_snap" } | Should -Throw "Snapshot 'no_snap' does not exist."
        }

        It "Should throw error when mkvolumegroup REST call fails" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                $script:callCount++
                if ($Cmd -eq "lsvolumegroup")         { if ($script:callCount -eq 1) { return $null } }
                if ($Cmd -eq "lsvolumegroupsnapshot") {
                    return [pscustomobject]@{ name = 'pwsh_snap0'; volume_group_name = 'pwsh_vg0'; parent_uid = 'uid-002' }
                }
                if ($Cmd -eq "mkvolumegroup") {
                    return [pscustomobject]@{
                        url  = "https://1.1.1.1:7443/rest/v1/mkvolumegroup"
                        code = 500; err = "HTTPError failed"; out = @{}; data = @{}
                    }
                }
            } -ModuleName IBMStorageVirtualize

            { New-IBMSVClone -Name "pwsh_clone_vg0" -Type "clone" -Snapshot "pwsh_snap0" } | Should -Throw
        }
    }

    Context "VolumeGroup Clone (subset via FromSourceVolumes)" {

        It "Should create a volumegroup clone from multiple source volumes (array syntax)" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                $script:callCount++
                if ($Cmd -eq "lsvolumegroup") {
                    if ($script:callCount -eq 1) { return $null }
                    return [pscustomobject]@{ id = '5'; name = 'pwsh_clone_vg0'; volume_group_type = 'clone' }
                }
                if ($Cmd -eq "lsvolumegroupsnapshot") {
                    return [pscustomobject]@{ name = 'pwsh_snap0'; volume_group_name = 'pwsh_vg0'; parent_uid = 'uid-002' }
                }
                if ($Cmd -eq "mkvolumegroup") { return [pscustomobject]@{ id = '5' } }
            } -ModuleName IBMStorageVirtualize

            $result = New-IBMSVClone -Name "pwsh_clone_vg0" -Type "clone" -Snapshot "pwsh_snap0" -FromSourceVolumes "pwsh_vol0","pwsh_vol1","pwsh_vol2" -Pool "pool0"
            $result.name | Should -Be 'pwsh_clone_vg0'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroup" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "mkvolumegroup" -and
                    $CmdOpts.name              -eq "pwsh_clone_vg0" -and
                    $CmdOpts.type              -eq "clone" -and
                    $CmdOpts.snapshot          -eq "pwsh_snap0" -and
                    $CmdOpts.fromsourcevolumes -eq "pwsh_vol0:pwsh_vol1:pwsh_vol2" -and
                    $CmdOpts.pool              -eq "pool0"
                }
        }

        It "Should create a volumegroup clone from colon-separated source volumes string" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                $script:callCount++
                if ($Cmd -eq "lsvolumegroup") {
                    if ($script:callCount -eq 1) { return $null }
                    return [pscustomobject]@{ id = '5'; name = 'pwsh_clone_vg0'; volume_group_type = 'clone' }
                }
                if ($Cmd -eq "lsvolumegroupsnapshot") {
                    return [pscustomobject]@{ name = 'pwsh_snap0'; volume_group_name = 'pwsh_vg0'; parent_uid = 'uid-002' }
                }
                if ($Cmd -eq "mkvolumegroup") { return [pscustomobject]@{ id = '5' } }
            } -ModuleName IBMStorageVirtualize

            New-IBMSVClone -Name "pwsh_clone_vg0" -Type "clone" -Snapshot "pwsh_snap0" -FromSourceVolumes "pwsh_vol0:pwsh_vol1:pwsh_vol2"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroup" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "mkvolumegroup" -and
                    $CmdOpts.name              -eq "pwsh_clone_vg0" -and
                    $CmdOpts.type              -eq "clone" -and
                    $CmdOpts.snapshot          -eq "pwsh_snap0" -and
                    $CmdOpts.fromsourcevolumes -eq "pwsh_vol0:pwsh_vol1:pwsh_vol2"
                }
        }
        
        It "Should use fromsourceuid when snapshot has no volume_group_name(using multivolume snashot for clone)" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                $script:callCount++
                if ($Cmd -eq "lsvolumegroup") {
                    if ($script:callCount -eq 1) { return $null }
                    return [pscustomobject]@{ id = '5'; name = 'pwsh_clone_vg0'; volume_group_type = 'clone' }
                }
                if ($Cmd -eq "lsvolumegroupsnapshot") {
                    return [pscustomobject]@{ name = 'pwsh_snap0'; volume_group_name = ''; parent_uid = 'uid-003' }
                }
                if ($Cmd -eq "mkvolumegroup") { return [pscustomobject]@{ id = '5' } }
            } -ModuleName IBMStorageVirtualize

            New-IBMSVClone -Name "pwsh_clone_vg0" -Type "clone" -Snapshot "pwsh_snap0" -FromSourceVolumes "pwsh_vol0:pwsh_vol1"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroup" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsvolumegroupsnapshot" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "mkvolumegroup" -and
                    $CmdOpts.name     -eq "pwsh_clone_vg0" -and
                    $CmdOpts.type     -eq "thinclone" -and
                    $CmdOpts.snapshot -eq "pwsh_snap0" -and
                    $CmdOpts.fromsourcevolumes -eq "pwsh_vol0:pwsh_vol1:pwsh_vol2"
                    $CmdOpts.fromsourceuid -eq 'uid-003'
                }
        }
    }
}
