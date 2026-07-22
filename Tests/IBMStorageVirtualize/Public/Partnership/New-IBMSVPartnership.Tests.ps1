Describe "New-IBMSVPartnership Tests" {
    $script:FlashSystemRestApiPort = 7443

    InModuleScope IBMStorageVirtualize {
        $script:primarysession = "1.1.1.1"
    }
    Context "Parameter Validation" {
        It "Should throw error when RemoteSystem and ClusterIP are both specified" {
            { New-IBMSVPartnership -Type FC -RemoteSystem "0000020321E04D5A" -ClusterIP "192.168.1.100" -LinkBandwidthMbits 10000 } | Should -Throw "-RemoteSystem and -ClusterIP are mutually exclusive. Use -RemoteSystem for FC partnerships or -ClusterIP for IP partnerships."
        }

        It "Should throw error when IP partnership parameters are used with FC type" {
            { New-IBMSVPartnership -Type FC -RemoteSystem "0000020321E04D5A" -LinkBandwidthMbits 10000 -Link1 "portset0" } | Should -Throw "Parameter(s) -Link1 are not applicable for FC partnerships."
        }

        It "Should throw error when RemoteSystem is not specified for FC without RemoteCluster" {
            { New-IBMSVPartnership -Type FC -LinkBandwidthMbits 10000 } | Should -Throw "-RemoteSystem is required when -RemoteCluster is not specified for FC partnerships."
        }

        It "Should throw error when ClusterIP is not specified for IP without RemoteCluster" {
            { New-IBMSVPartnership -Type IP -Link1 "portset0" -LinkBandwidthMbits 10000 } | Should -Throw "-ClusterIP is required when -RemoteCluster is not specified for IP partnerships."
        }

        It "Should throw error when neither Link1 nor Link2 is specified for IP partnership" {
            { New-IBMSVPartnership -Type IP -ClusterIP "192.168.1.100" -LinkBandwidthMbits 10000 } | Should -Throw "At least one of Link1 or Link2 must be specified for IP partnerships."
        }

        It "Should throw error when RemoteLink is specified without RemoteCluster" {
            { New-IBMSVPartnership -Type IP -ClusterIP "192.168.1.100" -Link1 "portset0" -RemoteLink1 "portset1" -LinkBandwidthMbits 10000 } | Should -Throw "-RemoteCluster is required when -RemoteLink1 or -RemoteLink2 is specified."
        }
    }

    Context "FC Partnership" {
        It "Should not call API to create FC partnership when -WhatIf is specified" {
            Mock Invoke-IBMSVRestRequest {} -ModuleName IBMStorageVirtualize
            New-IBMSVPartnership -Type FC -RemoteSystem "0000020321E04D5A" -LinkBandwidthMbits 10000 -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }

        Context "Local Cluster Only" {
            BeforeEach {
                $script:LsPartnershipCalls = 0
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd, $CmdArgs)
                    if ($Cmd -eq "lspartnership") {
                        $script:LsPartnershipCalls++
                        if ($script:LsPartnershipCalls -eq 1) {
                            return $null
                        }
                        return [pscustomobject]@{
                            id = $CmdArgs
                            name = 'remote_system'
                            partnership = 'fully_configured'
                            console_ip = "1.1.1.1:$script:FlashSystemRestApiPort"
                        }
                    }
                } -ModuleName IBMStorageVirtualize
            }
            It "Should create FC partnership on local cluster with RemoteSystem only" {
                $result = New-IBMSVPartnership -Type FC -RemoteSystem "0000020321E04D5A" -LinkBandwidthMbits 10000
                $result.id | Should -Be '0000020321E04D5A'
                $result.partnership | Should -Be 'fully_configured'

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "mkfcpartnership" -and
                        $CmdOpts.linkbandwidthmbits -eq 10000 -and
                        $CmdArgs -eq "0000020321E04D5A"
                    }
            }

            It "Should be idempotent when FC partnership already exists" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd)
                    if ($Cmd -eq "lspartnership") {
                        return [pscustomobject]@{ id = '0000020321E04D5A'; partnership = 'fully_configured' }
                    }
                } -ModuleName IBMStorageVirtualize

                $result = New-IBMSVPartnership -Type FC -RemoteSystem "0000020321E04D5A" -LinkBandwidthMbits 10000
                $result.id | Should -Be '0000020321E04D5A'
                $result.partnership | Should -Be 'fully_configured'

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "mkfcpartnership" }
            }

            It "Should create FC partnership with multiple parameter" {
                $result = New-IBMSVPartnership -Type FC -RemoteSystem "0000020321E04D5A" -LinkBandwidthMbits 10000 -BackgroundCopyRate 100
                $result.id | Should -Be '0000020321E04D5A'

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "mkfcpartnership" -and
                        $CmdOpts.linkbandwidthmbits -eq 10000 -and
                        $CmdOpts.backgroundcopyrate -eq 100 -and
                        $CmdArgs -eq "0000020321E04D5A"
                    }
            }
        }

        Context "Both Clusters" {
            BeforeEach {
                $script:LsSystemCalls = 0
                $script:LsPartnershipCalls = 0
            }
            It "Should create FC partnership with -RemoteCluster (on both clusters)" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd, $CmdArgs, $Cluster)
                    if ($Cmd -eq "lspartnership") {
                        $script:LsPartnershipCalls++
                        if ($CmdArgs -eq "0000020321E04D5B") {
                            if ($script:LsPartnershipCalls -eq 1) {
                                return $null
                            }
                            elseif ($script:LsPartnershipCalls -eq 2) {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    partnership = 'partially_configured_local'
                                    console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                }
                            }
                            elseif ($script:LsPartnershipCalls -eq 5) {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                        elseif ($CmdArgs -eq "0000020321E04D5A") {
                            if ($script:LsPartnershipCalls -eq 3) {
                                return $null
                            }
                            elseif ($script:LsPartnershipCalls -eq 4) {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5A'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.1:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                    }
                    if ($Cmd -eq "lssystem") {
                        if ($Cluster -eq "1.1.1.2") {
                            return [pscustomobject]@{ id = '0000020321E04D5B' }
                        }
                        return [pscustomobject]@{ id = '0000020321E04D5A' }
                    }
                } -ModuleName IBMStorageVirtualize

                $result = New-IBMSVPartnership -Type FC -RemoteCluster "1.1.1.2" -LinkBandwidthMbits 10000
                $result.Count | Should -Be 2
                $result[0].id | Should -Be "0000020321E04D5B"
                $result[0].partnership | Should -Be "fully_configured"
                $result[0].console_ip | Should -Be "1.1.1.2:$script:FlashSystemRestApiPort"
                $result[1].id | Should -Be "0000020321E04D5A"
                $result[1].partnership | Should -Be "fully_configured"
                $result[1].console_ip | Should -Be "1.1.1.1:$script:FlashSystemRestApiPort"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lssystem" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 5 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "mkfcpartnership" -and $CmdOpts.linkbandwidthmbits -eq 10000 }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 9 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should create FC partnership with -RemoteCluster (on local cluster only)" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd, $CmdArgs, $Cluster)
                    if ($Cmd -eq "lspartnership") {
                        $script:LsPartnershipCalls++
                        if ($CmdArgs -eq "0000020321E04D5B") {
                            if ($script:LsPartnershipCalls -eq 1) {
                                return $null
                            }
                            elseif ($script:LsPartnershipCalls -eq 2) {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                        elseif ($CmdArgs -eq "0000020321E04D5A") {
                            if ($script:LsPartnershipCalls -eq 3) {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5A'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.1:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                    }
                    if ($Cmd -eq "lssystem") {
                        if ($Cluster -eq "1.1.1.2") {
                            return [pscustomobject]@{ id = '0000020321E04D5B' }
                        }
                        return [pscustomobject]@{ id = '0000020321E04D5A' }
                    }
                } -ModuleName IBMStorageVirtualize

                $result = New-IBMSVPartnership -Type FC -RemoteCluster "1.1.1.2" -LinkBandwidthMbits 10000
                $result.Count | Should -Be 2
                $result[0].id | Should -Be "0000020321E04D5B"
                $result[0].partnership | Should -Be "fully_configured"
                $result[0].console_ip | Should -Be "1.1.1.2:$script:FlashSystemRestApiPort"
                $result[1].id | Should -Be "0000020321E04D5A"
                $result[1].partnership | Should -Be "fully_configured"
                $result[1].console_ip | Should -Be "1.1.1.1:$script:FlashSystemRestApiPort"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lssystem" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 3 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "mkfcpartnership" -and $CmdOpts.linkbandwidthmbits -eq 10000 }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 6 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should create FC partnership with -RemoteCluster (on remote cluster only)" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd, $CmdArgs, $Cluster)
                    if ($Cmd -eq "lspartnership") {
                        $script:LsPartnershipCalls++
                        if ($CmdArgs -eq "0000020321E04D5B") {
                            if ($script:LsPartnershipCalls -eq 1) {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    partnership = 'partially_configured_local'
                                    console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                }
                            }
                            elseif ($script:LsPartnershipCalls -eq 4) {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                        elseif ($CmdArgs -eq "0000020321E04D5A") {
                            if ($script:LsPartnershipCalls -eq 2) {
                                return $null
                            }
                            elseif ($script:LsPartnershipCalls -eq 3) {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5A'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.1:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                    }
                    if ($Cmd -eq "lssystem") {
                        if ($Cluster -eq "1.1.1.2") {
                            return [pscustomobject]@{ id = '0000020321E04D5B' }
                        }
                        return [pscustomobject]@{ id = '0000020321E04D5A' }
                    }
                } -ModuleName IBMStorageVirtualize

                $result = New-IBMSVPartnership -Type FC -RemoteCluster "1.1.1.2" -LinkBandwidthMbits 10000
                $result.Count | Should -Be 2
                $result[0].id | Should -Be "0000020321E04D5B"
                $result[0].partnership | Should -Be "fully_configured"
                $result[0].console_ip | Should -Be "1.1.1.2:$script:FlashSystemRestApiPort"
                $result[1].id | Should -Be "0000020321E04D5A"
                $result[1].partnership | Should -Be "fully_configured"
                $result[1].console_ip | Should -Be "1.1.1.1:$script:FlashSystemRestApiPort"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lssystem" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 4 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "mkfcpartnership" -and $CmdOpts.linkbandwidthmbits -eq 10000  }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 7 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should be idempotent when FC partnership already exists on both clusters" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd, $CmdArgs, $Cluster)
                    if ($Cmd -eq "lspartnership") {
                        $script:LsPartnershipCalls++
                        if ($CmdArgs -eq "0000020321E04D5B") {
                            if ($script:LsPartnershipCalls -eq 1) {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                        elseif ($CmdArgs -eq "0000020321E04D5A") {
                            if ($script:LsPartnershipCalls -eq 2) {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5A'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.1:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                    }
                    if ($Cmd -eq "lssystem") {
                        if ($Cluster -eq "1.1.1.2") {
                            return [pscustomobject]@{ id = '0000020321E04D5B' }
                        }
                        return [pscustomobject]@{ id = '0000020321E04D5A' }
                    }
                } -ModuleName IBMStorageVirtualize

                $result = New-IBMSVPartnership -Type FC -RemoteCluster "1.1.1.2" -LinkBandwidthMbits 10000
                $result.Count | Should -Be 2
                $result[0].id | Should -Be "0000020321E04D5B"
                $result[0].partnership | Should -Be "fully_configured"
                $result[0].console_ip | Should -Be "1.1.1.2:$script:FlashSystemRestApiPort"
                $result[1].id | Should -Be "0000020321E04D5A"
                $result[1].partnership | Should -Be "fully_configured"
                $result[1].console_ip | Should -Be "1.1.1.1:$script:FlashSystemRestApiPort"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lssystem" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "mkfcpartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 4 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should create FC partnership on both clusters with -RemoteSystem and -RemoteCluster" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd, $CmdArgs)
                    if ($Cmd -eq "lspartnership") {
                        $script:LsPartnershipCalls++
                        if ($CmdArgs -eq "0000020321E04D5B") {
                            if ($script:LsPartnershipCalls -eq 1) {
                                return $null
                            }
                            elseif ($script:LsPartnershipCalls -eq 2) {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    partnership = 'partially_configured_local'
                                    console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                }
                            }
                            elseif ($script:LsPartnershipCalls -eq 5) {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                        elseif ($CmdArgs -eq "0000020321E04D5A") {
                            if ($script:LsPartnershipCalls -eq 3) {
                                return $null
                            }
                            elseif ($script:LsPartnershipCalls -eq 4) {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5A'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.1:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                    }
                    if ($Cmd -eq "lssystem") {
                        return [pscustomobject]@{ id = '0000020321E04D5A' }
                    }
                } -ModuleName IBMStorageVirtualize

                $result = New-IBMSVPartnership -Type FC -RemoteSystem "0000020321E04D5B" -RemoteCluster "1.1.1.2" -LinkBandwidthMbits 10000
                $result.Count | Should -Be 2
                $result[0].id | Should -Be "0000020321E04D5B"
                $result[0].partnership | Should -Be "fully_configured"
                $result[0].console_ip | Should -Be "1.1.1.2:$script:FlashSystemRestApiPort"
                $result[1].id | Should -Be "0000020321E04D5A"
                $result[1].partnership | Should -Be "fully_configured"
                $result[1].console_ip | Should -Be "1.1.1.1:$script:FlashSystemRestApiPort"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lssystem" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 5 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "mkfcpartnership" -and $CmdOpts.linkbandwidthmbits -eq 10000 }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 8 -Exactly -ModuleName IBMStorageVirtualize
            }
        }
    }

    Context "IP Partnership" {
        It "Should not call API to create IP partnership when -WhatIf is specified" {
            Mock Invoke-IBMSVRestRequest {} -ModuleName IBMStorageVirtualize
            New-IBMSVPartnership -Type IP -ClusterIP "1.1.1.2" -Link1 "portset0" -LinkBandwidthMbits 10000 -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }

        Context "Local Cluster Only" {
            BeforeEach {
                $script:LsPartnershipCalls = 0
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd, $CmdArgs)
                    if ($Cmd -eq "lspartnership") {
                        $script:LsPartnershipCalls++
                        if (-not $CmdArgs) {
                            # lspartnership without args - list all
                            if ($script:LsPartnershipCalls -eq 1) {
                                return @()
                            }
                            return @(
                                [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    cluster_ip = '1.1.1.2'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                }
                            )
                        }
                        else {
                            # lspartnership with id
                            return [pscustomobject]@{
                                id = '0000020321E04D5B'
                                cluster_ip = '1.1.1.2'
                                partnership = 'fully_configured'
                                console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                            }
                        }
                    }
                } -ModuleName IBMStorageVirtualize
            }

            It "Should create IP partnership on local cluster with ClusterIP only" {
                $result = New-IBMSVPartnership -Type IP -ClusterIP "1.1.1.2" -Link1 "portset0" -LinkBandwidthMbits 10000
                $result.cluster_ip | Should -Be '1.1.1.2'
                $result.partnership | Should -Be 'fully_configured'

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and -not $CmdArgs }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "mkippartnership" -and
                        $CmdOpts.clusterip -eq "1.1.1.2" -and
                        $CmdOpts.link1 -eq "portset0" -and
                        $CmdOpts.linkbandwidthmbits -eq 10000
                    }
            }

            It "Should be idempotent when IP partnership already exists" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd, $CmdArgs)
                    if ($Cmd -eq "lspartnership") {
                        if (-not $CmdArgs) {
                            return @(
                                [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    cluster_ip = '1.1.1.2'
                                    partnership = 'fully_configured'
                                    console_ip = '1.1.1.2'
                                }
                            )
                        }
                        else {
                            return [pscustomobject]@{
                                id = '0000020321E04D5B'
                                cluster_ip = '1.1.1.2'
                                partnership = 'fully_configured'
                                console_ip = '1.1.1.2'
                            }
                        }
                    }
                } -ModuleName IBMStorageVirtualize

                $result = New-IBMSVPartnership -Type IP -ClusterIP "1.1.1.2" -Link1 "portset0" -LinkBandwidthMbits 10000
                $result.cluster_ip | Should -Be '1.1.1.2'
                $result.partnership | Should -Be 'fully_configured'

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and -not $CmdArgs }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "mkippartnership" }
            }

            It "Should create IP partnership with multiple optional parameters" {
                $result = New-IBMSVPartnership -Type IP -ClusterIP "1.1.1.2" -Link1 "portset0" -Link2 "portset1" -LinkBandwidthMbits 10000 -BackgroundCopyRate 100 -ChapSecret "secret123" -Compressed "yes" -Secured "yes"
                $result.cluster_ip | Should -Be '1.1.1.2'

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and -not $CmdArgs }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cmd -eq "mkippartnership" -and
                        $CmdOpts.clusterip -eq "1.1.1.2" -and
                        $CmdOpts.link1 -eq "portset0" -and
                        $CmdOpts.link2 -eq "portset1" -and
                        $CmdOpts.linkbandwidthmbits -eq 10000 -and
                        $CmdOpts.backgroundcopyrate -eq 100 -and
                        $CmdOpts.chapsecret -eq "secret123" -and
                        $CmdOpts.compressed -eq "yes" -and
                        $CmdOpts.secured -eq "yes"
                    }
            }
        }

        Context "Both Clusters" {
            BeforeEach {
                $script:LsPartnershipCalls = 0
            }

            It "Should create IP partnership with -RemoteCluster (on both clusters)" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd, $CmdArgs)
                    if ($Cmd -eq "lspartnership") {
                        $script:LsPartnershipCalls++
                        if (-not $CmdArgs) {
                            if ($script:LsPartnershipCalls -eq 1 -or $script:LsPartnershipCalls -eq 3) {
                                return @()
                            }
                            if ($script:LsPartnershipCalls -eq 2) {
                                return @(
                                    [pscustomobject]@{
                                        id = '0000020321E04D5B'
                                        cluster_ip = '1.1.1.2'
                                        partnership = 'partially_configured_local'
                                    }
                                )
                            }
                            if ($script:LsPartnershipCalls -eq 4) {
                                return @(
                                    [pscustomobject]@{
                                        id = '0000020321E04D5A'
                                        cluster_ip = '1.1.1.1'
                                        partnership = 'fully_configured'
                                    }
                                )
                            }
                        }
                        else {
                            if ($CmdArgs -eq '0000020321E04D5A') {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5A'
                                    cluster_ip = '1.1.1.1'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.1:$script:FlashSystemRestApiPort"
                                }
                            }
                            if ($CmdArgs -eq '0000020321E04D5B') {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    cluster_ip = '1.1.1.2'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                    }
                } -ModuleName IBMStorageVirtualize

                $result = New-IBMSVPartnership -Type IP -RemoteCluster "1.1.1.2" -Link1 "portset0" -RemoteLink1 "portset1" -LinkBandwidthMbits 10000
                $result.Count | Should -Be 2
                $result[0].cluster_ip | Should -Be '1.1.1.2'
                $result[0].partnership | Should -Be 'fully_configured'
                $result[0].console_ip | Should -Be "1.1.1.2:$script:FlashSystemRestApiPort"
                $result[1].cluster_ip | Should -Be '1.1.1.1'
                $result[1].partnership | Should -Be 'fully_configured'
                $result[1].console_ip | Should -Be "1.1.1.1:$script:FlashSystemRestApiPort"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 4 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and -not $CmdArgs }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B"}
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A"}
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cluster -eq "1.1.1.1"
                        $Cmd -eq "mkippartnership" -and
                        $CmdOpts.clusterip -eq "1.1.1.2" -and
                        $CmdOpts.link1 -eq "portset0" -and
                        $CmdOpts.linkbandwidthmbits -eq 10000
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cluster -eq "1.1.1.2"
                        $Cmd -eq "mkippartnership" -and
                        $CmdOpts.clusterip -eq "1.1.1.1" -and
                        $CmdOpts.link1 -eq "portset1" -and
                        $CmdOpts.linkbandwidthmbits -eq 10000
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 8 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should create IP partnership with -RemoteCluster (on local cluster only)" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd, $CmdArgs)
                    if ($Cmd -eq "lspartnership") {
                        $script:LsPartnershipCalls++
                        if (-not $CmdArgs) {
                            if ($script:LsPartnershipCalls -eq 1) {
                                return @()
                            }
                            if ($script:LsPartnershipCalls -eq 2) {
                                return @(
                                    [pscustomobject]@{
                                        id = '0000020321E04D5B'
                                        cluster_ip = '1.1.1.2'
                                        partnership = 'fully_configured'
                                    }
                                )
                            }
                            if ($script:LsPartnershipCalls -eq 4) {
                                return @(
                                    [pscustomobject]@{
                                        id = '0000020321E04D5A'
                                        cluster_ip = '1.1.1.1'
                                        partnership = 'fully_configured'
                                    }
                                )
                            }
                        }
                        else {
                            if ($CmdArgs -eq '0000020321E04D5B') {
                                return @(
                                    [pscustomobject]@{
                                        id = '0000020321E04D5B'
                                        cluster_ip = '1.1.1.2'
                                        partnership = 'fully_configured'
                                        console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                    }
                                )
                            }
                            if ($CmdArgs -eq '0000020321E04D5A') {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5A'
                                    cluster_ip = '1.1.1.1'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.1:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                    }
                } -ModuleName IBMStorageVirtualize

                $result = New-IBMSVPartnership -Type IP -RemoteCluster "1.1.1.2" -Link1 "portset0" -RemoteLink1 "portset1" -LinkBandwidthMbits 10000
                $result.Count | Should -Be 2
                $result[0].cluster_ip | Should -Be '1.1.1.2'
                $result[0].partnership | Should -Be 'fully_configured'
                $result[0].console_ip | Should -Be "1.1.1.2:$script:FlashSystemRestApiPort"
                $result[1].cluster_ip | Should -Be '1.1.1.1'
                $result[1].partnership | Should -Be 'fully_configured'
                $result[1].console_ip | Should -Be "1.1.1.1:$script:FlashSystemRestApiPort"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 5 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cluster -eq "1.1.1.1" -and $Cmd -eq "mkippartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cluster -eq "1.1.1.2" -and $Cmd -eq "mkippartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 6 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should create IP partnership with -RemoteCluster (on remote cluster only)" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd, $CmdArgs)
                    if ($Cmd -eq "lspartnership") {
                        $script:LsPartnershipCalls++
                        if (-not $CmdArgs) {
                            if ($script:LsPartnershipCalls -eq 1) {
                                return @(
                                    [pscustomobject]@{
                                        id = '0000020321E04D5B'
                                        cluster_ip = '1.1.1.2'
                                        partnership = 'partially_configured_local'
                                    }
                                )
                            }
                            if ($script:LsPartnershipCalls -eq 2) {
                                return @()
                            }
                            if ($script:LsPartnershipCalls -eq 3) {
                                return @(
                                    [pscustomobject]@{
                                        id = '0000020321E04D5A'
                                        cluster_ip = '1.1.1.1'
                                        partnership = 'fully_configured'
                                    }
                                )
                            }
                        }
                        else {
                            if ($CmdArgs -eq '0000020321E04D5A') {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5A'
                                    cluster_ip = '1.1.1.1'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.1:$script:FlashSystemRestApiPort"
                                }
                            }
                            if ($CmdArgs -eq '0000020321E04D5B') {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    cluster_ip = '1.1.1.2'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                    }
                } -ModuleName IBMStorageVirtualize

                $result = New-IBMSVPartnership -Type IP -RemoteCluster "1.1.1.2" -Link1 "portset0" -RemoteLink1 "portset1" -LinkBandwidthMbits 10000
                $result.Count | Should -Be 2
                $result[0].cluster_ip | Should -Be '1.1.1.2'
                $result[0].partnership | Should -Be 'fully_configured'
                $result[0].console_ip | Should -Be "1.1.1.2:$script:FlashSystemRestApiPort"
                $result[1].cluster_ip | Should -Be '1.1.1.1'
                $result[1].partnership | Should -Be 'fully_configured'
                $result[1].console_ip | Should -Be "1.1.1.1:$script:FlashSystemRestApiPort"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 5 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cluster -eq "1.1.1.1" -and $Cmd -eq "mkippartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cluster -eq "1.1.1.2" -and $Cmd -eq "mkippartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 6 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should be idempotent when IP partnership already exists on both clusters" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd, $CmdArgs)
                    if ($Cmd -eq "lspartnership") {
                        $script:LsPartnershipCalls++
                        if (-not $CmdArgs) {
                            if ($script:LsPartnershipCalls -eq 1) {
                                return @(
                                    [pscustomobject]@{
                                        id = '0000020321E04D5B'
                                        cluster_ip = '1.1.1.2'
                                        partnership = 'fully_configured'
                                    }
                                )
                            }
                            elseif ($script:LsPartnershipCalls -eq 3) {
                                return @(
                                    [pscustomobject]@{
                                        id = '0000020321E04D5A'
                                        cluster_ip = '1.1.1.1'
                                        partnership = 'fully_configured'
                                    }
                                )
                            }
                        }
                        else {
                            if ($CmdArgs -eq '0000020321E04D5B') {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    cluster_ip = '1.1.1.2'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                }
                            }
                            elseif ($CmdArgs -eq '0000020321E04D5A') {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5A'
                                    cluster_ip = '1.1.1.1'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.1:$script:FlashSystemRestApiPort"
                                }
                            }
                        }
                    }
                } -ModuleName IBMStorageVirtualize

                $result = New-IBMSVPartnership -Type IP -RemoteCluster "1.1.1.2" -Link1 "portset0" -RemoteLink1 "portset1" -LinkBandwidthMbits 10000
                $result.Count | Should -Be 2
                $result[0].cluster_ip | Should -Be '1.1.1.2'
                $result[0].partnership | Should -Be 'fully_configured'
                $result[0].console_ip | Should -Be "1.1.1.2:$script:FlashSystemRestApiPort"
                $result[1].cluster_ip | Should -Be '1.1.1.1'
                $result[1].partnership | Should -Be 'fully_configured'
                $result[1].console_ip | Should -Be "1.1.1.1:$script:FlashSystemRestApiPort"

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 4 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "mkippartnership" }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 4 -Exactly -ModuleName IBMStorageVirtualize
            }

            It "Should create IP partnership with multiple optional parameters on both clusters" {
                Mock Invoke-IBMSVRestRequest {
                    param($Cmd, $CmdArgs)
                    if ($Cmd -eq "lspartnership") {
                        $script:LsPartnershipCalls++
                        if (-not $CmdArgs) {
                            if ($script:LsPartnershipCalls -eq 1 -or $script:LsPartnershipCalls -eq 3) {
                                return @()
                            }
                            if ($script:LsPartnershipCalls -eq 2) {
                                return @(
                                    [pscustomobject]@{
                                        id = '0000020321E04D5B'
                                        cluster_ip = '1.1.1.2'
                                        partnership = 'partially_configured_local'
                                    }
                                )
                            }
                            if ($script:LsPartnershipCalls -eq 4) {
                                return @(
                                    [pscustomobject]@{
                                        id = '0000020321E04D5A'
                                        cluster_ip = '1.1.1.1'
                                        partnership = 'fully_configured'
                                    }
                                )
                            }
                        }
                        else {
                            if ($CmdArgs -eq '0000020321E04D5A') {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5A'
                                    cluster_ip = '1.1.1.1'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.1:$script:FlashSystemRestApiPort"
                                    link1 = 'portset2'
                                    link2 = 'portset3'
                                    link_bandwidth_mbits = '10000'
                                    background_copy_rate = '100'
                                    chap_secret = 'secret123'
                                    compressed = 'yes'
                                    secured = 'yes'

                                }
                            }
                            if ($CmdArgs -eq '0000020321E04D5B') {
                                return [pscustomobject]@{
                                    id = '0000020321E04D5B'
                                    cluster_ip = '1.1.1.2'
                                    partnership = 'fully_configured'
                                    console_ip = "1.1.1.2:$script:FlashSystemRestApiPort"
                                    link1 = 'portset0'
                                    link2 = 'portset1'
                                    link_bandwidth_mbits = '10000'
                                    background_copy_rate = '100'
                                    chap_secret = 'secret123'
                                    compressed = 'yes'
                                    secured = 'yes'
                                }
                            }
                        }
                    }
                } -ModuleName IBMStorageVirtualize

                $result = New-IBMSVPartnership -Type IP -RemoteCluster "1.1.1.2" -Link1 "portset0" -Link2 "portset1" -RemoteLink1 "portset2" -RemoteLink2 "portset3" -LinkBandwidthMbits 10000 -BackgroundCopyRate 100 -ChapSecret "secret123" -Compressed "yes" -Secured "yes"
                $result.Count | Should -Be 2
                $result[0].cluster_ip | Should -Be '1.1.1.2'
                $result[0].partnership | Should -Be 'fully_configured'
                $result[0].console_ip | Should -Be "1.1.1.2:$script:FlashSystemRestApiPort"
                $result[0].link1 | Should -Be 'portset0'
                $result[0].link2 | Should -Be 'portset1'
                $result[0].link_bandwidth_mbits | Should -Be '10000'
                $result[0].background_copy_rate | Should -Be '100'
                $result[0].chap_secret | Should -Be 'secret123'
                $result[0].compressed | Should -Be 'yes'
                $result[0].secured | Should -Be 'yes'

                $result[1].cluster_ip | Should -Be '1.1.1.1'
                $result[1].partnership | Should -Be 'fully_configured'
                $result[1].console_ip | Should -Be "1.1.1.1:$script:FlashSystemRestApiPort"
                $result[1].link1 | Should -Be 'portset2'
                $result[1].link2 | Should -Be 'portset3'
                $result[1].link_bandwidth_mbits | Should -Be '10000'
                $result[1].background_copy_rate | Should -Be '100'
                $result[1].chap_secret | Should -Be 'secret123'
                $result[1].compressed | Should -Be 'yes'
                $result[1].secured | Should -Be 'yes'

                Assert-MockCalled Invoke-IBMSVRestRequest -Times 4 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and -not $CmdArgs }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5B"}
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter { $Cmd -eq "lspartnership" -and $CmdArgs -eq "0000020321E04D5A"}
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cluster -eq "1.1.1.1"
                        $Cmd -eq "mkippartnership" -and
                        $CmdOpts.clusterip -eq "1.1.1.2" -and
                        $CmdOpts.link1 -eq "portset0" -and
                        $CmdOpts.link2 -eq "portset1" -and
                        $CmdOpts.linkbandwidthmbits -eq 10000 -and
                        $CmdOpts.backgroundcopyrate -eq 100 -and
                        $CmdOpts.chapsecret -eq "secret123" -and
                        $CmdOpts.compressed -eq "yes" -and
                        $CmdOpts.secured -eq "yes"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                    -ParameterFilter {
                        $Cluster -eq "1.1.1.2"
                        $Cmd -eq "mkippartnership" -and
                        $CmdOpts.clusterip -eq "1.1.1.1" -and
                        $CmdOpts.link1 -eq "portset2" -and
                        $CmdOpts.link2 -eq "portset3" -and
                        $CmdOpts.linkbandwidthmbits -eq 10000 -and
                        $CmdOpts.backgroundcopyrate -eq 100 -and
                        $CmdOpts.chapsecret -eq "secret123" -and
                        $CmdOpts.compressed -eq "yes" -and
                        $CmdOpts.secured -eq "yes"
                    }
                Assert-MockCalled Invoke-IBMSVRestRequest -Times 8 -Exactly -ModuleName IBMStorageVirtualize
            }
        }
    }
}
