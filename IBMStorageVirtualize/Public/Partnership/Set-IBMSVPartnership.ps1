
<#
.SYNOPSIS
Modifies an existing partnership on an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVPartnership cmdlet updates properties of an existing partnership (FC or IP).

Parameter behavior:
- RemoteSystem only: Updates partnership on local cluster only
- RemoteCluster only: Updates partnership on both clusters (lssystem call on remote)
- Both RemoteSystem and RemoteCluster: Updates on both clusters (no extra lssystem call)

Special handling:
Some parameters (clusterip, chapsecret, compressed, link1, link2, nolink1, nolink2, nochapsecret) require the partnership to be stopped before modification.
The module automatically stops the partnership if required, applies the changes, and restores it to its previous state.

.PARAMETER RemoteSystem
Specifies the system ID of the remote system in the partnership.
When specified alone, updates the partnership on the local cluster only.
When specified with RemoteCluster, updates on both clusters without requiring an lssystem call.

.PARAMETER RemoteCluster
Specifies the remote cluster to update the partnership on.
When specified alone, updates the partnership on both clusters (requires lssystem call to get remote system ID).
When specified with RemoteSystem, updates on both clusters in an optimized manner.

.PARAMETER Start
Starts the partnership if it is currently stopped.
Mutually exclusive with -Stop.

.PARAMETER Stop
Stops the partnership if it is currently running.
Mutually exclusive with -Start.

.PARAMETER ClusterIP
Specifies the new partner system IP address, which can be IPv4, IPv6 or FQDNs.
Only valid for IP partnerships. Requires the partnership to be stopped before modification.

.PARAMETER ChapSecret
Specifies the CHAP secret for IP partnership authentication.
Only valid for IP partnerships. Requires the partnership to be stopped before modification.
Mutually exclusive with -NoChapSecret.

.PARAMETER NoChapSecret
Removes the CHAP secret from the IP partnership.
Only valid for IP partnerships. Requires the partnership to be stopped before modification.
Mutually exclusive with -ChapSecret.

.PARAMETER BackgroundCopyRate
Specifies the background copy rate.
Valid for both FC and IP partnerships.

.PARAMETER LinkBandwidthMbits
Specifies the bandwidth limit for the partnership link in Mbps.
Valid for both FC and IP partnerships.

.PARAMETER Compressed
Specifies whether compression is enabled for IP partnership.
Valid values: yes, no.
Only valid for IP partnerships. Requires the partnership to be stopped before modification.

.PARAMETER Link1
Specifies the first link IP address for IP partnership.
Only valid for IP partnerships.
Mutually exclusive with -NoLink1.

.PARAMETER Link2
Specifies the second link IP address for IP partnership.
Only valid for IP partnerships.
Mutually exclusive with -NoLink2.

.PARAMETER NoLink1
Removes the first link from the IP partnership.
Only valid for IP partnerships.
Mutually exclusive with -Link1.

.PARAMETER NoLink2
Removes the second link from the IP partnership.
Only valid for IP partnerships.
Mutually exclusive with -Link2.

.PARAMETER Secured
Specifies whether the IP partnership uses secured communication.
Valid values: yes, no.
Only valid for IP partnerships.

.PARAMETER PBRinUse
Specifies whether Policy-Based Replication is in use.
Valid values: yes, no.
Valid for both FC and IP partnerships.

.PARAMETER Cluster
Specifies the local FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -LinkBandwidthMbits 2000
Updates the bandwidth limit for an FC partnership on the local cluster.

.EXAMPLE
PS> Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -RemoteCluster "10.10.10.20" -BackgroundCopyRate 100
Updates the background copy rate on both clusters.

.EXAMPLE
PS> Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -Stop
Stops the partnership.

.EXAMPLE
PS> Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -Start
Starts the partnership.

.EXAMPLE
PS> Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -ChapSecret "newpassword"
Updates the CHAP secret for an IP partnership.
The partnership is automatically stopped, modified, and restarted.

.EXAMPLE
PS> Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -NoChapSecret
Removes the CHAP secret from an IP partnership.

