<#
.SYNOPSIS
Modifies system-level configuration settings on an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVSystemProperty cmdlet updates system-wide configuration.

It maps to chsystem, settimezone, and setsystemtime commands depending on requested changes.

The cmdlet is idempotent:
- Only properties that differ from the current configuration are modified.
- If no changes are required, no operation is performed.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER Name
Specifies a new name for the system.

.PARAMETER RCBufferSize
Specifies the Remote Copy buffer size.

.PARAMETER ConsoleIp
Specifies the console IP address.

.PARAMETER InvEmailInterval
Specifies the inventory email notification interval.

.PARAMETER GMMLinkTolerance
Specifies the Global Mirror link tolerance.

.PARAMETER GMMaxHostDelay
Specifies the Global Mirror maximum host delay.

.PARAMETER NtpIp
Specifies the NTP server IPv4 address.

This parameter is mutually exclusive with -Time.

.PARAMETER IsnsIp
Specifies the iSNS server IPv4 address.

.PARAMETER RelationshipBandwidthLimit
Specifies the replication bandwidth limit.

.PARAMETER ChapSecret
Specifies the iSCSI CHAP secret.

This parameter is mutually exclusive with -NoChapSecret.

.PARAMETER NoChapSecret
Removes the configured iSCSI CHAP secret.

This parameter is mutually exclusive with -ChapSecret.

.PARAMETER Layer
Specifies the system layer.
Valid values: replication, storage.

.PARAMETER CachePrefetch
Specifies whether cache prefetch is enabled.
Valid values: on, off.

.PARAMETER LocalFcPortMask
Specifies the local Fibre Channel port mask.

.PARAMETER PartnerFcPortMask
Specifies the partner Fibre Channel port mask.

.PARAMETER Topology
Specifies the system topology.
Valid values are: standard, hyperswap.

.PARAMETER VdiskProtectionTime
Specifies the volume protection time.

.PARAMETER VdiskProtectionEnabled
Specifies whether volume protection is enabled.
Valid values are: yes, no.

.PARAMETER Odx
Specifies whether ODX is enabled.
Valid values are: on, off.

.PARAMETER EasyTierAcceleration
Specifies whether Easy Tier acceleration is enabled.
Valid values are: on, off.

.PARAMETER MaxReplicationDelay
Specifies the maximum replication delay.

.PARAMETER PartnershipExclusionThreshold
Specifies the partnership exclusion threshold.

.PARAMETER EnhancedCallHome
Specifies whether Enhanced Call Home is enabled.
Valid values are: on, off.

.PARAMETER CensorCallHome
Specifies that sensitive data is deleted from the enhanced call home data.

.PARAMETER HostUnmap
Specifies whether host unmap is enabled.
Valid values are: on, off.

.PARAMETER BackendUnmap
Specifies whether backend unmap is enabled.
Valid values are: on, off.

.PARAMETER QuorumMode
Specifies the quorum mode.
Valid values are: standard, preferred, winner.

.PARAMETER QuorumSite
Specifies the quorum site name.
This parameter is not valid when quorum mode is standard.

.PARAMETER QuorumLease
Specifies the quorum lease duration.
Valid values are: short, long.

.PARAMETER SnapshotPolicySuspended
Specifies whether snapshot policies are suspended.
Valid values are: yes, no.

.PARAMETER EasyTier
Specifies whether Easy Tier is enabled.
Valid values are: on, off.

.PARAMETER SnapshotPreserveParent
Specifies whether parent snapshots are preserved.
Valid values are: yes, no.

.PARAMETER FlashcopyDefaultGrainSize
Specifies the default grain size for FlashCopy operations.

.PARAMETER StorageInsightsControlAccess
Specifies whether Storage Insights control access is enabled.
Valid values are: yes, no.

.PARAMETER AutoDriveDownload
Specifies whether the auto drive download feature for the system is enabled or disabled
Valid values are: on, off.

.PARAMETER Time
Specifies the system time.

This parameter is mutually exclusive with -NtpIp.

.PARAMETER Timezone
Specifies the system time zone by ID or name.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Set-IBMSVSystemProperty -Name Cluster_1.1.1.1

Updates the system name.

.EXAMPLE
PS> Set-IBMSVSystemProperty -NtpIp 192.168.1.10

Configures the NTP server.

.EXAMPLE
PS> Set-IBMSVSystemProperty -Time 040509142003

Sets the system time manually.

.EXAMPLE
PS> Set-IBMSVSystemProperty -EnhancedCallHome on -CensorCallHome on

Enables Enhanced Call Home and censors sensitive data.

.EXAMPLE
PS> Set-IBMSVSystemProperty -QuorumMode preferred -QuorumSite SiteA

Configures quorum mode and assigns a quorum site.

.INPUTS
None.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Only modified properties are sent to the backend.
- Some updates are applied in multiple steps to satisfy mutual exclusivity constraints.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chsystem

.LINK
https://www.ibm.com/docs/en/search/settimezone

.LINK
https://www.ibm.com/docs/en/search/setsystemtime
#>

