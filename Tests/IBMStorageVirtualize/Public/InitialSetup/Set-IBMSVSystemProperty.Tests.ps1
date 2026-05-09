Describe "Set-IBMSVSystemProperty" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lssystem") {
                return [pscustomobject]@{
                    name='pwsh_system'; console_IP = '1.1.1.10:443'; inventory_mail_interval = '0'; gm_link_tolerance = '300'; gm_max_host_delay = '5';
                    cluster_ntp_IP_address = '1.1.1.11'; cluster_isns_IP_address = '1.1.1.12'; iscsi_chap_secret = 'abcd1234'; relationship_bandwidth_limit = '25';
                    layer = 'replication'; cache_prefetch = 'on'; local_fc_port_mask = '1111111111111111111111111111111111111111111111111111111111111111'
                    partner_fc_port_mask = '1111111111111111111111111111111111111111111111111111111111111111'; topology = 'standard'; vdisk_protection_time = '15'
                    vdisk_protection_enabled = 'yes'; odx = 'off'; easy_tier_acceleration = 'off'; max_replication_delay = '0'; rc_buffer_size='256'
                    partnership_exclusion_threshold = '315'; enhanced_callhome = 'on'; censor_callhome = 'off'; host_unmap = 'off'; backend_unmap = 'on'
                    quorum_mode = 'standard'; quorum_site_name = ''; quorum_lease = 'short'; snapshot_policy_suspended = 'no'; easytier = 'on'
                    snapshot_preserve_parent = 'no'; flashcopy_default_grainsize = '256'; storage_insights_control_access = 'no'; auto_drive_download = 'on'
                    time_zone = '522 UTC'
                }
            }
            if ($Cmd -eq "lstimezones") {
                return @(
                    [pscustomobject]@{ id = '522'; timezone = 'UTC' }
                    [pscustomobject]@{ id = '523'; timezone = 'WET' }
                )
            }
            if ($Cmd -eq 'chsystem') {
                return [pscustomobject]@{ message = 'System updated successfully' }
            }
            if ($Cmd -eq 'settimezone') {
                return [pscustomobject]@{ message = 'Timezone set successfully' }
            }
            if ($Cmd -eq 'setsystemtime') {
                return [pscustomobject]@{ message = 'System time set successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }
    It "Should throw when ChapSecret and NoChapSecret are both specified" {
        { Set-IBMSVSystemProperty -ChapSecret "abc123" -NoChapSecret } | Should -Throw "CMMVC5713E Parameter -ChapSecret and -NoChapSecret are mutually exclusive."
    }

    It "Should throw when Time and NtpIp are both specified" {
        { Set-IBMSVSystemProperty -Time "040509142003" -NtpIp "1.1.1.11" } | Should -Throw "CMMVC5713E Parameters -Time and -NtpIp are mutually exclusive."
    }

    It "Should throw when QuorumSite used without QuorumMode and current QuorumMode is 'standard'" {
        { Set-IBMSVSystemProperty -QuorumSite "Site1" } | Should -Throw "Parameter -QuorumSite is not valid when current quorum mode is 'standard'. Specify -QuorumMode."
    }

    It "Should throw when QuorumMode 'winner' used without QuorumSite" {
        { Set-IBMSVSystemProperty -QuorumMode "winner" } | Should -Throw "Parameter -QuorumSite is required when quorum mode is 'winner'."
    }

    It "Should throw when QuorumSite used with QuorumMode 'standard'" {
        { Set-IBMSVSystemProperty -QuorumMode "standard" -QuorumSite "Site1" } | Should -Throw "Parameter -QuorumSite is not valid when quorum mode is 'standard'."
    }

    It "Should not call API to update system when -WhatIf is specified" {
        Set-IBMSVSystemProperty -Name "pwsh_system1" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should update system name (single string parameter)" {
        Set-IBMSVSystemProperty -Name "pwsh_system1"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'lssystem' }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chsystem' -and $CmdOpts.name -eq 'pwsh_system1' }
    }

    It "Should update system vdiskprotectiontime (single int parameter)" {
        Set-IBMSVSystemProperty -VdiskProtectionTime 20

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'lssystem' }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chsystem' -and $CmdOpts.vdiskprotectiontime -eq 20 }
    }

    It "Should update system chapsecret (single bool parameter)" {
        Set-IBMSVSystemProperty -NoChapSecret

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'lssystem' }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chsystem' -and $CmdOpts.nochapsecret -eq $true }
    }

    It "Should update exclusive parameters" {
        Set-IBMSVSystemProperty -RelationshipBandwidthLimit 50 -GMMaxHostDelay 6

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'lssystem' }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "chsystem" -and $CmdOpts.relationshipbandwidthlimit -eq 50 }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "chsystem" -and $CmdOpts.gmmaxhostdelay -eq 6 }
    }

    It "Should update exclusive parameters with other parameters" {
        Set-IBMSVSystemProperty -Odx "on" -RCBufferSize 128 -Name "pwsh_system1" -StorageInsightsControlAccess "yes"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'lssystem' }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "chsystem" -and $CmdOpts.odx -eq "on" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "chsystem" -and $CmdOpts.rcbuffersize -eq 128 }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq "chsystem" -and $CmdOpts.name -eq "pwsh_system1" -and $CmdOpts.storageinsightscontrolaccess -eq "yes" }
    }

    It "Should update system" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lssystem") {
                return [pscustomobject]@{
                    console_IP = '1.1.1.10:443'; inventory_mail_interval = '0'; gm_link_tolerance = '300'; gm_max_host_delay = '5'; cluster_ntp_IP_address = ''
                    cluster_isns_IP_address = ''; iscsi_chap_secret = ''; relationship_bandwidth_limit = '25'; layer = 'replication'; cache_prefetch = 'on'
                    local_fc_port_mask = '1111111111111111111111111111111111111111111111111111111111111111'
                    partner_fc_port_mask = '1111111111111111111111111111111111111111111111111111111111111111'; topology = 'standard'; rc_buffer_size = '256'
                    vdisk_protection_enabled = 'yes'; odx = 'off'; easy_tier_acceleration = 'off'; max_replication_delay = '0'
                    partnership_exclusion_threshold = '315'; enhanced_callhome = 'on'; censor_callhome = 'off'; host_unmap = 'off'; backend_unmap = 'on'
                    quorum_mode = 'standard'; quorum_site_name = ''; quorum_lease = 'short'; snapshot_policy_suspended = 'no'; easytier = 'on'
                    snapshot_preserve_parent = 'no'; flashcopy_default_grainsize = '256'; storage_insights_control_access = 'no'; auto_drive_download = 'on'
                }
            }
            if ($Cmd -eq 'chsystem') {
                return [pscustomobject]@{ message = 'System updated successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVSystemProperty -RCBufferSize 128 -ConsoleIp "1.1.1.11" -InvEmailInterval 1 -GMMLinkTolerance 500 -GMMaxHostDelay 6 -NtpIp "1.1.1.12" `
        -IsnsIp "1.1.1.13" -RelationshipBandwidthLimit 512  -ChapSecret "abcd1234" -Layer "storage" -CachePrefetch "off" -LocalFcPortMask "111111101101" `
        -PartnerFcPortMask "111111101101" -Topology "hyperswap" -VdiskProtectionEnabled "no" -Odx "on" -EasyTierAcceleration "on" `
        -MaxReplicationDelay 10 -PartnershipExclusionThreshold 300 -EnhancedCallHome "off" -CensorCallHome "on" -HostUnmap "on" -BackendUnmap "off" `
        -QuorumMode "winner" -QuorumSite "site1" -QuorumLease "long" -SnapshotPolicySuspended "yes" -EasyTier "off" -SnapshotPreserveParent "yes" `
        -FlashcopyDefaultGrainSize 128 -StorageInsightsControlAccess "yes" -AutoDriveDownload "off"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'lssystem' }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chsystem'
                $CmdOpts.rcbuffersize -eq 128 -and
                $CmdOpts.consoleip -eq "1.1.1.11" -and
                $CmdOpts.invemailinterval -eq 1 -and
                $CmdOpts.gmmlinktolerance -eq 500 -and
                $CmdOpts.gmmaxhostdelay -eq 6 -and
                $CmdOpts.ntpip -eq "1.1.1.12" -and
                $CmdOpts.isnsip -eq "1.1.1.13" -and
                $CmdOpts.relationshipbandwidthlimit -eq 512 -and
                $CmdOpts.chapsecret -eq "abcd1234" -and
                $CmdOpts.layer -eq "storage" -and
                $CmdOpts.cacheprefetch -eq "off" -and
                $CmdOpts.localfcportmask -eq "111111101101" -and
                $CmdOpts.partnerfcportmask -eq "111111101101" -and
                $CmdOpts.topology -eq "hyperswap" -and
                $CmdOpts.vdiskprotectionenabled -eq "no" -and
                $CmdOpts.odx -eq "on" -and
                $CmdOpts.easytieracceleration -eq "on" -and
                $CmdOpts.maxreplicationdelay -eq 10 -and
                $CmdOpts.partnershipexclusionthreshold -eq 300 -and
                $CmdOpts.enhancedcallhome -eq "off" -and
                $CmdOpts.censorcallhome -eq "on" -and
                $CmdOpts.hostunmap -eq "on" -and
                $CmdOpts.backendunmap -eq "off" -and
                $CmdOpts.quorummode -eq "winner" -and
                $CmdOpts.quorumsite -eq "site1" -and
                $CmdOpts.quorumlease -eq "long" -and
                $CmdOpts.snapshotpolicysuspended -eq "yes" -and
                $CmdOpts.easytier -eq "off" -and
                $CmdOpts.snapshotpreserveparent -eq "yes" -and
                $CmdOpts.flashcopydefaultgrainsize -eq "128" -and
                $CmdOpts.storageinsightscontrolaccess -eq "yes" -and
                $CmdOpts.autodrivedownload -eq "off"
            }
    }

    It "Should update system name, time and timzeone" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lssystem") {
                return [pscustomobject]@{
                    name = 'fs5200-cl'
                    cluster_ntp_IP_address = ''
                    time_zone = '522 UTC'
                }
            }
            if ($Cmd -eq 'chsystem') {
                return [pscustomobject]@{ message = 'System updated successfully' }
            }
            if ($Cmd -eq 'settimezone') {
                return [pscustomobject]@{ message = 'Timezone set successfully' }
            }
            if ($Cmd -eq 'setsystemtime') {
                return [pscustomobject]@{ message = 'System time set successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVSystemProperty -Name "pwsh_system1" -Time "040509142003" -Timezone "523"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'lssystem' }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chsystem" -and $CmdOpts.name -eq "pwsh_system1" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "setsystemtime" -and $CmdOpts.time -eq "040509142003" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "settimezone" -and $CmdOpts.timezone -eq "523" }
    }

    It "Should update timezone (using region string)" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lssystem") {
                return [pscustomobject]@{ time_zone = '522 UTC' }
            }
            if ($Cmd -eq "lstimezones") {
                return @(
                    [pscustomobject]@{ id = '522'; timezone = 'UTC' }
                    [pscustomobject]@{ id = '523'; timezone = 'WET' }
                )
            }
            if ($Cmd -eq 'settimezone') {
                return [pscustomobject]@{ message = 'Timezone set successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVSystemProperty -Timezone "WET"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'lssystem' }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'lstimezones' }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "settimezone" -and $CmdOpts.timezone -eq "523" }
    }

    It "Should to be idempotent when updating system" {
        Set-IBMSVSystemProperty -Name "pwsh_system" -RCBufferSize 256 -ConsoleIp "1.1.1.10" -InvEmailInterval 0 -GMMLinkTolerance 300 -GMMaxHostDelay 5 `
        -NtpIp "1.1.1.11" -IsnsIp "1.1.1.12" -RelationshipBandwidthLimit 25  -ChapSecret "abcd1234" -Layer "replication" -CachePrefetch "on" `
        -LocalFcPortMask "1111111111111111111111111111111111111111111111111111111111111111" -Topology "standard" -VdiskProtectionTime 15 -VdiskProtectionEnabled "yes" `
        -Odx "off" -EasyTierAcceleration "off" -MaxReplicationDelay 0 -PartnershipExclusionThreshold 315 -EnhancedCallHome "on" -CensorCallHome "off" `
        -HostUnmap "off" -BackendUnmap "on" -QuorumMode "standard" -QuorumLease "short" -SnapshotPolicySuspended "no" -EasyTier "on" `
        -SnapshotPreserveParent "no" -FlashcopyDefaultGrainSize 256 -StorageInsightsControlAccess "no" -AutoDriveDownload "on" -Timezone "522" `
        -PartnerFcPortMask "1111111111111111111111111111111111111111111111111111111111111111"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'lssystem' }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chsystem' }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lssystem") {
                return [pscustomobject]@{ name='pwsh_system' }
            }
            if ($Cmd -eq 'chsystem') {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/chsystem"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVSystemProperty -Name "pwsh_system1" } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/chsystem"
    }
}
