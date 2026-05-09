Describe "Remove-IBMSVVolume" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsvdisk") {
                return [pscustomobject]@{
                    name = 'pwsh_vol'
                    vdisk_UID = '60050768108101C7C0000000000001A1'
                    capacity = '1.00GB'
                }
            }
            if ($Cmd -eq 'rmvolume') {
                return [pscustomobject]@{ message = 'Volume removed successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should not call API to remove volume when -WhatIf is specified" {
        Remove-IBMSVVolume -Name "pwsh_vol" -Confirm:$false -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should not throw error when volume does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsvdisk") {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVVolume -Name "pwsh_vol" -Confirm:$false } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdisk" -and $CmdArgs -contains "pwsh_vol" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmvolume" }
    }

    It "Should remove the volume" {
        Remove-IBMSVVolume -Name "pwsh_vol" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdisk" -and $CmdArgs -contains "pwsh_vol" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmvolume" -and $CmdArgs -contains "pwsh_vol" }
    }

    It "Should remove the volume using uid" {
        Remove-IBMSVVolume -Name "60050768108101C7C0000000000001A1" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdisk" -and $CmdArgs -contains "60050768108101C7C0000000000001A1" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmvolume" -and $CmdArgs -contains "60050768108101C7C0000000000001A1" }
    }

    It "Should remove a volume which has host mappings, rc relationship or fc mapping" {
        Remove-IBMSVVolume -Name "pwsh_vol" -RemoveHostMappings -RemoveFCMappings -RemoveRCRelationships -DiscardImage -CancelBackUp -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdisk" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "rmvolume" -and
                $CmdOpts.removehostmappings -eq $true -and
                $CmdOpts.removefcmaps -eq $true -and
                $CmdOpts.removercrelationships -eq $true -and
                $CmdOpts.discardimage -eq $true -and
                $CmdOpts.cancelbackup -eq $true -and
                $CmdArgs -contains "pwsh_vol"
            }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsvdisk") {
                return [pscustomobject]@{ name = 'pwsh_vol'; capacity = '1.00GB' }
            }
            if ($Cmd -eq "rmvolume") {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/rmvolume/pwsh_vol"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVVolume -Name "pwsh_vol" -Confirm:$false } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/rmvolume/pwsh_vol"
    }
}
