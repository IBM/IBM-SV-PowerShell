<#
.SYNOPSIS
Removes connection sessions.

.DESCRIPTION
The Disconnect-IBMStorageVirtualize cmdlet removes one or more sessions
created by Connect-IBMStorageVirtualize.

If -Cluster is specified, only that session is removed.
If not specified, all sessions are removed.

If a removed session is marked as primary, the primary session is cleared.

.PARAMETER Cluster
Specifies the cluster whose session should be removed.

If not specified, all sessions are removed.

.EXAMPLE
PS> Disconnect-IBMStorageVirtualize -Cluster 1.1.1.1

Removes the session associated with cluster 1.1.1.1.

.EXAMPLE
PS> Disconnect-IBMStorageVirtualize

Removes all sessions.

.INPUTS
None.

.OUTPUTS
None.

.NOTES
- Removes only locally stored session data.
- No API call is made to the storage system.
- If the session does not exist, no error is thrown.
- Use Get-IBMSVSession to view active sessions.
- Use Connect-IBMStorageVirtualize to establish new sessions.
#>

function Disconnect-IBMStorageVirtualize {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$Cluster
    )

    if ($Cluster) {
        if ($PSCmdlet.ShouldProcess("Cluster $Cluster", "Disconnect")) {
            if ($script:sessions.ContainsKey($Cluster)) {
                $script:sessions.Remove($Cluster)

                if ($script:primarysession -eq $Cluster) {
                    $script:primarysession = $null
                }

                Write-IBMSVLog -Level INFO -Message "REST session for cluster '$Cluster' removed."
            }
            else {
                Write-IBMSVLog -Level INFO -Message "No REST session existed for cluster '$Cluster'."
            }
        }
    }
    else {
        if ($PSCmdlet.ShouldProcess("All sessions", "Disconnect")) {
            if ($script:sessions -and $script:sessions.Count -gt 0) {
                $script:sessions.Clear()
                $script:primarysession = $null

                Write-IBMSVLog -Level INFO -Message "All REST sessions have been removed."
            }
            else {
                Write-IBMSVLog -Level INFO -Message "No active REST sessions found."
            }
        }
    }
}
