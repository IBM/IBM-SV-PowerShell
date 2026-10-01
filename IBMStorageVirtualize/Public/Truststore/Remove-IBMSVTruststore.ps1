<#
.SYNOPSIS
Removes an existing truststore from an IBM Storage Virtualize system.

.DESCRIPTION
The Remove-IBMSVTruststore cmdlet deletes a truststore from the system.

.PARAMETER Name
Specifies the name of the truststore to remove from the local cluster.

.PARAMETER RemoteTruststoreName
Specifies the name of the truststore if it is not the same as Name on the remote cluster.
If not provided, defaults to the same name as Name.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.PARAMETER RemoteCluster
Specifies the remote cluster from which to remove the truststore.
When specified, truststores are removed from both local and remote clusters.

.EXAMPLE
PS> Remove-IBMSVTruststore -Name "trust_partner"
Removes the truststore from the local cluster only.

.EXAMPLE
PS> Remove-IBMSVTruststore -Name "trust_partner" -RemoteCluster "10.10.10.20"
Removes truststores named "trust_partner" from both local and remote clusters.

.EXAMPLE
PS> Remove-IBMSVTruststore -Name "trust_local" -RemoteTruststoreName "trust_remote" -RemoteCluster "10.10.10.20"
Removes truststores with different names from local and remote clusters.

.EXAMPLE
PS> Remove-IBMSVTruststore -Name "trust_old" -WhatIf
Shows what would happen if the truststore were removed.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- This is a destructive operation and cannot be undone.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/rmtruststore
#>

function Remove-IBMSVTruststore {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$RemoteTruststoreName,

        [string]$Cluster,

        [string]$RemoteCluster
    )

    process {
        if (-not $Cluster) {
            $Cluster = $script:primarysession
        }

        $clustersToUpdate = @()
        if (-not $RemoteCluster) {
            if ($RemoteTruststoreName) {
                throw (Resolve-Error -ErrorInput "-RemoteTruststoreName is not applicable when -RemoteCluster is not specified." -Category InvalidArgument)
            }
            $clustersToUpdate += [pscustomobject]@{
                Cluster     = $Cluster
                Name        = $Name
                Description = "cluster '$Cluster'"
            }
        }
        else {
            if (-not $RemoteTruststoreName) {
                $RemoteTruststoreName = $Name
            }
            $clustersToUpdate += [pscustomobject]@{
                Cluster     = $Cluster
                Name        = $Name
                Description = "primary cluster '$Cluster'"
            }
            $clustersToUpdate += [pscustomobject]@{
                Cluster     = $RemoteCluster
                Name        = $RemoteTruststoreName
                Description = "secondary cluster '$RemoteCluster'"
            }
        }

        # --- Remove Truststore ---
        foreach ($target in $clustersToUpdate) {
            if ($PSCmdlet.ShouldProcess("Truststore '$($target.name)'", "Remove")) {

                # --- Existence check ---
                $existing = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "lstruststore" -CmdArgs $target.Name
                if ($existing.err) {
                    throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
                }
                if (-not $existing) {
                    Write-IBMSVLog -Level INFO -Message "Truststore '$($target.Name)' does not exist on $($target.Description)."
                }
                else {
                    $result = Invoke-IBMSVRestRequest -Cluster $target.Cluster -Cmd "rmtruststore" -CmdArgs $target.Name
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                    Write-IBMSVLog -Level INFO -Message "Truststore '$($target.Name)' removed successfully from $($target.Description)."
                }
            }
        }
    }
}
