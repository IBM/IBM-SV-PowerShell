<#
.SYNOPSIS
Removes an existing partnership from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVPartnership cmdlet deletes a partnership from the system.

Parameter behavior:
- RemoteSystem only: Removes partnership from local cluster only
- RemoteCluster only: Removes partnership from both clusters (lsystem call on remote)
- Both RemoteSystem and RemoteCluster: Removes from both clusters (no extra lsystem call)

.PARAMETER RemoteSystem
Specifies the system ID of the remote system in the partnership.
When specified alone, removes the partnership from the local cluster only.
When specified with RemoteCluster, removes from both clusters without requiring an lsystem call.

.PARAMETER RemoteCluster
Specifies the remote cluster to remove the partnership from.
When specified alone, removes the partnership from both clusters (requires lsystem call to get remote system ID).
When specified with RemoteSystem, removes from both clusters in an optimized manner.

.PARAMETER Cluster
Specifies the local FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> Remove-IBMSVPartnership -RemoteSystem "0000020321E04D5A"
Removes the partnership from the local cluster only.

.EXAMPLE
PS> Remove-IBMSVPartnership -RemoteCluster "10.10.10.20"
Removes the partnership from both the local and remote clusters.

.EXAMPLE
PS> Remove-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -RemoteCluster "10.10.10.20"
Removes the partnership from both clusters in an optimized manner.
No additional lssystem call is needed since RemoteSystem is provided.

.EXAMPLE
PS> Remove-IBMSVPartnership -RemoteSystem "0000020321E04D5A" -Cluster "10.10.10.10" -WhatIf
Shows what would happen if the partnership were removed from the local cluster.

.INPUTS
System.String
You can pipe objects with RemoteSystem properties to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- This is a destructive operation and cannot be undone.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/rmpartnership
#>

function Remove-IBMSVPartnership {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$RemoteSystem,

        [string]$RemoteCluster,

        [string]$Cluster
    )

    process {
        if (-not $PSBoundParameters.ContainsKey('Cluster')) {
            $Cluster = $Script:primarysession
        }

        $clustersToUpdate = @()

        if (-not $RemoteCluster) {
            if (-not $RemoteSystem) {
                throw (Resolve-Error -ErrorInput "-RemoteSystem is required when -RemoteCluster is not specified." -Category InvalidArgument)
            }

            $clustersToUpdate = @(
                [pscustomobject]@{
                    Cluster      = $Cluster
                    RemoteSystem = $RemoteSystem
                    Description  = "Local system"
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

            $clustersToUpdate = @(
                [pscustomobject]@{
                    Cluster      = $Cluster
                    RemoteSystem = $RemoteSystem
                    Description  = "Local system"
                },
                [pscustomobject]@{
                    Cluster      = $RemoteCluster
                    RemoteSystem = $localSystemData.id
                    Description  = "Remote system"
                }
            )
        }

        # --- Remove Partnership ---
        foreach ($target in $clustersToUpdate) {

            if ($PSCmdlet.ShouldProcess("Partnership with system '$($target.RemoteSystem)' on $($target.Description)", "Remove")) {

                # --- Existence check ---
                $existing = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "lspartnership" -CmdArgs $target.RemoteSystem
                if ($existing -and $existing.PSObject.Properties.Name -contains "err") {
                    throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
                }
                if (-not $existing) {
                    Write-IBMSVLog -Level INFO -Message "Partnership with system '$($target.RemoteSystem)' does not exist on '$($target.Description)'."
                    continue
                }
                else {
                    if ($existing.partnership -in @("fully_configured", "partially_configured_local")) {
                        $result = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "chpartnership" -CmdOpts @{ stop = $true } -CmdArgs $target.RemoteSystem
                        if ($result -and $result.PSObject.Properties.Name -contains "err") {
                            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                        }
                    }
                    $result = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "rmpartnership" -CmdArgs $target.RemoteSystem
                    if ($result -and $result.PSObject.Properties.Name -contains "err") {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                    Write-IBMSVLog -Level INFO -Message "Partnership with system '$($target.RemoteSystem)' removed from '$($target.Description)'."
                }
            }
        }
    }
}
