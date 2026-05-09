Describe "Set-IBMSVMDisk Tests" {
    BeforeEach {
        $script:count = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq "lsmdisk") {
                return @{
                    id = '0'
                    name = 'pwsh_mdisk0'
                    mdisk_grp_name='pwsh_pool0'
                    tier = 'tier0_flash'
                    easy_tier_load = 'default'
                }
            }
            return @{}
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when MDisk does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdisk") { return $null }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVMDisk -Name 'pwsh_mdisk0' } | Should -Throw "MDisk 'pwsh_mdisk0' does not exist."
    }

    It "Should throw error when both MDisk and new name do not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdisk") { return $null }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVMDisk -Name 'pwsh_mdisk0' -NewName 'pwsh_mdisk1' } | Should -Throw "MDisk 'pwsh_mdisk0' does not exist."
    }

    It "Should not call API to update MDisk when -WhatIf is specified" {
        Set-IBMSVMDisk -Name 'pwsh_mdisk0' -Tier 'tier1_flash' -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chmdisk' }
    }

    It "Should rename the MDisk when NewName is different" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq "lsmdisk") {
                if ($script:count -eq 1) {
                    return @{
                        id = '0'
                        name = 'pwsh_mdisk0'
                        mdisk_grp_name='pwsh_pool0'
                        tier = 'tier0_flash'
                        easy_tier_load = 'default'
                    }
                    return $null
                }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVMDisk -Name 'pwsh_mdisk0' -NewName 'pwsh_mdisk1' -Tier 'tier1_flash'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsmdisk" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdisk' -and
                $CmdOpts.name -eq 'pwsh_mdisk1' -and
                $CmdOpts.tier -eq 'tier1_flash' -and
                $CmdArgs -eq 'pwsh_mdisk0'
            }
    }

    It "Should not throw error if -Name MDisk does not exist but -NewName MDisk exists and proceed to update other params on -NewName MDisk" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq "lsmdisk") {
                if ($script:count -eq 1) { return $null }
                return @{
                    id = '1'
                    name = 'pwsh_mdisk1'
                    tier = 'tier0_flash'
                    easy_tier_load = 'default'
                }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVMDisk -Name 'pwsh_mdisk0' -NewName 'pwsh_mdisk1' -Tier 'tier1_flash'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdisk' -and
                $CmdOpts.tier -eq 'tier1_flash' -and
                $CmdArgs -eq 'pwsh_mdisk1'
            }
    }

    It "Should throw error if both -Name MDisk and -NewName MDisk exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq "lsmdisk") {
                if ($script:count -eq 1) { return @{ name = 'pwsh_mdisk0'; id = '0' } }
                return @{ name = 'pwsh_mdisk1'; id = '1' }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVMDisk -Name 'pwsh_mdisk0' -NewName 'pwsh_mdisk1' -Tier 'tier1_flash' } | Should -Throw "Both 'pwsh_mdisk0' and 'pwsh_mdisk1' exist. Cannot rename, cannot proceed with other updates."
    }

    It "Should update MDisk Tier" {
        Set-IBMSVMDisk -Name 'pwsh_mdisk0' -Tier 'tier1_flash'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsmdisk" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdisk' -and
                $CmdOpts.tier -eq 'tier1_flash' -and
                $CmdArgs -eq 'pwsh_mdisk0'
            }
    }

    It "Should update MDisk EasyTierLoad" {
        Set-IBMSVMDisk -Name 'pwsh_mdisk0' -EasyTierLoad 'high'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsmdisk" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdisk' -and
                $CmdOpts.easytierload -eq 'high' -and
                $CmdArgs -eq 'pwsh_mdisk0'
            }
    }

    It "Should update MDisk with multiple parameters" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq "lsmdisk") {
                if ($script:count -eq 1) {
                    return @{
                        id = '0'
                        name = 'pwsh_mdisk0'
                        mdisk_grp_name='pwsh_pool0'
                        tier = 'tier0_flash'
                        easy_tier_load = 'default'
                    }
                }
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVMDisk -Name 'pwsh_mdisk0' -NewName 'pwsh_mdisk1' -Tier 'tier1_flash' -EasyTierLoad 'medium'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsmdisk" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdisk' -and
                $CmdOpts.tier -eq 'tier1_flash' -and
                $CmdOpts.easytierload -eq 'medium' -and
                $CmdArgs -eq 'pwsh_mdisk0'
            }
    }

    It "Should not make changes when same name is used for rename" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:count++
            if ($Cmd -eq "lsmdisk") {
                if ($script:count -eq 1) { return $null }
                return @{ name = 'pwsh_mdisk1'; tier = 'tier1_flash'; easy_tier_load = 'high' }
            }
            return @{}
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVMDisk -Name 'pwsh_mdisk0' -NewName 'pwsh_mdisk1' -Tier 'tier1_flash' -EasyTierLoad 'high'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsmdisk" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chmdisk" }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsmdisk") {
                return @{ name = 'pwsh_mdisk0'; tier = 'tier0_flash'; easy_tier_load = 'default' }
            }
            if ($Cmd -eq "chmdisk") {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/chmdisk/pwsh_mdisk"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVMDisk -Name "pwsh_mdisk0" -Tier 'tier1_flash' } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/chmdisk/pwsh_mdisk"
    }
}
