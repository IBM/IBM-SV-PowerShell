Describe "Remove-IBMSVMDisk Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdisk") {
                return [pscustomobject]@{
                    id='1'
                    name='pwsh_mdisk0'
                    mdisk_grp_name='pwsh_pool0' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should not call API to remove MDisk when -WhatIf is specified" {
        Remove-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Confirm:$false -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should not throw error when MDisk does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdisk") { return $null }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Confirm:$false } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsmdisk" -and $CmdArgs -contains "pwsh_mdisk0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmmdisk" }
    }

    It "Should remove the MDisk" {
        Remove-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsmdisk" -and $CmdArgs -contains "pwsh_mdisk0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "rmmdisk" -and
                $CmdOpts.mdisk -eq "pwsh_mdisk0" -and
                $CmdArgs -eq "pwsh_pool0"
            }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdisk") {
                return [pscustomobject]@{ id='1'; name='pwsh_mdisk0'; mdisk_grp_name='pwsh_pool0' }
            }
            if ($Cmd -eq "rmmdisk") {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/rmmdisk/pwsh_pool"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVMDisk -Name "pwsh_mdisk0" -MDiskGrp "pwsh_pool0" -Confirm:$false } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/rmmdisk/pwsh_pool"
    }
}
