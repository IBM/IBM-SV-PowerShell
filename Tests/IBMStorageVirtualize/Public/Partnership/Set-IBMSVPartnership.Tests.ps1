Describe "Set-IBMSVPartnership Tests" {
    $script:fcPartnership = [pscustomobject]@{
        id                    = '0000020321E04D5A'
        type                  = 'fc'
        partnership           = 'fully_configured'
        background_copy_rate  = '50'
        link_bandwidth_mbits  = '1000'
        pbr_in_use            = 'no'
    }

    # Shared helper: a fully_configured IP partnership
    $script:ipPartnership = [pscustomobject]@{
        id                    = '0000020321E04D5B'
        type                  = 'ipv4'
        partnership           = 'fully_configured'
        background_copy_rate  = '50'
        link_bandwidth_mbits  = '1000'
        cluster_ip            = '1.1.1.2'
        link1                 = 'portset0'
        link2                 = ''
        chap_secret           = ''
        compressed            = 'no'
        secured               = 'no'
        pbr_in_use            = 'no'
    }

    Context "Parameter Validation" {
        BeforeEach {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq "lspartnership") {
                    return [pscustomobject]@{
                        id                    = '0000020321E04D5A'
                        type                  = 'fc'
                        partnership           = 'fully_configured'
                        background_copy_rate  = '50'
                        link_bandwidth_mbits  = '1000'
                        pbr_in_use            = 'no'
                    }
                }
                if ($Cmd -eq "chpartnership") {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize
        }

        It "Should throw error when mutually exclusive parameters are specified" {
            { Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -Start -Stop } | Should -Throw "Parameters Start, Stop are mutually exclusive."
            { Set-IBMSVPartnership -RemoteSystem "0000020321E04D5B" -ChapSecret "secret" -NoChapSecret } | Should -Throw "Parameters ChapSecret, NoChapSecret are mutually exclusive."
            { Set-IBMSVPartnership -RemoteSystem "0000020321E04D5B" -Link1 "portset0" -NoLink1 } | Should -Throw "Parameters Link1, NoLink1 are mutually exclusive."
            { Set-IBMSVPartnership -RemoteSystem "0000020321E04D5B" -Link2 "portset1" -NoLink2 } | Should -Throw "Parameters Link2, NoLink2 are mutually exclusive."
        }

        It "Should throw error when neither RemoteSystem nor RemoteCluster is specified" {
            { Set-IBMSVPartnership -LinkBandwidthMbits 2000 } | Should -Throw "At least one of -RemoteSystem or -RemoteCluster must be specified."
        }

        It "Should throw error when IP-only parameters are used on an FC partnership" {
            { Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -Link1 "portset0" } | Should -Throw "Parameter(s) -Link1 are not applicable for FC partnerships."
        }

        It "Should throw error when partnership does not exist" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lspartnership') { return $null }
                if ($Cmd -eq 'chpartnership') { return $null }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -LinkBandwidthMbits 2000 } | Should -Throw "Partnership with system '0000020321E04D5A' does not exist on local system."
        }

        It "Should not call chpartnership when -WhatIf is specified" {
            Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -LinkBandwidthMbits 2000 -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "chpartnership" }
        }
    }

    Context "Local Cluster Only" {
        Context "FC Partnership" {
            BeforeEach {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd)
                    if ($Cmd -eq "lspartnership") {
                        return [pscustomobject]@{
                            id                    = '0000020321E04D5A'
                            type                  = 'fc'
                            partnership           = 'fully_configured'
                            background_copy_rate  = '50'
                            link_bandwidth_mbits  = '1000'
                            pbr_in_use            = 'no'
                        }
                    }
                    if ($Cmd -eq "chpartnership") {
                        return $null
                    }
                } -ModuleName IBMStorageVirtualize
            }

            It "Should update LinkBandwidthMbits" {
                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -LinkBandwidthMbits 2000 -BackgroundCopyRate 100

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.linkbandwidthmbits -eq 2000 -and
                        $CmdOpts.backgroundcopyrate -eq 100 -and
                        $CmdArgs -eq "0000020321E04D5A"
                    }
            }

            It "Should update PBRinUse" {
                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -PBRinUse "yes"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.pbrinuse -eq "yes" -and
                        $CmdArgs -eq "0000020321E04D5A"
                    }
            }

            It "Should stop a running FC partnership" {
                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -Stop

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.stop -eq $true -and
                        $CmdArgs -eq "0000020321E04D5A"
                    }
            }

            It "Should start a stopped FC partnership" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd)
                    if ($Cmd -eq 'lspartnership') {
                        return [pscustomobject]@{
                            id                   = '0000020321E04D5A'
                            type                 = 'fc'
                            partnership          = 'fully_configured_stopped'
                            background_copy_rate = '50'
                            link_bandwidth_mbits = '1000'
                            pbr_in_use           = 'no'
                        }
                    }
                    if ($Cmd -eq 'chpartnership') { return $null }
                } -ModuleName IBMStorageVirtualize

                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -Start

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.start -eq $true -and
                        $CmdArgs -eq "0000020321E04D5A"
                    }
            }

            It "Should update FC partnership with multiple parameters" {
                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -LinkBandwidthMbits 2000 -BackgroundCopyRate 100 -PBRinUse "yes" -Stop

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.linkbandwidthmbits -eq 2000 -and
                        $CmdOpts.backgroundcopyrate -eq 100 -and
                        $CmdArgs -eq "0000020321E04D5A"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.pbrinuse -eq "yes" -and
                        $CmdArgs -eq "0000020321E04D5A"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.stop -eq $true -and
                        $CmdArgs -eq "0000020321E04D5A"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 4 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should be idempotent when updating FC partnership with same values" {
                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -LinkBandwidthMbits 1000 -BackgroundCopyRate 50 -PBRinUse "no" -Start

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "chpartnership" }
            }
        }

        Context "IP Partnership" {
            BeforeEach {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd)
                    if ($Cmd -eq "lspartnership") {
                        return [pscustomobject]@{
                            id                    = '0000020321E04D5B'
                            type                  = 'ipv4'
                            partnership           = 'fully_configured'
                            background_copy_rate  = '50'
                            link_bandwidth_mbits  = '1000'
                            cluster_ip            = '1.1.1.2'
                            link1                 = 'portset0'
                            link2                 = ''
                            chap_secret           = ''
                            compressed            = 'no'
                            secured               = 'no'
                            pbr_in_use            = 'no'
                        }
                    }
                    if ($Cmd -eq "chpartnership") {
                        return $null
                    }
                } -ModuleName IBMStorageVirtualize
            }
            It "Should update Link1" {
                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5B" -Link1 "portset2"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.link1 -eq "portset2" -and
                        $CmdArgs -eq "0000020321E04D5B"
                    }
            }

            It "Should remove Link1 with NoLink1" {
                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5B" -NoLink1

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.nolink1 -eq $true -and
                        $CmdArgs -eq "0000020321E04D5B"
                    }
            }

            It "Should auto stop/start when updating Compressed (partnership is running)" {
                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5B" -Compressed "yes"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.stop -eq $true -and
                        $CmdArgs -eq "0000020321E04D5B"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.compressed -eq "yes" -and
                        $CmdArgs -eq "0000020321E04D5B"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.start -eq $true -and
                        $CmdArgs -eq "0000020321E04D5B"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 4 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should auto stop but NOT restart when -Stop is also specified with a requires-stop param" {
                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5B" -Compressed "yes" -Stop

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "chpartnership" -and $CmdOpts.stop -eq $true }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.compressed -eq "yes" -and
                        $CmdArgs -eq "0000020321E04D5B"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "chpartnership" -and $CmdOpts.start -eq $true }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 3 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should auto stop/start when updating Compressed (partnership is stopped)" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd)
                    if ($Cmd -eq 'lspartnership') {
                        return [pscustomobject]@{
                            id                    = '0000020321E04D5B'
                            type                  = 'ipv4'
                            partnership           = 'fully_configured_stoppee'
                            compressed            = 'no'
                        }
                    }
                    if ($Cmd -eq 'chpartnership') { return $null }
                } -ModuleName IBMStorageVirtualize

                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5B" -Compressed "yes"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.compressed -eq "yes" -and
                        $CmdArgs -eq "0000020321E04D5B"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should NOT stop/start when updating only non-requires-stop IP params" {
                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5B" -Secured "yes"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "chpartnership" -and $CmdOpts.stop -eq $true }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "chpartnership" -and $CmdOpts.start -eq $true }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.secured -eq "yes" -and
                        $CmdArgs -eq "0000020321E04D5B"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should update IP partnership with multiple parameters" {
                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5B" -ChapSecret "abcd1234" -LinkBandwidthMbits 2000 -BackgroundCopyRate 100 -Compressed "yes" -Link1 "portset1" -Link2 "portset2" -Secured "yes" -PBRinUse "yes"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.stop -eq $true -and
                        $CmdArgs -eq "0000020321E04D5B"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.linkbandwidthmbits -eq 2000 -and
                        $CmdOpts.backgroundcopyrate -eq 100 -and
                        $CmdArgs -eq "0000020321E04D5B"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.pbrinuse -eq "yes" -and
                        $CmdArgs -eq "0000020321E04D5B"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.chapsecret -eq "abcd1234" -and
                        $CmdOpts.compressed -eq "yes" -and
                        $CmdOpts.link1 -eq "portset1" -and
                        $CmdOpts.link2 -eq "portset2" -and
                        $CmdOpts.secured -eq "yes" -and
                        $CmdArgs -eq "0000020321E04D5B"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "chpartnership" -and
                        $CmdOpts.start -eq $true -and
                        $CmdArgs -eq "0000020321E04D5B"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 6 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should be idempotent when updating IP partnership with same values" {
                Set-IBMSVPartnership -RemoteSystem "0000020321E04D5B" -NoChapSecret -LinkBandwidthMbits 1000 -BackgroundCopyRate 50 -Compressed "no" -Link1 "portset0" -NoLink2 -Secured "no" -PBRinUse "no"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "chpartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -Exactly -ModuleName IBMStorageVirtualize
            }
        }
    }

    Context "Both Clusters" {
        BeforeEach {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd, $CmdArgs, $Cluster)
                if ($Cmd -eq 'lssystem') {
                    if ($Cluster -eq "1.1.1.2") { return [pscustomobject]@{ id = '0000020321E04D5B' } }
                    return [pscustomobject]@{ id = '0000020321E04D5A' }
                }
                if ($Cmd -eq 'lspartnership') {
                    if ($CmdArgs -eq '0000020321E04D5B') {
                        return [pscustomobject]@{
                            id                   = '0000020321E04D5B'
                            type                 = 'fc'
                            partnership          = 'fully_configured'
                            background_copy_rate = '100'
                            link_bandwidth_mbits = '1000'
                        }
                    }
                    if ($CmdArgs -eq '0000020321E04D5A') {
                        return [pscustomobject]@{
                            id                   = '0000020321E04D5A'
                            type                 = 'fc'
                            partnership          = 'fully_configured'
                            background_copy_rate = '50'
                            link_bandwidth_mbits = '1000'
                        }
                    }
                }
                if ($Cmd -eq 'chpartnership') { return $null }
            } -ModuleName IBMStorageVirtualize
        }
        It "Should throw error when partnership does not exist on local cluster" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd, $CmdArgs, $Cluster)
                if ($Cmd -eq 'lssystem') {
                    if ($Cluster -eq "1.1.1.2") { return [pscustomobject]@{ id = '0000020321E04D5B' } }
                    return [pscustomobject]@{ id = '0000020321E04D5A' }
                }
                if ($Cmd -eq 'lspartnership') {
                    if ($CmdArgs -eq '0000020321E04D5B') { return  }
                    if ($CmdArgs -eq '0000020321E04D5A') { return [pscustomobject]@{ id = '0000020321E04D5A' } }
                }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVPartnership -RemoteCluster "1.1.1.2" -LinkBandwidthMbits 2000 } | Should -Throw "Partnership with system '0000020321E04D5B' does not exist on local system."
        }

        It "Should throw error when partnership does not exist on remote cluster" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd, $CmdArgs, $Cluster)
                if ($Cmd -eq 'lssystem') {
                    if ($Cluster -eq "1.1.1.2") { return [pscustomobject]@{ id = '0000020321E04D5B' } }
                    return [pscustomobject]@{ id = '0000020321E04D5A' }
                }
                if ($Cmd -eq 'lspartnership') {
                    if ($CmdArgs -eq '0000020321E04D5B') { return [pscustomobject]@{ id = '0000020321E04D5A' } }
                    if ($CmdArgs -eq '0000020321E04D5A') { return $null }
                }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVPartnership -RemoteCluster "1.1.1.2" -LinkBandwidthMbits 2000 } | Should -Throw "Partnership with system '0000020321E04D5A' does not exist on remote system."
        }

        It "Should update partnership on both clusters with -RemoteCluster only" {
            Set-IBMSVPartnership -RemoteCluster "1.1.1.2" -LinkBandwidthMbits 2000

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lssystem" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -ne "1.1.1.2" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.linkbandwidthmbits -eq 2000
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.2" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.linkbandwidthmbits -eq 2000
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 6 -Exactly -ModuleName IBMStorageVirtualize
        }

        It "Should update partnership on both clusters with -RemoteSystem and -RemoteCluster" {
            Set-IBMSVPartnership -RemoteSystem "0000020321E04D5B" -RemoteCluster "1.1.1.2" -LinkBandwidthMbits 2000

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lssystem" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -ne "1.1.1.2" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.linkbandwidthmbits -eq 2000
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.2" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.linkbandwidthmbits -eq 2000
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 5 -Exactly -ModuleName IBMStorageVirtualize
        }

        It "Should update partnership on remote clusters only" {
            Set-IBMSVPartnership -RemoteCluster "1.1.1.2" -BackgroundCopyRate 100

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lssystem" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -ne "1.1.1.2" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.backgroundcopyrate -eq 100 -and
                    $CmdArgs -eq "0000020321E04D5B"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cluster -eq "1.1.1.2" -and
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.backgroundcopyrate -eq 100 -and
                    $CmdArgs -eq "0000020321E04D5A"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 5 -Exactly -ModuleName IBMStorageVirtualize
        }

        It "Should update IP partnership with multiple parameters" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd, $CmdArgs, $Cluster)
                if ($Cmd -eq 'lssystem') {
                    if ($Cluster -eq "1.1.1.2") { return [pscustomobject]@{ id = '0000020321E04D5B' } }
                    return [pscustomobject]@{ id = '0000020321E04D5A' }
                }
                if ($Cmd -eq "lspartnership") {
                    return [pscustomobject]@{
                        id                    = $CmdArgs
                        type                  = 'ipv4'
                        partnership           = 'fully_configured'
                        background_copy_rate  = '50'
                        link_bandwidth_mbits  = '1000'
                        link1                 = 'portset0'
                        link2                 = ''
                        chap_secret           = ''
                        compressed            = 'no'
                        secured               = 'no'
                        pbr_in_use            = 'no'
                    }
                }
                if ($Cmd -eq "chpartnership") {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVPartnership -RemoteCluster "1.1.1.2" -ChapSecret "abcd1234" -LinkBandwidthMbits 2000 -BackgroundCopyRate 100 -Compressed "yes" -Link1 "portset1" -Link2 "portset2" -Secured "yes" -PBRinUse "yes"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lssystem" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.stop -eq $true
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.linkbandwidthmbits -eq 2000 -and
                    $CmdOpts.backgroundcopyrate -eq 100
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.pbrinuse -eq "yes"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.chapsecret -eq "abcd1234" -and
                    $CmdOpts.compressed -eq "yes" -and
                    $CmdOpts.link1 -eq "portset1" -and
                    $CmdOpts.link2 -eq "portset2" -and
                    $CmdOpts.secured -eq "yes"
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                -ParameterFilter {
                    $Cmd -eq "chpartnership" -and
                    $CmdOpts.start -eq $true
                }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 14 -Exactly -ModuleName IBMStorageVirtualize
        }

        It "Should be idempotent when updating IP partnership with same values" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd, $CmdArgs, $Cluster)
                if ($Cmd -eq 'lssystem') {
                    if ($Cluster -eq "1.1.1.2") { return [pscustomobject]@{ id = '0000020321E04D5B' } }
                    return [pscustomobject]@{ id = '0000020321E04D5A' }
                }
                if ($Cmd -eq "lspartnership") {
                    if ($CmdArgs -eq '0000020321E04D5B') {
                        return [pscustomobject]@{
                            id                    = '0000020321E04D5B'
                            type                  = 'ipv4'
                            partnership           = 'fully_configured'
                            background_copy_rate  = '50'
                            link_bandwidth_mbits  = '1000'
                            cluster_ip            = '1.1.1.1'
                            link1                 = 'portset0'
                            link2                 = ''
                            chap_secret           = ''
                            compressed            = 'no'
                            secured               = 'no'
                            pbr_in_use            = 'no'
                        }
                    }
                    if ($CmdArgs -eq '0000020321E04D5A') {
                        return [pscustomobject]@{
                            id                    = '0000020321E04D5A'
                            type                  = 'ipv4'
                            partnership           = 'fully_configured'
                            background_copy_rate  = '50'
                            link_bandwidth_mbits  = '1000'
                            cluster_ip            = '1.1.1.2'
                            link1                 = 'portset0'
                            link2                 = ''
                            chap_secret           = ''
                            compressed            = 'no'
                            secured               = 'no'
                            pbr_in_use            = 'no'
                        }

                    }
                }
                if ($Cmd -eq "chpartnership") {
                    return $null
                }
            } -ModuleName IBMStorageVirtualize
            Set-IBMSVPartnership -RemoteCluster "1.1.1.2" -NoChapSecret -LinkBandwidthMbits 1000 -BackgroundCopyRate 50 -Compressed "no" -Link1 "portset0" -NoLink2 -Secured "no" -PBRinUse "no"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "chpartnership" }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 4 -Exactly -ModuleName IBMStorageVirtualize
        }
    }

    It "Should throw error when REST API fails on chpartnership" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lspartnership') { return [pscustomobject]@{ id = '0000020321E04D5B' } }
            if ($Cmd -eq 'chpartnership') {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/chpartnership/0000020321E04D5A"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -LinkBandwidthMbits 2000 } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/chpartnership/0000020321E04D5A"
    }
}
