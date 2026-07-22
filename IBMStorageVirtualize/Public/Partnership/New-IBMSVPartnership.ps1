<#
.SYNOPSIS
Creates a new partnership between IBM Storage Virtualize systems.

.DESCRIPTION
The New-IBMSVPartnership cmdlet creates a partnership (FC or IP) between IBM Storage Virtualize systems.

FC Partnership behavior:
- RemoteSystem only: Creates FC partnership on local cluster only
- RemoteCluster only: Creates partnership on both clusters (requires lssystem calls on both)
- RemoteSystem + RemoteCluster: Creates on both clusters (requires lssystem call on local only)

IP Partnership behavior:
- ClusterIP only: Creates IP partnership on local cluster only
- ClusterIP + RemoteCluster: Creates partnership on both clusters

.PARAMETER Type
Specifies the type of partnership to create.
Valid values: FC, IP.
Required parameter that determines whether to create an FC or IP partnership.

.PARAMETER RemoteSystem
Specifies the remote system name or ID for FC partnership.
When specified alone, creates partnership on local cluster only.
When specified with RemoteCluster, creates on both clusters.
Optional for FC partnerships when RemoteCluster is specified.

.PARAMETER ClusterIP
Specifies the IP address of the remote cluster for IP partnership.

.PARAMETER RemoteCluster
Specifies the remote cluster to create the partnership with.
When specified, creates partnership on both clusters.

.PARAMETER LinkBandwidthMbits
Specifies the bandwidth limit for the partnership link in Mbps.
Required parameter for both FC and IP partnerships.

.PARAMETER BackgroundCopyRate
Valid for both FC and IP partnerships.

.PARAMETER ChapSecret
Specifies the CHAP secret for IP partnership authentication.
Only valid for IP partnerships.

.PARAMETER Link1
Specifies the first link IP address for IP partnership.
Only valid for IP partnerships. At least one of Link1 or Link2 must be specified for IP partnerships.

.PARAMETER Link2
Specifies the second link IP address for IP partnership.
Only valid for IP partnerships. At least one of Link1 or Link2 must be specified for IP partnerships.

.PARAMETER RemoteLink1
Specifies the first remote link IP address for IP partnership.
Only valid for IP partnerships when RemoteCluster is specified.
At least one of RemoteLink1 or RemoteLink2 must be specified when creating bidirectional IP partnerships.

.PARAMETER RemoteLink2
Specifies the second remote link IP address for IP partnership.
Only valid for IP partnerships when RemoteCluster is specified.
At least one of RemoteLink1 or RemoteLink2 must be specified when creating bidirectional IP partnerships.

.PARAMETER Compressed
Specifies whether compression is enabled for IP partnership.
Valid values: yes, no.
Only valid for IP partnerships.

.PARAMETER Secured
Specifies whether the IP partnership should use secured communication.
Valid values: yes, no.
Only valid for IP partnerships.

.PARAMETER Cluster
Specifies the local FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> New-IBMSVPartnership -Type FC -RemoteSystem "0000020321E04D5A" -LinkBandwidthMbits 1000
Creates an FC partnership on local cluster only.

.EXAMPLE
PS> New-IBMSVPartnership -Type FC -RemoteCluster "1.1.1.2" -LinkBandwidthMbits 1000
Creates an FC partnership on both clusters.

.EXAMPLE
PS> New-IBMSVPartnership -Type FC -RemoteSystem "0000020321E04D5A" -RemoteCluster "10.10.10.20" -LinkBandwidthMbits 1000
Creates an FC partnership on both clusters.

.EXAMPLE
PS> New-IBMSVPartnership -Type IP -ClusterIP "192.168.1.100" -Link1 "portset0" -RemoteLink1 "portset1" -LinkBandwidthMbits 1000
Creates an IP partnership on local cluster only.

.EXAMPLE
PS> New-IBMSVPartnership -Type IP -RemoteCluster "10.10.10.20" -Link1 "portset0" -RemoteLink1 "portset1" -LinkBandwidthMbits 1000
Creates an IP partnership between 2 clusters.

.EXAMPLE
PS> New-IBMSVPartnership -Type IP -RemoteCluster "10.10.10.20" -Link1 "portset0" -Link2 "portset1" -RemoteLink1 "portset2" -RemoteLink2 "portset3" -Compressed yes -Secured yes -LinkBandwidthMbits 2000
Creates a secured and compressed IP partnership with two links on both clusters.

.EXAMPLE
PS> New-IBMSVPartnership -Type FC -RemoteCluster "10.10.10.20" -LinkBandwidthMbits 1000 -BackgroundCopyRate 100
Creates an FC partnership on both clusters with custom bandwidth and copy rate settings.

