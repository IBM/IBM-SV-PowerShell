Describe "Get-IBMSVInfo" {
    Context "Cmdlet existence" {
        It "Should export Get-IBMSVPool" {
            Get-Command Get-IBMSVPool -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
        It "Should export Get-IBMSVVolume" {
            Get-Command Get-IBMSVVolume -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
        It "Should export Get-IBMSVHost" {
            Get-Command Get-IBMSVHost -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    Context "Get-IBMSVVolume wrapper - Unit Tests" {
        BeforeEach {
            Mock Invoke-IBMSVRestRequest {
                return @{ id = 1; name = "vol1"; volume_group_name = "vg0" }
            } -ModuleName IBMStorageVirtualize
        }

        It "Should call Invoke-IBMSVRestRequest once when called without parameters(returning empty object)" {
            Mock Invoke-IBMSVRestRequest { return @{} } -ModuleName IBMStorageVirtualize
            { Get-IBMSVVolume } | Should -Not -Throw
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should call Invoke-IBMSVRestRequest once when called without parameters" {
            $result = Get-IBMSVVolume
            $result.id | Should -Be 1
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should forward ObjectName to Invoke-IBMSVRestRequest" {
            $result = Get-IBMSVVolume -ObjectName "vol1"
            $result.name | Should -Be "vol1"
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk" -and $CmdArgs -contains "vol1"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should forward ObjectName to Invoke-IBMSVRestRequest(returning empty object)" {
            Mock Invoke-IBMSVRestRequest { return @{} } -ModuleName IBMStorageVirtualize
            { Get-IBMSVVolume -ObjectName "vol1" } | Should -Not -Throw
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk" -and $CmdArgs -contains "vol1"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should forward Detailed switch to Invoke-IBMSVRestRequest" {
            Mock Invoke-IBMSVRestRequest {
                return @(@{ id = 1; name = "vol1" })
            } -ModuleName IBMStorageVirtualize

            $result = Get-IBMSVVolume -Detailed
            $result.name | Should -Be "vol1"
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize
        }

        It "Should forward FilterValue to Invoke-IBMSVRestRequest" {
            $result = Get-IBMSVVolume -FilterValue "name=vol1"
            $result.name | Should -Be "vol1"
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk" -and $CmdOpts.filtervalue -eq "name=vol1"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should forward FilterValue to Invoke-IBMSVRestRequest(with multiple values)" {
            $vol = Get-IBMSVVolume -FilterValue "name=vol1:volume_group_name=vg0"
            $vol.name | Should -Be "vol1"
            $vol.volume_group_name | Should -Be "vg0"
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk" -and $CmdOpts.filtervalue -eq "name=vol1:volume_group_name=vg0"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should forward FilterValue to Invoke-IBMSVRestRequest(with invalid key:value)" {
            { Get-IBMSVVolume -FilterValue "na=na" } | Should -Not -Throw
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should allow Detailed and FilterValue to be used together" {
            Mock Invoke-IBMSVRestRequest {
                return @(@{ id = 1; name = "vol1" })
            } -ModuleName IBMStorageVirtualize

            $result = Get-IBMSVVolume -Detailed -FilterValue "name=vol1"
            $result.name | Should -Be "vol1"
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize
        }

        It "Should throw when ObjectName and Detailed are used together" {
            { Get-IBMSVVolume -ObjectName "vol1" -Detailed } | Should -Throw "Parameter -ObjectName cannot be used together with -Detailed or -FilterValue."
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }

        It "Should throw when ObjectName and FilterValue are used together" {
            { Get-IBMSVVolume -ObjectName "vol1" -FilterValue "name=vol1" } | Should -Throw "Parameter -ObjectName cannot be used together with -Detailed or -FilterValue."
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }
    }

    Context "Get-IBMSVInfo invocation" {
        BeforeEach {
            Mock Invoke-IBMSVRestRequest {
                return @{ id = 1; name = "vol1"; volume_group_name = "vg0" }
            } -ModuleName IBMStorageVirtualize
        }

        It "Should call Invoke-IBMSVRestRequest once when called without parameters(returning empty object)" {
            Mock Invoke-IBMSVRestRequest { return @{} } -ModuleName IBMStorageVirtualize
            { Get-IBMSVInfo -Subset "Volume" } | Should -Not -Throw
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should call Invoke-IBMSVRestRequest once when called without parameters" {
            $result = Get-IBMSVInfo -Subset "Volume"
            $result.id | Should -Be 1
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should forward ObjectName to Invoke-IBMSVRestRequest" {
            $result = Get-IBMSVInfo -Subset "Volume" -ObjectName "vol1"
            $result.name | Should -Be "vol1"
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk" -and $CmdArgs -contains "vol1"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should forward ObjectName to Invoke-IBMSVRestRequest(returning empty object)" {
            Mock Invoke-IBMSVRestRequest { return @{} } -ModuleName IBMStorageVirtualize
            { Get-IBMSVInfo -Subset "Volume" -ObjectName "vol1" } | Should -Not -Throw
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk" -and $CmdArgs -contains "vol1"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should forward Detailed switch to Invoke-IBMSVRestRequest" {
            Mock Invoke-IBMSVRestRequest {
                return @(@{ id = 1; name = "vol1" })
            } -ModuleName IBMStorageVirtualize

            $result = Get-IBMSVInfo -Subset "Volume" -Detailed
            $result.name | Should -Be "vol1"
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize
        }

        It "Should forward FilterValue to Invoke-IBMSVRestRequest" {
            $result = Get-IBMSVInfo -Subset "Volume" -FilterValue "name=vol1"
            $result.name | Should -Be "vol1"
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk" -and $CmdOpts.filtervalue -eq "name=vol1"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should forward FilterValue to Invoke-IBMSVRestRequest(with multiple values)" {
            $vol = Get-IBMSVInfo -Subset "Volume" -FilterValue "name=vol1:volume_group_name=vg0"
            $vol.name | Should -Be "vol1"
            $vol.volume_group_name | Should -Be "vg0"
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk" -and $CmdOpts.filtervalue -eq "name=vol1:volume_group_name=vg0"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should forward FilterValue to Invoke-IBMSVRestRequest(with invalid key:value)" {
            { Get-IBMSVInfo -Subset "Volume" -FilterValue "na=na" } | Should -Not -Throw
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ParameterFilter {
                $Cmd -eq "lsvdisk"
            } -ModuleName IBMStorageVirtualize
        }

        It "Should allow Detailed and FilterValue to be used together" {
            Mock Invoke-IBMSVRestRequest {
                return @(@{ id = 1; name = "vol1" })
            } -ModuleName IBMStorageVirtualize

            $result = Get-IBMSVInfo -Subset "Volume" -Detailed -FilterValue "name=vol1"
            $result.name | Should -Be "vol1"
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize
        }

        It "Should throw when ObjectName and Detailed are used together" {
            { Get-IBMSVInfo -Subset "Volume" -ObjectName "vol1" -Detailed } | Should -Throw "Parameter -Detailed is invalid when -ObjectName is specified."
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }

        It "Should throw when ObjectName and FilterValue are used together" {
            { Get-IBMSVInfo -Subset "Volume" -ObjectName "vol1" -FilterValue "name=vol1" } | Should -Throw "Parameter -FilterValue cannot be used with -ObjectName."
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }
    }

    Context "Get-IBMSVInfo invocation with multiple subset" {
        BeforeEach {
            Mock Invoke-IBMSVRestRequest {
                switch ($Cmd) {
                    "lsvdisk" { return @(@{ id = "vol1"; name = "obj1" }) }
                    "lshost"  { return @(@{ id = "host1"; name = "obj1" }) }
                }
            } -ModuleName IBMStorageVirtualize
        }

        It "Calls Invoke-IBMSVRestRequest with no parameters" {
            Mock Invoke-IBMSVRestRequest { return @{} } -ModuleName IBMStorageVirtualize
            { Get-IBMSVInfo -Subset Volume,Host } | Should -Not -Throw
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize
        }

        It "Calls Invoke-IBMSVRestRequest with no parameters" {
            $data = Get-IBMSVInfo -Subset @("Volume","Host")
            $data.Host.name | Should -Be "obj1"
            $data.Volume.name | Should -Be "obj1"
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize
        }

        It "Calls Invoke-IBMSVRestRequest with -ObjectName" {
            $data = Get-IBMSVInfo -Subset Volume,Host -ObjectName "obj1"
            $data.Host.name | Should -Be "obj1"
            $data.Volume.name | Should -Be "obj1"
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ParameterFilter {
                $CmdArgs -contains "obj1"
            } -ModuleName IBMStorageVirtualize
        }

        It "Calls Invoke-IBMSVRestRequest with -ObjectName with non-existent object" {
            Mock Invoke-IBMSVRestRequest { return @{} } -ModuleName IBMStorageVirtualize
            { Get-IBMSVInfo -Subset Volume,Host -ObjectName "obj2" } | Should -Not -Throw
        }

        It "Calls Invoke-IBMSVRestRequest with -Detailed" {
            Mock Invoke-IBMSVRestRequest {
                switch ($Cmd) {
                    "lsvdisk" { return @(@{ id = "vol1"; name = "obj1" }) }
                    "lshost"  { return @(@{ id = "host1"; name = "obj1" }) }
                }
            } -ModuleName IBMStorageVirtualize

            $data = Get-IBMSVInfo -Subset Volume,Host -Detailed
            $data.Host.name | Should -Be "obj1"
            $data.Volume.name | Should -Be "obj1"
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 4 -ModuleName IBMStorageVirtualize
        }

        It "Calls Invoke-IBMSVRestRequest with -Filtervalue with multiplevalues" {
            { Get-IBMSVInfo -Subset Volume,Host -FilterValue "name=obj1:volume_group_name=vg0" } | Should -Throw "Parameter -FilterValue requires exactly one object type in -Subset."
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }

        It "Throws when -ObjectName and -Detailed are used together" {
            { Get-IBMSVInfo -Subset "Volume" -ObjectName "vol1" -Detailed } | Should -Throw "Parameter -Detailed is invalid when -ObjectName is specified."
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }
    }

    Context "Get-IBMSVArrayRecommendation - Unit Tests" {
        BeforeEach {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsdrive") {
                    return @(
                        [pscustomobject]@{ id = "0"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "1"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "2"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "3"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "4"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "5"; use = "candidate"; drive_class_id = 0 }
                    )
                }
                if ($Cmd -eq "lsarrayrecommendation") {
                    return @(
                        [pscustomobject]@{
                            raid_level = "raid6"
                            strip_size = "256"
                            drive_count = 6
                            capacity = "10TB"
                        }
                    )
                }
            } -ModuleName IBMStorageVirtualize
        }

        It "Should use all available drives when DriveCount is not specified" {
            $result = Get-IBMSVArrayRecommendation -MDiskGrp "mdiskgrp0" -DriveClass 0
            $result | Should -Not -BeNullOrEmpty

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsarrayrecommendation" -and $CmdOpts.drivecount -eq 6 }
        }

        It "Should return empty array when no candidate drives are found" {
            Mock Invoke-IBMSVRestRequest { return @() } -ModuleName IBMStorageVirtualize

            $result = Get-IBMSVArrayRecommendation -MDiskGrp "mdiskgrp0" -DriveClass 1
            $result | Should -BeNullOrEmpty
            $result.Count | Should -Be 0
        }

        It "Should return empty array when DriveCount exceeds available drives" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsdrive") {
                    return @(
                        [pscustomobject]@{ id = "0"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "1"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "2"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "3"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "4"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "5"; use = "candidate"; drive_class_id = 0 }
                    )
                }
                if ($Cmd -eq "lsarrayrecommendation") { return @() }
            } -ModuleName IBMStorageVirtualize

            $result = Get-IBMSVArrayRecommendation -MDiskGrp "mdiskgrp0" -DriveClass 0 -DriveCount 20
            $result | Should -BeNullOrEmpty
            $result.Count | Should -Be 0

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lsarrayrecommendation" }
        }

        It "Should handle multiple recommendation objects" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lsdrive") {
                    return @(
                        [pscustomobject]@{ id = "0"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "1"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "2"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "3"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "4"; use = "candidate"; drive_class_id = 0 }
                        [pscustomobject]@{ id = "5"; use = "candidate"; drive_class_id = 0 }
                    )
                }
                if ($Cmd -eq "lsarrayrecommendation") {
                    return @(
                        [pscustomobject]@{ raid_level = "raid6"; drive_count = 6 }
                        [pscustomobject]@{ raid_level = "raid1"; drive_count = 6 }
                    )
                }
            } -ModuleName IBMStorageVirtualize

            $result = Get-IBMSVArrayRecommendation -MDiskGrp "mdiskgrp0" -DriveClass 0 -DriveCount 6
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result[0].raid_level | Should -Be "raid6"
            $result[1].raid_level | Should -Be "raid1"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "lsarrayrecommendation" -and
                    $CmdOpts.driveclass -eq 0 -and
                    $CmdOpts.drivecount -eq 6 -and
                    $CmdArgs -contains "mdiskgrp0"
                }
        }
    }
}
