<#
.SYNOPSIS
Establishes a connection session with an IBM Storage Virtualize system.

.DESCRIPTION
The Connect-IBMStorageVirtualize cmdlet authenticates to an IBM Storage
Virtualize system using REST API and creates a reusable session.

The cmdlet uses HTTPS REST API on port 7443 for all operations.

The cmdlet supports multiple authentication modes:
1. Secret-based authentication (-SecretName)
   Credentials are retrieved securely from a vault using PowerShell SecretManagement.
   This enables secure, non-interactive token refresh without storing credentials in memory.

2. Credential with caching (-AllowCredentialCaching)
   Credentials are stored in memory for the duration of the session.
   This allows automatic token refresh when the token expires.

3. Credential (default)
   Credentials are used for authentication. The authentication token is stored,
   but credentials are NOT stored unless explicitly requested.
   When the authentication token expires, subsequent requests will fail and
   the user must reconnect.

Sessions are reused automatically when connecting with the same settings.
You can mark one session as the primary session, which will
be used by default when other cmdlets do not explicitly specify a cluster.

.PARAMETER Cluster
Specifies the hostname or management IP address of the IBM Storage Virtualize system.

.PARAMETER Credential
Specifies the credentials used to authenticate with the system.
This should be a PSCredential object containing the REST API username and password.

.PARAMETER AllowCredentialCaching
Specifies that the provided credential should be stored in memory for the session.

When enabled:
- Token refresh is automatic
- No additional prompts are required

When not enabled:
- Credentials are NOT stored (only the authentication token is stored)
- Token refresh will fail and require reconnect

.PARAMETER SecretName
Specifies the name of a secret stored in a PowerShell SecretManagement vault.

The secret must contain a PSCredential object.

This enables secure authentication and automatic token refresh without storing credentials in memory.

To set up a vault and store credentials, see the module README.

.PARAMETER VaultName
Specifies the name of the SecretManagement vault from which the secret should be retrieved.

When provided, the cmdlet retrieves the credential from the specified vault instead of the default vault.

This parameter is optional. If not specified, the default vault registered in SecretManagement is used.

Use this parameter when:
- Multiple vaults are configured (e.g., LocalStore, Azure Key Vault, HashiCorp Vault)
- You want to explicitly control which vault is used for authentication

.PARAMETER Domain
Specifies an optional domain name to append to the cluster hostname.

.PARAMETER ValidateCerts
Specifies whether to validate the SSL/TLS certificate when connecting via REST API.

Default: Disabled (certificate validation is skipped).

.PARAMETER AutoAddHostKey
Automatically accepts and stores a new SSH host key when the existing trusted key no longer matches the server.

.PARAMETER Primary
Marks this connection as the primary session.

Only one primary session is allowed at a time.
If a primary session already exists for a different cluster, an error is thrown.

.PARAMETER TimeoutSec
Specifies the timeout (in seconds) for the authentication request.

Default: 30.

.EXAMPLE
PS> Connect-IBMStorageVirtualize -Cluster 1.1.1.1 -SecretName "cluster1"

Connects using REST API with credentials stored in a secure vault.
Token refresh is automatic and secure.

.EXAMPLE
PS> $cred = Get-Credential
PS> Connect-IBMStorageVirtualize -Cluster 1.1.1.1 -Credential $cred -AllowCredentialCaching

Connects via REST and caches credentials in memory.
Token refresh happens automatically.

.EXAMPLE
PS> $cred = Get-Credential
PS> Connect-IBMStorageVirtualize -Cluster 1.1.1.1 -Credential $cred

Connects via REST without caching credentials.
Authentication token is stored, but credentials are not.
Token refresh will fail when the token expires.

.EXAMPLE
PS> $cred = Get-Credential
PS> Connect-IBMStorageVirtualize -Cluster 1.1.1.1 -Credential $cred -Primary

Connects via REST and sets the session as primary.
This session will be used by default for all subsequent cmdlets.

.INPUTS
None.

.OUTPUTS
None.

.NOTES
- Requires network connectivity to the IBM Storage Virtualize REST API (port 7443).
- Authentication tokens are stored internally and reused automatically.
- Credentials are NOT stored unless -AllowCredentialCaching or -SecretName is used.
- Use Get-IBMSVSession to view sessions.
- Use Disconnect-IBMStorageVirtualize to remove sessions.
#>