.INPUTS
None.

.OUTPUTS
System.Object
Returns an array containing the parynership objects from both the local and remote
clusters (one entry each). If a parynership already existed on a cluster, the
existing object is returned for that cluster instead.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkfcpartnership

.LINK
https://www.ibm.com/docs/en/search/mkippartnership
#>

function New-IBMSVPartnership {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("FC", "IP")]
        [string]$Type,

        [string]$RemoteSystem,

        [string]$ClusterIP,

        [Parameter(Mandatory = $true)]
        [int]$LinkBandwidthMbits,

        [int]$BackgroundCopyRate,

        [string]$ChapSecret,

        [string]$Link1,

        [string]$Link2,

        [string]$RemoteLink1,

        [string]$RemoteLink2,

        [ValidateSet("yes", "no")]
        [string]$Compressed,

        [ValidateSet("yes", "no")]
        [string]$Secured,

        [string]$Cluster,

        [string]$RemoteCluster
    )

    process {
        if (-not $PSBoundParameters.ContainsKey('Cluster')) {
            $Cluster = $Script:primarysession
        }

        if ($RemoteSystem -and $ClusterIP) {
            throw (Resolve-Error -ErrorInput "-RemoteSystem and -ClusterIP are mutually exclusive. Use -RemoteSystem for FC partnerships or -ClusterIP for IP partnerships." -Category InvalidArgument)
        }

        # --- Create FC Partnership ---
        if ($Type -eq 'FC') {
            $IPPartnershipParams = @('ClusterIP', 'ChapSecret', 'Compressed', 'Link1', 'Link2', 'RemoteLink1', 'RemoteLink2', 'Secured')
            $invalidParams = $IPPartnershipParams | Where-Object { $PSBoundParameters.ContainsKey($_) }
            if ($invalidParams) {
                $invalidParams = $invalidParams | ForEach-Object { "-$_" }
                throw (Resolve-Error -ErrorInput "Parameter(s) $($invalidParams -join ', ') are not applicable for FC partnerships." -Category InvalidArgument)
            }

            $clustersToCreate = @()
            if (-not $RemoteCluster) {
                if (-not $RemoteSystem) {
                    throw (Resolve-Error -ErrorInput "-RemoteSystem is required when -RemoteCluster is not specified for FC partnerships." -Category InvalidArgument)
                }
                $clustersToCreate = @(
                    [pscustomobject]@{
                        Primary     = $Cluster
                        Remote      = $RemoteSystem
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
                $clustersToCreate = @(
                    [pscustomobject]@{
                        Primary     = $Cluster
                        Remote      = $RemoteSystem
                        Description = "Local system"
                    },
                    [pscustomobject]@{
                        Primary     = $RemoteCluster
                        Remote      = $localSystemData.id
                        Description = "Remote system"
                    }
                )
            }

            $final = @()
            $needsRefresh = $null

            foreach ($target in $clustersToCreate) {
                if ($PSCmdlet.ShouldProcess("Cluster '$($target.Primary)'", "Create FC partnership with '$($target.Remote)'")) {

                    $existingPartnership = Invoke-IBMSVRestRequest -Cluster $target.Primary -Cmd "lspartnership" -CmdArgs $target.Remote
                    if ($existingPartnership -and $existingPartnership.PSObject.Properties.Name -contains "err") {
                        throw (Resolve-Error -ErrorInput $existingPartnership -Category InvalidOperation)
                    }

                    if ($existingPartnership) {
                        Write-IBMSVLog -Level INFO -Message "FC partnership with system '$($target.Remote)' already exists on $($target.Description) and in '$($existingPartnership.partnership)' state."

                        if ($existingPartnership.partnership -notlike "fully_configured" -and $clustersToCreate.Count -eq 2) {
                            Write-IBMSVLog -Level DEBUG -Message "FC partnership with system '$($target.Remote)' on $($target.Description) is '$($existingPartnership.partnership)'. Will refresh after remote creation."
                            $needsRefresh = [pscustomobject]@{
                                Cluster      = $target.Primary
                                RemoteSystem = $target.Remote
                            }
                        }
                        else {
                            $final += $existingPartnership
                        }
                        continue
                    }

                    $opts = @{ linkbandwidthmbits = $LinkBandwidthMbits }
                    if ($PSBoundParameters.ContainsKey('BackgroundCopyRate')) {
                        $opts['backgroundcopyrate'] = $BackgroundCopyRate
                    }

                    $result = Invoke-IBMSVRestRequest -Cluster $target.Primary -Cmd "mkfcpartnership" -CmdOpts $opts -CmdArgs $target.Remote
                    if ($result -and $result.PSObject.Properties.Name -contains "err") {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }

                    $newPartnership = Invoke-IBMSVRestRequest -Cluster $target.Primary -Cmd "lspartnership" -CmdArgs $target.Remote
                    if ($newPartnership -and $newPartnership.PSObject.Properties.Name -contains "err") {
                        throw (Resolve-Error -ErrorInput $newPartnership -Category InvalidOperation)
                    }

                    Write-IBMSVLog -Level INFO -Message "FC partnership with system '$($target.Remote)' created on $($target.Description) and in '$($newPartnership.partnership)' state."

                    if ($newPartnership) {
                        if ($newPartnership.partnership -notlike "fully_configured" -and $clustersToCreate.Count -eq 2) {
                            Write-IBMSVLog -Level DEBUG -Message "FC partnership with system '$($target.Remote)' on $($target.Description) is '$($existingPartnership.partnership)'. Will refresh after remote creation."
                            $needsRefresh = [pscustomobject]@{
                                Cluster      = $target.Primary
                                RemoteSystem = $target.Remote
                            }
                        }
                        else {
                            $final += $newPartnership
                        }
                    }
                }
            }

            if ($null -ne $needsRefresh) {
                $refreshed = Invoke-IBMSVRestRequest -Cluster $needsRefresh.Cluster -Cmd "lspartnership" -CmdArgs $needsRefresh.RemoteSystem
                if ($refreshed -and $refreshed.PSObject.Properties.Name -contains "err") {
                    throw (Resolve-Error -ErrorInput $refreshed -Category InvalidOperation)
                }
                $final += $refreshed
            }

            if ($final.Count -eq 2 -and $final[0].console_ip.Split(':')[0] -eq $Cluster) {
                $final = @($final[1], $final[0])
            }
            return $final
        }

        # --- Create IP Partnership ---
        if ($Type -eq 'IP') {
            if (-not $ClusterIP) {
                if (-not $RemoteCluster) {
                    throw (Resolve-Error -ErrorInput "-ClusterIP is required when -RemoteCluster is not specified for IP partnerships." -Category InvalidArgument)
                }
                $ClusterIP = $RemoteCluster
            }
            if (-not $Link1 -and -not $Link2) {
                throw (Resolve-Error -ErrorInput "At least one of Link1 or Link2 must be specified for IP partnerships." -Category InvalidArgument)
            }
            if ($RemoteLink1 -or $RemoteLink2) {
                if (-not $RemoteCluster) {
                    throw (Resolve-Error -ErrorInput "-RemoteCluster is required when -RemoteLink1 or -RemoteLink2 is specified." -Category InvalidArgument)
                }
            }
            else {
                $RemoteLink1 = $Link1
                $RemoteLink2 = $Link2
            }
            if ($PSBoundParameters.ContainsKey('RemoteLink1') -and -not $PSBoundParameters.ContainsKey('Link1')) {
                throw (Resolve-Error -ErrorInput "-RemoteLink1 can only be specified when -Link1 is specified." -Category InvalidArgument)
            }

            if ($PSBoundParameters.ContainsKey('RemoteLink2') -and -not $PSBoundParameters.ContainsKey('Link2')) {
                throw (Resolve-Error -ErrorInput "-RemoteLink2 can only be specified when -Link2 is specified." -Category InvalidArgument)
            }

            if ($RemoteCluster) {
                $clustersToCreate = @(
                    [pscustomobject]@{
                        Primary     = $Cluster
                        Remote      = $ClusterIP
                        Description = "Local system"
                    },
                    [pscustomobject]@{
                        Primary     = $ClusterIP
                        Remote      = $Cluster
                        Description = "Remote system"
                    }
                )
            }
            else {
                $clustersToCreate = @(
                    [pscustomobject]@{
                        Primary     = $Cluster
                        Remote      = $ClusterIP
                        Description = "Local system"
                    }
                )
            }

            $final = @()
            $needsRefresh = $null

            foreach ($target in $clustersToCreate) {
                if ($PSCmdlet.ShouldProcess("Cluster '$($target.Primary)'", "Create IP partnership with '$($target.Remote)'")) {

                    $partnerships = Invoke-IBMSVRestRequest -Cluster $target.Primary -Cmd "lspartnership"
                    if ($partnerships -and $partnerships.PSObject.Properties.Name -contains "err") {
                        throw (Resolve-Error -ErrorInput $partnerships -Category InvalidOperation)
                    }

                    $existingPartnership = $partnerships | Where-Object { $_.cluster_ip -eq $target.Remote }

                    if ($existingPartnership) {
                        Write-IBMSVLog -Level INFO -Message "IP partnership with cluster IP '$($target.Remote)' already exists on $($target.Description) and in '$($existingPartnership.partnership)' state."

                        if ($existingPartnership.partnership -notlike "fully_configured" -and $clustersToCreate.Count -eq 2) {
                            Write-IBMSVLog -Level DEBUG -Message "IP partnership with system '$($target.Remote)' on $($target.Description) is '$($existingPartnership.partnership)'. Will refresh after remote creation."
                            $needsRefresh = [pscustomobject]@{
                                Cluster      = $target.Primary
                                RemoteSystem = $existingPartnership.id
                            }
                        }
                        else {
                            $partnershipData = Invoke-IBMSVRestRequest -Cluster $target.Primary -Cmd "lspartnership" -CmdArgs $existingPartnership.id
                            if ($partnershipData -and $partnershipData.PSObject.Properties.Name -contains "err") {
                                throw (Resolve-Error -ErrorInput $partnershipData -Category InvalidOperation)
                            }
                            $final += $partnershipData
                        }
                        continue
                    }

                    $opts = @{
                        clusterip          = $target.Remote
                        linkbandwidthmbits = $LinkBandwidthMbits
                    }
                    if ($target.Primary -eq $ClusterIP) {
                        if ($RemoteLink1) { $opts["link1"] = $RemoteLink1 }
                        if ($RemoteLink2) { $opts["link2"] = $RemoteLink2 }
                    }
                    elseif ($target.Primary -eq $Cluster) {
                        if ($Link1) { $opts["link1"] = $Link1 }
                        if ($Link2) { $opts["link2"] = $Link2 }
                    }
                    foreach ($field in @('BackgroundCopyRate', 'ChapSecret', 'Compressed', 'Secured')) {
                        if ($PSBoundParameters.ContainsKey($field)) {
                            $value = $PSBoundParameters[$field]
                            if ($null -ne $value -and $value -ne '') {
                                if ($value -is [System.Management.Automation.SwitchParameter]) {
                                    $opts[$field.ToLower()] = $value.IsPresent
                                }
                                else {
                                    $opts[$field.ToLower()] = $value
                                }
                            }
                        }
                    }

                    $result = Invoke-IBMSVRestRequest -Cluster $target.Primary -Cmd "mkippartnership" -CmdOpts $opts
                    if ($result -and $result.PSObject.Properties.Name -contains "err") {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }

                    $allPartnerships = Invoke-IBMSVRestRequest -Cluster $target.Primary -Cmd "lspartnership"
                    if ($allPartnerships -and $allPartnerships.PSObject.Properties.Name -contains "err") {
                        throw (Resolve-Error -ErrorInput $allPartnerships -Category InvalidOperation)
                    }

                    $newPartnership = $allPartnerships | Where-Object { $_.cluster_ip -eq $target.Remote }

                    Write-IBMSVLog -Level INFO -Message "IP partnership with cluster IP '$($target.Remote)' created on $($target.Description) and in '$($newPartnership.partnership)' state."

                    if ($newPartnership) {
                        if ($newPartnership.partnership -notlike "fully_configured" -and $clustersToCreate.Count -eq 2) {
                            Write-IBMSVLog -Level INFO -Message "IP partnership with cluster IP '$($target.Remote)' on $($target.Description) is '$($existingPartnership.partnership)'. Will refresh after remote creation."
                            $needsRefresh = [pscustomobject]@{
                                Cluster      = $target.Primary
                                RemoteSystem = $newPartnership.id
                            }
                        }
                        else {
                            $partnershipData = Invoke-IBMSVRestRequest -Cluster $target.Primary -Cmd "lspartnership" -CmdArgs $newPartnership.id
                            if ($partnershipData -and $partnershipData.PSObject.Properties.Name -contains "err") {
                                throw (Resolve-Error -ErrorInput $partnershipData -Category InvalidOperation)
                            }
                            $final += $partnershipData
                        }
                    }
                }
            }

            if ($null -ne $needsRefresh) {
                $refreshed = Invoke-IBMSVRestRequest -Cluster $needsRefresh.Cluster -Cmd "lspartnership" -CmdArgs $needsRefresh.RemoteSystem
                if ($refreshed -and $refreshed.PSObject.Properties.Name -contains "err") {
                    throw (Resolve-Error -ErrorInput $refreshed -Category InvalidOperation)
                }
                $final += $refreshed
            }

            if ($final.Count -eq 2 -and $final[0].console_ip.Split(':')[0] -eq $Cluster) {
                $final = @($final[1], $final[0])
            }
            return $final
        }
    }
}
