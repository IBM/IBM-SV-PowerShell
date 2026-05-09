Describe "New-IBMSVVolToHostMap" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsvdiskhostmap") {
                if ($script:callCount -eq 1) { return $null }
                if ($CmdArgs -eq "pwsh_vol" -or $CmdArgs -eq "60050768108101C7C0000000000001A1") {
                    return @(
                        [pscustomobject]@{
                            id        = "0"
                            name      = "pwsh_vol"
                            host_name = "pwsh_host"
                            host_cluster_name = "pwsh_hc"
                        }
                    )
                }
            }
            if ($Cmd -eq 'mkvdiskhostmap' -or $Cmd -eq 'mkvolumehostclustermap') {
                return [pscustomobject]@{ id='0'; message='Mapping created successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when HostName and HostClusterName are both specified" {
        { New-IBMSVVolToHostMap -Volume 'pwsh_vol0' -HostName 'pwsh_host0' -HostCluster 'pwsh_hc0' } | Should -Throw "Parameters -HostName and -HostCluster are mutually exclusive."
    }

    It "Should throw error when creating vdiskhostmap without Host or HostCluster" {
        { New-IBMSVVolToHostMap -Volume 'pwsh_vol0' } | Should -Throw "One of -HostName or -HostCluster parameter is required."
    }

    It "Should throw error when SCSI and AllowMismatchedScsiIds are both specified" {
        { New-IBMSVVolToHostMap -Volume 'pwsh_vol0' -HostName 'pwsh_host0' -SCSI 1 -AllowMismatchedScsiIds } | Should -Throw "Parameters -SCSI and -AllowMismatchedScsiIds are mutually exclusive."
    }

    It "Should not call API to create vdiskhostmap when -WhatIf is specified" {
        New-IBMSVVolToHostMap -Volume "pwsh_vol" -HostName "pwsh_host" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should create vdiskhostmap between volume and host" {
        $result = New-IBMSVVolToHostMap -Volume "pwsh_vol" -HostName "pwsh_host" -Scsi 1
        $result.host_name | Should -Be "pwsh_host"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdiskhostmap" -and $CmdArgs -eq "pwsh_vol" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvdiskhostmap" -and
                $CmdOpts.host -eq "pwsh_host" -and
                $CmdOpts.scsi -eq 1 -and
                $CmdArgs -eq "pwsh_vol"
            }
    }

    It "Should create vdiskhostmap between volume(using uid) and host" {
        $result = New-IBMSVVolToHostMap -Volume "60050768108101C7C0000000000001A1" -HostName "pwsh_host" -Scsi 1
        $result.host_name | Should -Be "pwsh_host"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdiskhostmap" -and $CmdArgs -eq "60050768108101C7C0000000000001A1" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvdiskhostmap" -and
                $CmdOpts.host -eq "pwsh_host" -and
                $CmdOpts.scsi -eq 1 -and
                $CmdArgs -eq "60050768108101C7C0000000000001A1"
            }
    }

    It "Should be idempotent and return existing vdiskhostmap between volume and host without error" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsvdiskhostmap") {
                return @(
                    [pscustomobject]@{
                        id        = "0"
                        name      = "pwsh_vol"
                        host_name = "pwsh_host"
                    }
                )
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVVolToHostMap -Volume 'pwsh_vol' -HostName 'pwsh_host'
        $result.host_name | Should -Be "pwsh_host"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdiskhostmap" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkvdiskhostmap" }
    }

    It "Should create volumehostclustermap between volume and hostcluster" {
        $result = New-IBMSVVolToHostMap -Volume "pwsh_vol" -HostCluster "pwsh_hc"
        $result.host_cluster_name | Should -Be "pwsh_hc"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdiskhostmap" -and $CmdArgs -eq "pwsh_vol" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumehostclustermap" -and
                $CmdOpts.hostcluster -eq "pwsh_hc" -and
                $CmdArgs -eq "pwsh_vol"
            }
    }

    It "Should create volumehostclustermap between volume(using uid) and hostcluster" {
        $result = New-IBMSVVolToHostMap -Volume "60050768108101C7C0000000000001A1" -HostCluster "pwsh_hc"
        $result.host_cluster_name | Should -Be "pwsh_hc"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdiskhostmap" -and $CmdArgs -eq "60050768108101C7C0000000000001A1" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkvolumehostclustermap" -and
                $CmdOpts.hostcluster -eq "pwsh_hc" -and
                $CmdArgs -eq "60050768108101C7C0000000000001A1"
            }
    }

    It "Should be idempotent and return existing volumehostclustermap between volume and hostcluster without error" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsvdiskhostmap") {
                return @(
                    [pscustomobject]@{
                        id                = "0"
                        name              = "pwsh_vol"
                        host_cluster_name = "pwsh_hc"
                    }
                )
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVVolToHostMap -Volume 'pwsh_vol' -HostCluster 'pwsh_hc'
        $result.host_cluster_name | Should -Be "pwsh_hc"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsvdiskhostmap" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkvolumehostclustermap" }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsvdiskhostmap") { return $null }
            if ($Cmd -eq "mkvdiskhostmap") {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/mkvdiskhostmap/pwsh_vol"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { New-IBMSVVolToHostMap -Volume "pwsh_vol" -HostName "pwsh_host" } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/mkvdiskhostmap/pwsh_vol"
    }
}
