Describe "New-IBMSVVolume" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsvdisk") {
                if ($script:callCount -eq 1) {
                    return $null
                }
                return [pscustomobject]@{
                    name = 'pwsh_vol0'
                    capacity = '1.00GB'
                    id = '0'
                }
            }

            if ($Cmd -eq "mkvolume") {
                return [pscustomobject]@{ id = '0'; message = 'Volume created successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when Thin and Compressed are both specified" {
        { New-IBMSVVolume -Name "pwsh_vol0" -Size 1 -Unit "gb" -Pool "pwsh_pool0" -Thin -Compressed } | Should -Throw "Parameters -Thin and -Compressed are mutually exclusive."
    }

    It "Should throw error when Grainsize is provided without Thin" {
        { New-IBMSVVolume -Name "pwsh_vol0" -Size 1 -Unit "gb" -Pool "pwsh_pool0" -Grainsize 64 } | Should -Throw "Parameter -Grainsize is invalid without -Thin."
    }

    It "Should throw error when PreferredNode is provided without single IOGrp" {
        { New-IBMSVVolume -Name "pwsh_vol0" -Size 1 -Unit "gb" -Pool "pwsh_pool0" -IOGrp "io_grp1:io_grp2" -PreferredNode "node1" } | Should -Throw "Parameter -PreferredNode is only valid with a single iogrp."
    }

    It "Should throw error when optional parameters used without Thin/Compressed" {
        { New-IBMSVVolume -Name "pwsh_vol0" -Size 1 -Unit "gb" -Pool "pwsh_pool0" -BufferSize "10%" -Warning 50 -Deduplicated -NoAutoExpand } | Should -Throw "The parameter(s) -BufferSize, -Warning, -Deduplicated, -NoAutoExpand can only be used when one of -Thin or -Compressed is specified."
    }

    It "Should throw error when duplicate values are provided" {
        { New-IBMSVVolume -Name "pwsh_vol0" -Size 1 -Unit "gb" -Pool "pwsh_pool0" -IOGrp "0:1:1" } | Should -Throw "Duplicate IOGrp values found: 1"
    }

    It "Should not call API to create volume when -WhatIf is specified" {
        New-IBMSVVolume -Name "pwsh_vol0" -Size 1 -Unit "gb" -Pool "pwsh_pool0" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should create a volume with required parameters" {
        $result = New-IBMSVVolume -Name "pwsh_vol0" -Size 1 -Unit "gb" -Pool "pwsh_pool0"
        $result.name | Should -Be 'pwsh_vol0'
        $result.capacity | Should -Be '1.00GB'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdisk" -and $CmdArgs -contains "pwsh_vol0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolume" -and
                $CmdOpts.name -eq "pwsh_vol0" -and
                $CmdOpts.size -eq 1 -and
                $CmdOpts.unit -eq "gb" -and
                $CmdOpts.pool -eq "pwsh_pool0"
            }
    }

    It "Should be idempotent when volume already exists" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return [pscustomobject]@{
                    name = 'pwsh_vol0'
                    capacity = '1.00GB'
                    id = '0'
                }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVVolume -Name "pwsh_vol0" -Size 1024 -Pool "pwsh_pool0"
        $result.name | Should -Be 'pwsh_vol0'
        $result.capacity | Should -Be '1.00GB'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdisk" -and $CmdArgs -contains "pwsh_vol0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkvolume" }
    }

    It "Should create a volume with all parameters" {
        $result = New-IBMSVVolume -Name "pwsh_vol0" -Size 1 -Unit "gb" -Pool "pwsh_pool0" -Cache "none" -Udid "1234" -PreferredNode "node1" -IOGrp "io_grp0" -VolumeGroup "pwsh_vg0"
        $result.name | Should -Be 'pwsh_vol0'
        $result.capacity | Should -Be '1.00GB'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdisk" -and $CmdArgs -contains "pwsh_vol0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolume" -and
                $CmdOpts.name -eq "pwsh_vol0" -and
                $CmdOpts.size -eq 1 -and
                $CmdOpts.unit -eq "gb" -and
                $CmdOpts.pool -eq "pwsh_pool0" -and
                $CmdOpts.cache -eq "none" -and
                $CmdOpts.udid -eq "1234" -and
                $CmdOpts.preferrednode -eq "node1" -and
                $CmdOpts.iogrp -eq "io_grp0" -and
                $CmdOpts.volumegroup -eq "pwsh_vg0"
            }
    }

    It "Should create a thin volume" {
        $result = New-IBMSVVolume -Name "pwsh_vol0" -Size 1 -Unit "gb" -Pool "pwsh_pool0" -Cache "none" -Thin -BufferSize "3%" -Warning "70%" -NoAutoExpand -Grainsize 64 -Udid "1234" -PreferredNode "node1" -IOGrp "io_grp0" -VolumeGroup "pwsh_vg0"
        $result.name | Should -Be 'pwsh_vol0'
        $result.capacity | Should -Be '1.00GB'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdisk" -and $CmdArgs -contains "pwsh_vol0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolume" -and
                $CmdOpts.name -eq "pwsh_vol0" -and
                $CmdOpts.size -eq 1 -and
                $CmdOpts.unit -eq "gb" -and
                $CmdOpts.pool -eq "pwsh_pool0" -and
                $CmdOpts.cache -eq "none" -and
                $CmdOpts.thin -eq $true -and
                $CmdOpts.buffersize -eq "3%" -and
                $CmdOpts.warning -eq "70%" -and
                $CmdOpts.noautoexpand -eq $true -and
                $CmdOpts.grainsize -eq 64 -and
                $CmdOpts.udid -eq "1234" -and
                $CmdOpts.preferrednode -eq "node1" -and
                $CmdOpts.iogrp -eq "io_grp0" -and
                $CmdOpts.volumegroup -eq "pwsh_vg0"
            }
    }

    It "Should create a thin-deduplicated volume with multiple parameters" {
        $result = New-IBMSVVolume -Name "pwsh_vol0" -Size 1 -Unit "gb" -Pool "pwsh_pool0" -Cache "readwrite" -Thin -Deduplicated -Udid "1234" -PreferredNode "node1" -IOGrp "io_grp0" -VolumeGroup "pwsh_vg0"
        $result.name | Should -Be 'pwsh_vol0'
        $result.capacity | Should -Be '1.00GB'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdisk" -and $CmdArgs -contains "pwsh_vol0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolume" -and
                $CmdOpts.name -eq "pwsh_vol0" -and
                $CmdOpts.size -eq 1 -and
                $CmdOpts.unit -eq "gb" -and
                $CmdOpts.pool -eq "pwsh_pool0" -and
                $CmdOpts.cache -eq "readwrite" -and
                $CmdOpts.thin -eq $true -and
                $CmdOpts.deduplicated -eq $true -and
                $CmdOpts.udid -eq "1234" -and
                $CmdOpts.preferrednode -eq "node1" -and
                $CmdOpts.iogrp -eq "io_grp0" -and
                $CmdOpts.volumegroup -eq "pwsh_vg0"
            }
    }

    It "Should create a compressed volume with multiple parameters" {
        $result = New-IBMSVVolume -Name "pwsh_vol0" -Size 1 -Unit "gb" -Pool "pwsh_pool0"  -Compressed -Cache "readwrite" -Udid "1234" -PreferredNode "node1" -IOGrp "io_grp0" -VolumeGroup "pwsh_vg0"
        $result.name | Should -Be 'pwsh_vol0'
        $result.capacity | Should -Be '1.00GB'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdisk" -and $CmdArgs -contains "pwsh_vol0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolume" -and
                $CmdOpts.name -eq "pwsh_vol0" -and
                $CmdOpts.size -eq 1 -and
                $CmdOpts.unit -eq "gb" -and
                $CmdOpts.pool -eq "pwsh_pool0" -and
                $CmdOpts.cache -eq "readwrite" -and
                $CmdOpts.compressed -eq $true -and
                $CmdOpts.udid -eq "1234" -and
                $CmdOpts.preferrednode -eq "node1" -and
                $CmdOpts.iogrp -eq "io_grp0" -and
                $CmdOpts.volumegroup -eq "pwsh_vg0"
            }
    }

    It "Should create a compressed-dedulicated volume with multiple parameters" {
        $result = New-IBMSVVolume -Name "pwsh_vol0" -Size 1 -Unit "gb" -Pool "pwsh_pool0"  -Compressed -Deduplicated -Cache "readwrite" -Udid "1234" -PreferredNode "node1" -IOGrp "io_grp0" -VolumeGroup "pwsh_vg0"
        $result.name | Should -Be 'pwsh_vol0'
        $result.capacity | Should -Be '1.00GB'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdisk" -and $CmdArgs -contains "pwsh_vol0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolume" -and
                $CmdOpts.name -eq "pwsh_vol0" -and
                $CmdOpts.size -eq 1 -and
                $CmdOpts.unit -eq "gb" -and
                $CmdOpts.pool -eq "pwsh_pool0" -and
                $CmdOpts.cache -eq "readwrite" -and
                $CmdOpts.compressed -eq $true -and
                $CmdOpts.deduplicated -eq $true -and
                $CmdOpts.udid -eq "1234" -and
                $CmdOpts.preferrednode -eq "node1" -and
                $CmdOpts.iogrp -eq "io_grp0" -and
                $CmdOpts.volumegroup -eq "pwsh_vg0"
            }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdisk") {
                return $null
            }

            if ($Cmd -eq "mkvolume") {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/mkvolume"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { New-IBMSVVolume -Name "pwsh_vol0" -Size 1 -Unit "gb" -Pool "pwsh_pool0" } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/mkvolume"
    }
}
