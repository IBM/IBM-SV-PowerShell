Describe "Remove-IBMSVPartnership Tests" {
    InModuleScope IBMStorageVirtualize {
        $script:primarysession = "1.1.1.1"
    }

    Context "Parameter Validation" {
        It "Should throw error when RemoteSystem is not specified without RemoteCluster" {
            { Remove-IBMSVPartnership -Confirm:$false } | Should -Throw "-RemoteSystem is required when -RemoteCluster is not specified."
        }
    }

    Context "WhatIf Support" {
        It "Should not call API to remove partnership when -WhatIf is specified" {
            Mock Invoke-IBMSVRestRequest {} -ModuleName IBMStorageVirtualize
            Remove-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -Confirm:$false -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }
    }

    Context "Local Cluster Only" {
        It "Should not throw error when partnership does not exist" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lspartnership') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            { Remove-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -Confirm:$false } | Should -Not -Throw

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'rmpartnership' }
        }

        It "Should remove the partnership from local cluster" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd, $Cluster)

                if ($Cmd -eq 'lspartnership') {
                    return [pscustomobject]@{
                        id = '0000020321E04D5A'
                        name = 'remote_system'
                        partnership = 'fully_configured'
                    }
                }
                elseif ($Cmd -eq 'lssystem') {
                    if ($Cluster -eq "10.10.10.20") {
                        return [pscustomobject]@{ id = '0000020321E04D5B' }
                    }
                    return [pscustomobject]@{ id = '0000020321E04D5A' }
                }
                elseif ($Cmd -eq 'rmpartnership') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize
            Remove-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.stop -eq $true -and
                    $CmdArgs -eq "0000020321E04D5A"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "rmpartnership" -and
                    $CmdArgs -eq "0000020321E04D5A"
                }
        }
    }

    Context "Both Clusters" {
        It "Should remove partnership with -RemoteCluster (on both clusters)" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd, $CmdArgs, $Cluster)

                if ($Cmd -eq 'lssystem') {
                    if ($Cluster -eq "1.1.1.1") {
                        return [pscustomobject]@{ id = '0000020321E04D5A' }
                    }
                    if ($Cluster -eq "1.1.1.2") {
                        return [pscustomobject]@{ id = '0000020321E04D5B' }
                    }
                }
                if ($Cmd -eq 'lspartnership') {
                    if ($CmdArgs -eq "0000020321E04D5B") {
                        return [pscustomobject]@{
                            id = '0000020321E04D5B'
                            partnership = 'fully_configured'
                        }
                    }
                    if ($CmdArgs -eq "0000020321E04D5A") {
                        return [pscustomobject]@{
                            id = '0000020321E04D5A'
                            partnership = 'fully_configured'
                        }
                    }
                }
                if ($Cmd -eq 'rmpartnership') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            Remove-IBMSVPartnership -RemoteCluster "1.1.1.2" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lssystem" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.1" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.stop -eq $true -and
                    $CmdArgs -eq "0000020321E04D5B"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.2" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.stop -eq $true -and
                    $CmdArgs -eq "0000020321E04D5A"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.1" -and
                    $Cmd -eq "rmpartnership" -and
                    $CmdArgs -eq "0000020321E04D5B"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.2" -and
                    $Cmd -eq "rmpartnership" -and
                    $CmdArgs -eq "0000020321E04D5A"
                }
        }

        It "Should remove partnership with -RemoteCluster (on local cluster only)" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd, $CmdArgs, $Cluster)

                if ($Cmd -eq 'lssystem') {
                    if ($Cluster -eq "1.1.1.1") {
                        return [pscustomobject]@{ id = '0000020321E04D5A' }
                    }
                    if ($Cluster -eq "1.1.1.2") {
                        return [pscustomobject]@{ id = '0000020321E04D5B' }
                    }
                }
                if ($Cmd -eq 'lspartnership') {
                    if ($CmdArgs -eq "0000020321E04D5B") {
                        return [pscustomobject]@{
                            id = '0000020321E04D5B'
                            partnership = 'partially_configured_local'
                        }
                    }
                    if ($CmdArgs -eq "0000020321E04D5A") {
                        return $null
                    }
                }
                if ($Cmd -eq 'rmpartnership') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            Remove-IBMSVPartnership -RemoteCluster "1.1.1.2" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lssystem" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.1" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.stop -eq $true -and
                    $CmdArgs -eq "0000020321E04D5B"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.2" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.stop -eq $true -and
                    $CmdArgs -eq "0000020321E04D5A"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.1" -and
                    $Cmd -eq "rmpartnership" -and
                    $CmdArgs -eq "0000020321E04D5B"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.2" -and
                    $Cmd -eq "rmpartnership" -and
                    $CmdArgs -eq "0000020321E04D5A"
                }
        }

        It "Should remove partnership with -RemoteCluster (on remote cluster only)" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd, $CmdArgs, $Cluster)

                if ($Cmd -eq 'lssystem') {
                    if ($Cluster -eq "1.1.1.1") {
                        return [pscustomobject]@{ id = '0000020321E04D5A' }
                    }
                    if ($Cluster -eq "1.1.1.2") {
                        return [pscustomobject]@{ id = '0000020321E04D5B' }
                    }
                }
                if ($Cmd -eq 'lspartnership') {
                    if ($CmdArgs -eq "0000020321E04D5B") {
                        return $null
                    }
                    if ($CmdArgs -eq "0000020321E04D5A") {
                        return [pscustomobject]@{
                            id = '0000020321E04D5A'
                            partnership = 'fully_configured'
                        }
                    }
                }
                if ($Cmd -eq 'rmpartnership') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            Remove-IBMSVPartnership -RemoteCluster "1.1.1.2" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lssystem" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.1" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.stop -eq $true -and
                    $CmdArgs -eq "0000020321E04D5B"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.2" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.stop -eq $true -and
                    $CmdArgs -eq "0000020321E04D5A"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.1" -and
                    $Cmd -eq "rmpartnership" -and
                    $CmdArgs -eq "0000020321E04D5B"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.2" -and
                    $Cmd -eq "rmpartnership" -and
                    $CmdArgs -eq "0000020321E04D5A"
                }
        }

        It "Should be idempotent when FC partnership already exists on both clusters" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd, $CmdArgs, $Cluster)

                if ($Cmd -eq 'lssystem') {
                    if ($Cluster -eq "1.1.1.1") {
                        return [pscustomobject]@{ id = '0000020321E04D5A' }
                    }
                    if ($Cluster -eq "1.1.1.2") {
                        return [pscustomobject]@{ id = '0000020321E04D5B' }
                    }
                }
                if ($Cmd -eq 'lspartnership') {
                    if ($CmdArgs -eq "0000020321E04D5B") {
                        return $null
                    }
                    if ($CmdArgs -eq "0000020321E04D5A") {
                        return $null
                    }
                }
                if ($Cmd -eq 'rmpartnership') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            Remove-IBMSVPartnership -RemoteCluster "1.1.1.2" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lssystem" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "chpartnership" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "rmpartnership" }
        }

                It "Should remove partnership with -RemoteCluster (on both clusters)" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd, $CmdArgs, $Cluster)

                if ($Cmd -eq 'lssystem') {
                    if ($Cluster -eq "1.1.1.1") {
                        return [pscustomobject]@{ id = '0000020321E04D5A' }
                    }
                    if ($Cluster -eq "1.1.1.2") {
                        return [pscustomobject]@{ id = '0000020321E04D5B' }
                    }
                }
                if ($Cmd -eq 'lspartnership') {
                    if ($CmdArgs -eq "0000020321E04D5B") {
                        return [pscustomobject]@{
                            id = '0000020321E04D5B'
                            partnership = 'fully_configured_stopped'
                        }
                    }
                    if ($CmdArgs -eq "0000020321E04D5A") {
                        return [pscustomobject]@{
                            id = '0000020321E04D5A'
                            partnership = 'fully_configured_stopped'
                        }
                    }
                }
                if ($Cmd -eq 'rmpartnership') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            Remove-IBMSVPartnership -RemoteCluster "1.1.1.2" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lssystem" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "chpartnership" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.1" -and
                    $Cmd -eq "rmpartnership" -and
                    $CmdArgs -eq "0000020321E04D5B"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.2" -and
                    $Cmd -eq "rmpartnership" -and
                    $CmdArgs -eq "0000020321E04D5A"
                }
        }

        It "Should remove partnership on both clusters with -RemoteSystem and -RemoteCluster" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd, $CmdArgs, $Cluster)

                if ($Cmd -eq 'lssystem') {
                    if ($Cluster -eq "1.1.1.1") {
                        return [pscustomobject]@{ id = '0000020321E04D5A' }
                    }
                }
                if ($Cmd -eq 'lspartnership') {
                    if ($CmdArgs -eq "0000020321E04D5B") {
                        return [pscustomobject]@{
                            id = '0000020321E04D5B'
                            partnership = 'fully_configured'
                        }
                    }
                    if ($CmdArgs -eq "0000020321E04D5A") {
                        return [pscustomobject]@{
                            id = '0000020321E04D5A'
                            partnership = 'fully_configured'
                        }
                    }
                }
                if ($Cmd -eq 'rmpartnership') {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            Remove-IBMSVPartnership -RemoteSystem "0000020321E04D5B" -RemoteCluster "1.1.1.2" -Confirm:$false

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lssystem" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.1" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.stop -eq $true -and
                    $CmdArgs -eq "0000020321E04D5B"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.2" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.stop -eq $true -and
                    $CmdArgs -eq "0000020321E04D5A"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.1" -and
                    $Cmd -eq "rmpartnership" -and
                    $CmdArgs -eq "0000020321E04D5B"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.2" -and
                    $Cmd -eq "rmpartnership" -and
                    $CmdArgs -eq "0000020321E04D5A"
                }
        }
    }
}