function Set-IBMSVSystemProperty {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        [string]$Name,
        [int]$RCBufferSize,
        [string]$ConsoleIp,
        [int]$InvEmailInterval,
        [int]$GMMLinkTolerance,
        [int]$GMMaxHostDelay,
        [string]$NtpIp,
        [string]$IsnsIp,
        [int]$RelationshipBandwidthLimit,
        [string]$ChapSecret,
        [switch]$NoChapSecret,
        [ValidateSet("replication", "storage")][string]$Layer,
        [ValidateSet("on", "off")][string]$CachePrefetch,
        [string]$LocalFcPortMask,
        [string]$PartnerFcPortMask,
        [ValidateSet("standard", "hyperswap")][string]$Topology,
        [int]$VdiskProtectionTime,
        [ValidateSet("yes", "no")][string]$VdiskProtectionEnabled,
        [ValidateSet("on", "off")][string]$Odx,
        [ValidateSet("on", "off")][string]$EasyTierAcceleration,
        [int]$MaxReplicationDelay,
        [int]$PartnershipExclusionThreshold,
        [ValidateSet("on", "off")][string]$EnhancedCallHome,
        [ValidateSet("on", "off")][string]$CensorCallHome,
        [ValidateSet("on", "off")][string]$HostUnmap,
        [ValidateSet("on", "off")][string]$BackendUnmap,
        [ValidateSet("standard", "preferred", "winner")][string]$QuorumMode,
        [string]$QuorumSite,
        [ValidateSet("short", "long")][string]$QuorumLease,
        [ValidateSet("yes", "no")][string]$SnapshotPolicySuspended,
        [ValidateSet("on", "off")][string]$EasyTier,
        [ValidateSet("yes", "no")][string]$SnapshotPreserveParent,
        [int]$FlashcopyDefaultGrainSize,
        [ValidateSet("yes", "no")][string]$StorageInsightsControlAccess,
        [ValidateSet("on", "off")][string]$AutoDriveDownload,
        [string]$Time,
        [Parameter(HelpMessage = "Run Get-IBMSVTimezones to see available timezones.")][string]$Timezone,
        [string]$Cluster
    )

    process {
        # --- Parameter-level validation --
        $ExclusiveParam = @("RelationshipBandwidthLimit", "GMMaxHostDelay", "RCBufferSize", "LocalFcPortMask", "PartnerFcPortMask", "Odx", "MaxReplicationDelay")

        if ($ChapSecret -and $NoChapSecret) {
            throw (Resolve-Error -ErrorInput "CMMVC5713E Parameter -ChapSecret and -NoChapSecret are mutually exclusive." -Category InvalidArgument)
        }
        if ($Time -and $NtpIp) {
            throw (Resolve-Error -ErrorInput "CMMVC5713E Parameters -Time and -NtpIp are mutually exclusive." -Category InvalidArgument)
        }

        # --- Update System ---
        if ($PSCmdlet.ShouldProcess("System", "Modify")) {

            # --- Getting Info ---
            $data = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lssystem" -CmdArgs ("-gui")
            if ($data.err) {
                throw (Resolve-Error -ErrorInput $data -Category InvalidOperation)
            }

            # --- Probe logic ---
            $props = @{}
            $paramsMapping = @(
                @{ Key = 'Name'; Existing = $data.name }
                @{ Key = 'RCBufferSize'; Existing = [int]$data.rc_buffer_size }
                @{ Key = 'ConsoleIp'; Existing = if ($data.console_IP) { ($data.console_IP -split ':')[0] } else { '' } }
                @{ Key = 'InvEmailInterval'; Existing = [int]$data.inventory_mail_interval }
                @{ Key = 'GMMLinkTolerance'; Existing = [int]$data.gm_link_tolerance }
                @{ Key = 'GMMaxHostDelay'; Existing = [int]$data.gm_max_host_delay }
                @{ Key = 'NtpIp'; Existing = $data.cluster_ntp_IP_address }
                @{ Key = 'IsnsIp'; Existing = $data.cluster_isns_IP_address }
                @{ Key = 'RelationshipBandwidthLimit'; Existing = [int]$data.relationship_bandwidth_limit }
                @{ Key = 'Layer'; Existing = $data.layer }
                @{ Key = 'CachePrefetch'; Existing = $data.cache_prefetch }
                @{ Key = 'LocalFcPortMask'; Existing = $data.local_fc_port_mask }
                @{ Key = 'PartnerFcPortMask'; Existing = $data.partner_fc_port_mask }
                @{ Key = 'Topology'; Existing = $data.topology }
                @{ Key = 'VdiskProtectionTime'; Existing = [int]$data.vdisk_protection_time }
                @{ Key = 'VdiskProtectionEnabled'; Existing = $data.vdisk_protection_enabled }
                @{ Key = 'Odx'; Existing = $data.odx }
                @{ Key = 'EasyTierAcceleration'; Existing = $data.easy_tier_acceleration }
                @{ Key = 'MaxReplicationDelay'; Existing = [int]$data.max_replication_delay }
                @{ Key = 'PartnershipExclusionThreshold'; Existing = [int]$data.partnership_exclusion_threshold }
                @{ Key = 'EnhancedCallHome'; Existing = $data.enhanced_callhome }
                @{ Key = 'CensorCallHome'; Existing = $data.censor_callhome }
                @{ Key = 'HostUnmap'; Existing = $data.host_unmap }
                @{ Key = 'BackendUnmap'; Existing = $data.backend_unmap }
                @{ Key = 'QuorumMode'; Existing = $data.quorum_mode }
                @{ Key = 'QuorumSite'; Existing = $data.quorum_site_name }
                @{ Key = 'QuorumLease'; Existing = $data.quorum_lease }
                @{ Key = 'SnapshotPolicySuspended'; Existing = $data.snapshot_policy_suspended }
                @{ Key = 'EasyTier'; Existing = $data.easytier }
                @{ Key = 'SnapshotPreserveParent'; Existing = $data.snapshot_preserve_parent }
                @{ Key = 'FlashcopyDefaultGrainSize'; Existing = [int]$data.flashcopy_default_grainsize }
                @{ Key = 'StorageInsightsControlAccess'; Existing = $data.storage_insights_control_access }
                @{ Key = 'AutoDriveDownload'; Existing = $data.auto_drive_download }
                @{ Key = 'ChapSecret'; Existing = $data.iscsi_chap_secret }
                @{ Key = 'NoChapSecret'; Existing = -not [bool]$data.iscsi_chap_secret }
            )
            foreach ($item in $paramsMapping) {
                if ($PSBoundParameters.ContainsKey($item.Key)) {
                    $inputValue = Get-Variable -Name $item.Key -ValueOnly
                    if ($inputValue -and $inputValue -ne $item.Existing) {
                        if ($inputValue -is [System.Management.Automation.SwitchParameter]) { $inputValue = $true }
                        $props[$item.Key.ToLower()] = $inputValue
                    }
                }
            }

            $hasMode = $PSBoundParameters.ContainsKey('QuorumMode')
            $hasSite = $PSBoundParameters.ContainsKey('QuorumSite')
            $newIsStandard = ($QuorumMode -eq 'standard')
            $oldIsStandard = ($data.quorum_mode -eq 'standard')

            if ($hasMode -and $newIsStandard -and $hasSite) {
                throw (Resolve-Error -ErrorInput "Parameter -QuorumSite is not valid when quorum mode is 'standard'." -Category InvalidArgument)
            }
            if ($hasMode -and -not $newIsStandard -and -not $hasSite) {
                throw (Resolve-Error -ErrorInput "Parameter -QuorumSite is required when quorum mode is '$QuorumMode'." -Category InvalidArgument)
            }
            if ($hasSite -and -not $hasMode -and $oldIsStandard) {
                throw (Resolve-Error -ErrorInput "Parameter -QuorumSite is not valid when current quorum mode is 'standard'. Specify -QuorumMode." -Category InvalidArgument)
            }

            if ($Timezone) {
                $new = $Timezone
                if ($Timezone -notmatch '^\d+$') {
                    $timezones = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lstimezones"
                    if ($timezones -and $timezones.PSObject.Properties.Name -contains "err") {
                        throw (Resolve-Error -ErrorInput $timezones -Category InvalidOperation)
                    }
                    $obj = $null
                    $obj = $timezones | Where-Object { $_.timezone.ToLower() -eq $Timezone.ToLower() }
                    if ($null -eq $obj) {
                        throw (Resolve-Error -ErrorInput "Invalid timezone '$Timezone'. Run Get-IBMSVTimezones for valid values." -Category InvalidArgument)
                    }
                    $new = $obj.id
                }
                if ($new -ne $data.time_zone.split(' ')[0]) { $props["timezone"] = $new }
            }
            if ($Time) {
                if ($data.cluster_ntp_IP_address -ne "") { $props["ntpip"] = "0.0.0.0" }
                $props["time"] = $true
            }
            if ($props.Count -eq 0) { Write-IBMSVLog -Level INFO -Message "No changes required for system '$($data.name)'."; return }

            # --- Apply changes ---
            $singleProps = @{}

            foreach ($key in @($props.Keys)) {
                if ($ExclusiveParam -contains $key) {
                    $singleProps[$key.ToLower()] = $props[$key]
                    $props.Remove($key) | Out-Null
                }
            }

            if ($props.ContainsKey('timezone')) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "settimezone" -CmdOpts @{ 'timezone' = $props["timezone"] }
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                $props.remove('timezone')
            }

            $updateTime = $false
            if ($props.ContainsKey('time')) {
                $updateTime = $true
                $props.remove('time')
            }

            if ($props.Count -gt 0) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chsystem" -CmdOpts $props
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
            }

            foreach ($key in $singleProps.Keys) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chsystem" -CmdOpts @{ $key = $singleProps[$key] }
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
            }

            if ($updateTime) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "setsystemtime" -CmdOpts @{ 'time' = $Time }
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
            }

            Write-IBMSVLog -Level INFO -Message "System '$($data.name)' configuration updated successfully."
        }
    }
}
