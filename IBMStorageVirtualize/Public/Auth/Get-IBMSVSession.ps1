<#
.SYNOPSIS
Retrieves IBM Storage Virtualize REST session information.

.DESCRIPTION
The Get-IBMSVSession cmdlet returns locally stored REST sessions created by
Connect-IBMStorageVirtualize.

You can:
- Retrieve a specific session using -Cluster
- Retrieve the primary session using -Primary
- Retrieve all sessions

Security:
The returned object does not include sensitive information such as tokens or passwords.

.PARAMETER Cluster
Specifies the cluster whose session should be retrieved.

.PARAMETER Primary
Returns the primary session.

Cannot be used with -Cluster.

.EXAMPLE
PS> Get-IBMSVSession

Returns all active sessions.

.EXAMPLE
PS> Get-IBMSVSession -Cluster 1.1.1.1

Returns the session for the specified cluster.

.EXAMPLE
PS> Get-IBMSVSession -Primary

Returns the primary session.

.INPUTS
System.String

.OUTPUTS
System.Management.Automation.PSCustomObject

.NOTES
- Sessions are created using Connect-IBMStorageVirtualize.
- This cmdlet does not call the storage system.
#>

function Get-IBMSVSessionView {
    param($session)

    $baseObj = @{
        Cluster          = $session.Cluster
        Domain           = $session.Domain
        Primary          = $session.Primary
        AuthType         = if ($session.SecretName) {
            "Secret"
        }
        elseif ($session.Credential) {
            "Credential (Cached)"
        }
        else {
            "Credential (Not Cached)"
        }
        SecretName       = $session.SecretName
        VaultName        = $session.VaultName
        LastRestAuthTime = $session.RestLastAuthenticated
        ValidateCerts    = $session.ValidateCerts
        SVCVersion       = $session.SVCVersion
    }

    [pscustomobject]$baseObj
}

function Get-IBMSVSession {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$Cluster,

        [switch]$Primary
    )

    if ($Cluster -and $Primary) {
        throw (Resolve-Error -ErrorInput "Cannot specify both -Cluster and -Primary parameters." -Category InvalidArgument)
    }

    if ($Primary) {
        if ($script:primarysession) {
            return Get-IBMSVSessionView $script:sessions[$script:primarysession]
        }
        Write-IBMSVLog -Level INFO -Message "No primary session found."
        return
    }

    if ($Cluster) {
        if ($script:sessions.ContainsKey($Cluster)) {
            return Get-IBMSVSessionView $script:sessions[$Cluster]
        }
        Write-IBMSVLog -Level INFO -Message "No session found for cluster $Cluster."
        return
    }

    if ($script:sessions -and $script:sessions.Count -gt 0) {
        return $script:sessions.Values | ForEach-Object { Get-IBMSVSessionView $_ }
    }

    Write-IBMSVLog -Level INFO -Message "No active session found."
    return

}
