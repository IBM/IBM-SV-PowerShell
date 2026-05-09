Describe "Remove-IBMSVVolToHostMap" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsvdiskhostmap") {
                if ($CmdArgs -eq "pwsh_vol" -or $CmdArgs -eq "60050768108101C7C0000000000001A1") {
                    return @(
                        [pscustomobject]@{id=62; name='pwsh_vol'; vdisk_UID='60050768108101C7C0000000000001A1'; host_id=1; host_name='pwsh_host0'; host_cluster_id=1; host_cluster_name='pwsh_hc0'},
                        [pscustomobject]@{id=62; name='pwsh_vol'; vdisk_UID='60050768108101C7C0000000000001A1'; host_id=2; host_name='pwsh_host1'; host_cluster_id=2; host_cluster_name='pwsh_hc1'}
                    )
                }
                return $null
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when HostName and HostClusterName are both specified" {
        { Remove-IBMSVVolToHostMap -Volume 'pwsh_vol0' -HostName 'pwsh_host0' -HostCluster 'pwsh_hc0' } | Should -Throw "Parameters -HostName and -HostCluster are mutually exclusive."
    }

    It "Should throw error when creating vdiskhostmap without Host or HostCluster" {
        { Remove-IBMSVVolToHostMap -Volume 'pwsh_vol0' } | Should -Throw "One of -HostName or -HostCluster parameter is required."
    }

    It "Should not call API to create vdiskhostmap when -WhatIf is specified" {
        Remove-IBMSVVolToHostMap -Volume "pwsh_vol" -HostName "pwsh_host" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should not throw error when vdiskhostmap does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsvdiskhostmap") { return $null }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVVolToHostMap -Volume 'pwsh_vol' -HostName 'pwsh_host' -Confirm:$false } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdiskhostmap" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmvdiskhostmap" }
    }

    It "Should not throw error when volumehostclustermap does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsvdiskhostmap") { return $null }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVVolToHostMap -Volume 'pwsh_vol' -HostCluster 'pwsh_hc' -Confirm:$false } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdiskhostmap" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkvolumehostclustermap" }
    }


    It "Should remove vdiskhostmap" {
        Remove-IBMSVVolToHostMap -Volume 'pwsh_vol' -HostName 'pwsh_host0' -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdiskhostmap" -and $CmdArgs -eq "pwsh_vol" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "rmvdiskhostmap" -and
                $CmdOpts.host -eq "pwsh_host0" -and
                $CmdArgs -eq "pwsh_vol"
            }
    }

    It "Should remove vdiskhostmap using uid" {
        Remove-IBMSVVolToHostMap -Volume '60050768108101C7C0000000000001A1' -HostName 'pwsh_host0' -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdiskhostmap" -and $CmdArgs -eq "60050768108101C7C0000000000001A1" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "rmvdiskhostmap" -and
                $CmdOpts.host -eq "pwsh_host0" -and
                $CmdArgs -eq "60050768108101C7C0000000000001A1"
            }
    }

    It "Should remove volumehostclustermap" {
        Remove-IBMSVVolToHostMap -Volume 'pwsh_vol' -HostCluster 'pwsh_hc0' -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdiskhostmap" -and $CmdArgs -eq "pwsh_vol" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "rmvolumehostclustermap" -and
                $CmdOpts.hostcluster -eq "pwsh_hc0" -and
                $CmdArgs -eq "pwsh_vol"
            }
    }

    It "Should remove volumehostclustermap using uid" {
        Remove-IBMSVVolToHostMap -Volume '60050768108101C7C0000000000001A1' -HostCluster 'pwsh_hc0' -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdiskhostmap" -and $CmdArgs -eq "60050768108101C7C0000000000001A1" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "rmvolumehostclustermap" -and
                $CmdOpts.hostcluster -eq "pwsh_hc0" -and
                $CmdArgs -eq "60050768108101C7C0000000000001A1"
            }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsvdiskhostmap") {
                return @(
                    [pscustomobject]@{id=62; name='pwsh_vol'; host_id=1; host_name='pwsh_host0'},
                    [pscustomobject]@{id=62; name='pwsh_vol'; host_id=2; host_name='pwsh_host1'}
                )
            }
            if ($Cmd -eq "rmvdiskhostmap") {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/rmvdiskhostmap/pwsh_vol"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVVolToHostMap -Volume 'pwsh_vol' -HostName 'pwsh_host0' -Confirm:$false } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/rmvdiskhostmap/pwsh_vol"
    }
}