.EXAMPLE
PS> Set-IBMSVPartnership -RemoteCluster "10.10.10.20" -LinkBandwidthMbits 3000 -BackgroundCopyRate 120
Updates multiple properties on both clusters.

.EXAMPLE
PS> Set-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -PBRinUse yes
Enables Policy-Based Replication for the partnership.

.INPUTS
System.String
You can pipe objects with RemoteSystem properties to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- IP-specific parameters (ClusterIP, ChapSecret, Compressed, Link1, Link2, Secured) are only valid for IP partnerships.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chpartnership
#>

function Set-IBMSVPartnership {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$RemoteSystem,

        [string]$RemoteCluster,

        [switch]$Start,

        [switch]$Stop,

        [string]$ClusterIP,

        [string]$ChapSecret,

        [switch]$NoChapSecret,

        [int]$BackgroundCopyRate,

        [int]$LinkBandwidthMbits,

        [ValidateSet("yes", "no")]
        [string]$Compressed,

        [string]$Link1,

        [string]$Link2,

        [switch]$NoLink1,

        [switch]$NoLink2,

        [ValidateSet("yes", "no")]
        [string]$Secured,

        [ValidateSet("yes", "no")]
        [string]$PBRinUse,

        [string]$Cluster
    )

    process {
        if (-not $PSBoundParameters.ContainsKey('Cluster')) {
            $Cluster = $Script:primarysession
        }

        # --- Parameter-level validation ---
        $IPPartnershipParams = @('ClusterIP', 'ChapSecret', 'NoChapSecret', 'Compressed', 'Link1', 'Link2', 'NoLink1', 'NoLink2', 'Secured')
        $validationMutexRules = @{
            mutex1 = @('Start', 'Stop')
            mutex2 = @('ChapSecret', 'NoChapSecret')
            mutex3 = @('Link1', 'NoLink1')
            mutex4 = @('Link2', 'NoLink2')
            mutex5 = @('NoLink1', 'NoLink2')
            mutex6 = @('Link1', 'Stop')
            mutex7 = @('Link2', 'Stop')
            mutex8 = @('Link1', 'start')
            mutex9 = @('Link2', 'start')
        }
        foreach ($rule in $validationMutexRules.Values) {
            $present = $rule | Where-Object { $PSBoundParameters.ContainsKey($_) }
            if ($present.Count -gt 1) {
                throw (Resolve-Error -ErrorInput "Parameters $($present -join ', ') are mutually exclusive." -Category InvalidArgument)
            }
        }
        $clustersToUpdate = @()

        if (-not $RemoteCluster) {
            if (-not $RemoteSystem) {
                throw (Resolve-Error -ErrorInput "At least one of -RemoteSystem or -RemoteCluster must be specified." -Category InvalidArgument)
            }

            $primaryData = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lspartnership" -CmdArgs $RemoteSystem
            if ($primaryData -and $primaryData.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $primaryData -Category InvalidOperation)
            }
            if (-not $primaryData) {
                throw (Resolve-Error -ErrorInput "Partnership with system '$RemoteSystem' does not exist on local system." -Category ObjectNotFound)
            }

            $invalidParams = $IPPartnershipParams | Where-Object { $PSBoundParameters.ContainsKey($_) }
            if ($primaryData.type -eq 'fc' -and $invalidParams) {
                $invalidParams = $invalidParams | ForEach-Object { "-$_" }
                throw (Resolve-Error -ErrorInput "Parameter(s) $($invalidParams -join ', ') are not applicable for FC partnerships." -Category InvalidArgument)
            }

            $clustersToUpdate = @(
                [pscustomobject]@{
                    Cluster     = $Cluster
                    Data        = $primaryData
                    Description = "Local system"
                }
            )
        }
        else {
            if (-not $RemoteSystem) {
                $remoteSystemData = Invoke-IBMSVRestRequest -Cluster $RemoteCluster -Cmd "lssystem"
                if ($remoteSystemData -and $remoteSystemData.PSObject.Properties.Name -contains "err") {
                    throw (Resolve-Error -ErrorInput $remoteSystemData -Category InvalidOperation)
                }
                $RemoteSystem = $remoteSystemData.id
            }

            $localSystemData = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lssystem"
            if ($localSystemData -and $localSystemData.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $localSystemData -Category InvalidOperation)
            }

            $primaryData = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lspartnership" -CmdArgs $RemoteSystem
            if ($primaryData -and $primaryData.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $primaryData -Category InvalidOperation)
            }
            if (-not $primaryData) {
                throw (Resolve-Error -ErrorInput "Partnership with system '$RemoteSystem' does not exist on local system." -Category ObjectNotFound)
            }
            $invalidParams = $IPPartnershipParams | Where-Object { $PSBoundParameters.ContainsKey($_) }
            if ($primaryData.type -eq 'fc' -and $invalidParams) {
                $invalidParams = $invalidParams | ForEach-Object { "-$_" }
                throw (Resolve-Error -ErrorInput "Parameter(s) $($invalidParams -join ', ') are not applicable for FC partnerships." -Category InvalidArgument)
            }

            $secondaryData = Invoke-IBMSVRestRequest -Cluster $RemoteCluster -Cmd "lspartnership" -CmdArgs $localSystemData.id
            if ($secondaryData -and $secondaryData.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $secondaryData -Category InvalidOperation)
            }
            if (-not $secondaryData) {
                throw (Resolve-Error -ErrorInput "Partnership with system '$($localSystemData.id)' does not exist on remote system." -Category ObjectNotFound)
            }

            $clustersToUpdate = @(
                [pscustomobject]@{
                    Cluster     = $Cluster
                    Data        = $primaryData
                    Description = "Local system"
                },
                [pscustomobject]@{
                    Cluster     = $RemoteCluster
                    Data        = $secondaryData
                    Description = "Remote system"
                }
            )
        }

        foreach ($target in $clustersToUpdate) {

            if ($PSCmdlet.ShouldProcess("Partnership with system '$($target.Data.id)' on $($target.Description)", "Modify")) {

                $props = @{}
                $data = $target.Data

                # --- Probe logic ---
                $paramsMapping = @(
                    @{ Key = 'ClusterIP'; Existing = $data.cluster_ip }
                    @{ Key = 'ChapSecret'; Existing = $data.chap_secret }
                    @{ Key = 'NoChapSecret'; Existing = -not [bool]$data.chap_secret }
                    @{ Key = 'BackgroundCopyRate'; Existing = [int]$data.background_copy_rate }
                    @{ Key = 'LinkBandwidthMbits'; Existing = [int]$data.link_bandwidth_mbits }
                    @{ Key = 'Compressed'; Existing = $data.compressed }
                    @{ Key = 'Link1'; Existing = $data.link1 }
                    @{ Key = 'NoLink1'; Existing = -not [bool]$data.link1 }
                    @{ Key = 'Link2'; Existing = $data.link2 }
                    @{ Key = 'NoLink2'; Existing = -not [bool]$data.link2 }
                    @{ Key = 'Secured'; Existing = $data.secured }
                    @{ Key = 'PBRinUse'; Existing = $data.pbr_in_use }
                )
                foreach ($item in $paramsMapping) {
                    if ($PSBoundParameters.ContainsKey($item.Key)) {
                        $inputValue = Get-Variable -Name $item.Key -ValueOnly
                        if ($inputValue -is [System.Management.Automation.SwitchParameter]) {
                            $inputValue = $true
                        }

                        if ($inputValue -ne $item.Existing) {
                            $props[$item.Key.ToLower()] = $inputValue
                        }
                    }
                }

                if ($PSBoundParameters.ContainsKey('Start') -and $data.partnership -in @("fully_configured_stopped", "partially_configured_local_stopped")) {
                    $props['start'] = $true
                }

                if ($PSBoundParameters.ContainsKey('Stop') -and $data.partnership -in @("fully_configured", "partially_configured_local")) {
                    $props['stop'] = $true
                }

                if ($props.Count -eq 0) {
                    Write-IBMSVLog -Level INFO -Message "No changes required for partnership with system '$($data.id)' on $($target.Description)."
                }
                else {
                    # --- Apply changes ---
                    $requiresStop = $props.Keys | Where-Object { @('clusterip', 'chapsecret', 'compressed', 'link1', 'link2', 'nolink1', 'nolink2', 'nochapsecret') -contains $_ } | Select-Object -First 1

                    $preStop = $false
                    $postStart = $false

                    if ($requiresStop) {
                        if ($data.partnership -in @('fully_configured', 'partially_configured_local')) {
                            $preStop = $true

                            if (-not $PSBoundParameters.ContainsKey('Stop')) {
                                $postStart = $true
                            }
                        }
                        elseif ($PSBoundParameters.ContainsKey('Start')) {
                            $postStart = $true
                        }
                        $props.Remove('stop')
                        $props.Remove('start')
                    }

                    if ($preStop) {
                        $result = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "chpartnership" -CmdOpts @{ stop = $true } -CmdArgs $data.id
                        if ($result.err) {
                            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                        }

                        Write-IBMSVLog -Level DEBUG -Message "Partnership with system '$($data.id)' stopped on $($target.Description)."
                    }

                    $isUpdated = $false
                    $opts = @{}
                    if ($props.ContainsKey('linkbandwidthmbits')) {
                        $opts['linkbandwidthmbits'] = $LinkBandwidthMbits
                        $props.Remove('linkbandwidthmbits')
                    }
                    if ($props.ContainsKey('backgroundcopyrate')) {
                        $opts['backgroundcopyrate'] = $BackgroundCopyRate
                        $props.Remove('backgroundcopyrate')
                    }
                    if ($opts.Count -gt 0) {
                        $result = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "chpartnership" -CmdOpts $opts -CmdArgs $data.id
                        if ($result -and $result.PSObject.Properties.Name -contains "err") {
                            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                        }
                        $isUpdated = $true
                    }
                    if ($props.ContainsKey('pbrinuse')) {
                        $pbrResult = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "chpartnership" -CmdOpts @{ pbrinuse = $PBRinUse } -CmdArgs $data.id
                        if ($pbrResult -and $pbrResult.PSObject.Properties.Name -contains "err") {
                            throw (Resolve-Error -ErrorInput $pbrResult -Category InvalidOperation)
                        }
                        $props.Remove('pbrinuse')
                    }
                    if ($props.ContainsKey('stop') -and -not $requiresStop) {
                        $result = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "chpartnership" -CmdOpts @{ stop = $true } -CmdArgs $data.id
                        if ($result.err) {
                            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                        }
                        $props.Remove('stop')
                        Write-IBMSVLog -Level INFO -Message "Partnership with system '$($data.id)' stopped on $($target.Description)."
                    }
                    if ($props.ContainsKey('start') -and -not $requiresStop) {
                        $result = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "chpartnership" -CmdOpts @{ start = $true } -CmdArgs $data.id
                        if ($result.err) {
                            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                        }
                        $props.Remove('start')
                        Write-IBMSVLog -Level INFO -Message "Partnership with system '$($data.id)' started on $($target.Description)."
                    }

                    if ($props.Count -gt 0) {
                        $result = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "chpartnership" -CmdOpts $props -CmdArgs $data.id
                        if ($result -and $result.PSObject.Properties.Name -contains "err") {
                            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                        }
                        $isUpdated = $true
                    }

                    if ($isUpdated) {
                        Write-IBMSVLog -Level INFO -Message "Partnership with system '$($data.id)' updated on $($target.Description)."
                    }

                    if ($postStart) {
                        $result = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "chpartnership" -CmdOpts @{ start = $true } -CmdArgs $data.id
                        if ($result.err) {
                            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                        }

                        Write-IBMSVLog -Level DEBUG -Message "Partnership with system '$($data.id)' started on $($target.Description)."
                    }
                }
            }
        }
    }
}