function Connect-IBMStorageVirtualize {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "Credential")]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Cluster,

        [pscredential]$Credential,

        [switch]$AllowCredentialCaching,

        [string]$SecretName,

        [string]$VaultName,

        [string]$Domain,

        [switch]$ValidateCerts,

        [switch]$AutoAddHostKey,

        [switch]$Primary,

        [int]$TimeoutSec = 30
    )

    if ($PSCmdlet.ShouldProcess("Cluster $Cluster", "Connect")) {

        if (-not $Credential -and -not $SecretName) {
            throw (Resolve-Error -ErrorInput "Either -Credential or -SecretName must be specified." -Category InvalidArgument)
        }

        if ($Primary -and $script:primarysession -and $script:primarysession -ne $Cluster) {
            throw (Resolve-Error -ErrorInput "'$($script:primarysession)' is currently set as primary cluster. Please disconnect primary session before setting '$Cluster' as a primary cluster." -Category InvalidOperation)
        }

        if ($SecretName) {
            if (-not (Get-Command Get-Secret -ErrorAction SilentlyContinue)) {
                throw (Resolve-Error -ErrorInput "SecretManagement module not available. Install: Install-Module Microsoft.PowerShell.SecretManagement" -Category ResourceUnavailable)
            }
            try {
                $cred = if ($PSBoundParameters.ContainsKey('VaultName')) {
                    Get-Secret -Name $SecretName -Vault $VaultName -ErrorAction Stop
                }
                else {
                    Get-Secret -Name $SecretName -ErrorAction Stop
                }
            }
            catch {
                if ($_.Exception.Message -match "locked|unlock") {
                    $category = "PermissionDenied"
                    $msg = "SecretStore is locked. Run Unlock-SecretStore or configure non-interactive mode."
                }
                else {
                    $category = "ObjectNotFound"
                    $msg = "Failed to retrieve secret '$SecretName'. $_"
                }

                throw (Resolve-Error -ErrorInput $msg -Category $category)
            }

            if ($cred -isnot [pscredential]) {
                throw (Resolve-Error -ErrorInput "Secret '$SecretName' is not a PSCredential." -Category InvalidData)
            }
            $Credential = $cred
        }

        if ($script:sessions.ContainsKey($Cluster)) {
            Write-IBMSVLog -Level INFO -Message "Session for cluster '$Cluster' already exists. Removing existing session."
            Disconnect-IBMStorageVirtualize -Cluster $Cluster
        }

        $HostName = if ($Domain) { "$Cluster.$Domain" } else { $Cluster }
        $BaseUrl = "https://${HostName}:7443/rest/v1"

        $token = $null

        try {
            $result = Set-CertPolicy -ValidateCerts $ValidateCerts.IsPresent
            if ($result.err) { throw (Resolve-Error -ErrorInput $result -Category InvalidOperation) }
            $response = Invoke-RestMethod -Uri "$BaseUrl/auth" -Method Post -Headers @{
                "Content-Type"    = "application/json"
                "X-Auth-Username" = $Credential.UserName
                "X-Auth-Password" = $Credential.GetNetworkCredential().Password
            } -TimeoutSec $TimeoutSec

            $token = $response.token
        }
        catch {
            $ex = $_.Exception
            if ($ex.Response) {
                $status = $ex.Response.StatusCode.value__
                $body = ($_.ErrorDetails.Message | Out-String).Trim()
                if ($body -match '^"(.*)"$') {
                    $body = $Matches[1]
                }
                throw (Resolve-Error -ErrorInput "Authentication failed (HTTP $status): $body" -Category AuthenticationError)
            }
            else {
                throw (Resolve-Error -ErrorInput "Connection failed: $($ex.Message)" -Category ConnectionError)
            }
        }

        $sessionObj = @{
            Cluster          = $Cluster
            Domain           = $Domain
            Primary          = $Primary.IsPresent

            Credential       = if ($AllowCredentialCaching) { $Credential } else { $null }
            SecretName       = $SecretName
            VaultName        = $VaultName

            Token            = $token
            LastRestAuthTime = Get-Date
            ValidateCerts    = $ValidateCerts.IsPresent

            AutoAddHostKey   = $AutoAddHostKey.IsPresent

            SVCVersion       = $null
        }

        $script:sessions[$Cluster] = $sessionObj

        if ($Primary) {
            $script:primarysession = $Cluster
        }

        $msg = "Connected successfully to $Cluster"
        if ($Primary) { $msg += " as the primary session" }

        Write-IBMSVLog -Level INFO -Message $msg

        if (-not $AllowCredentialCaching -and -not $SecretName) {
            Write-IBMSVLog -Level WARN -Message "Credentials are not cached. Automatic re-authentication may fail if the session expires. Use -AllowCredentialCaching or -SecretName enable automatic reconnection."
        }

        $result = Invoke-IBMSVPluginRegistration -Session $sessionObj -Username $Credential.UserName
        if ($result.err) { return $result }
    }
}
