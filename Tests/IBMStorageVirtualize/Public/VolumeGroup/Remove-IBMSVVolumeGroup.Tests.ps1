Describe "Remove-IBMSVVolumeGroup Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return [pscustomobject]@{ name='pwsh_vg0'; id='0' }
            }
            elseif ($Cmd -eq 'rmvolumegroup') {
                return @{}
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should not call API to remove volume group when -WhatIf is specified" {
        Remove-IBMSVVolumeGroup -Name "pwsh_vg0" -Confirm:$false -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should not throw error when volume group does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVVolumeGroup -Name "pwsh_vg0" -Confirm:$false } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'rmvolumegroup' }
    }

    It "Should remove the volume group" {
        Remove-IBMSVVolumeGroup -Name "pwsh_vg0" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "rmvolumegroup" -and
                $CmdArgs -eq "pwsh_vg0"
            }
    }

    It "Should remove volume group with EvictVolumes parameter" {
        Remove-IBMSVVolumeGroup -Name "pwsh_vg0" -EvictVolumes -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvolumegroup" -and $CmdArgs -contains "pwsh_vg0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "rmvolumegroup" -and
                $CmdOpts.evictvolumes -eq $true -and
                $CmdArgs -eq "pwsh_vg0"
            }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lsvolumegroup') {
                return [pscustomobject]@{ name='pwsh_vg0'; id='0' }
            }
            elseif ($Cmd -eq 'rmvolumegroup') {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/rmvolumegroup/pwsh_vg"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }

            return $null
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVVolumeGroup -Name "pwsh_vg0" -Confirm:$false } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/rmvolumegroup/pwsh_vg"
    }
}
