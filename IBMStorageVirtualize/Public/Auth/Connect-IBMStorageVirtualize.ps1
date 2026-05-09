<#
.SYNOPSIS
Establishes a connection session with an IBM Storage Virtualize system.

.DESCRIPTION
The Connect-IBMStorageVirtualize cmdlet authenticates to an IBM Storage
Virtualize system using REST API and creates a reusable session.

The cmdlet supports multiple authentication modes:
1. Credential (default, secure)
   Credentials are used only for authentication and are NOT stored.
   When the authentication token expires, subsequent requests will fail
   and an error will be thrown. The user must reconnect using Connect-IBMStorageVirtualize.

2. Credential with caching (-AllowCredentialCaching)
   Credentials are stored in memory for the duration of the session.
   This allows automatic token refresh without user interaction.

3. Secret-based authentication (-SecretName)
   Credentials are retrieved securely from a vault using PowerShell SecretManagement.
   This enables secure, non-interactive token refresh without storing credentials in memory.

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
- Credentials are NOT stored
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
Specifies whether to validate the SSL/TLS certificate.

Default: Disabled.

.PARAMETER Primary
Marks this connection as the primary session.

Only one primary session is allowed at a time.
If a primary session already exists for a different cluster, an error is thrown.

.PARAMETER TimeoutSec
Specifies the timeout (in seconds) for the authentication request.

Default: 30.

.EXAMPLE
PS> Connect-IBMStorageVirtualize -Cluster 1.1.1.1 -SecretName "cluster1"

Connects using credentials stored in a secure vault.
Token refresh is automatic and secure.

.EXAMPLE
PS> $cred = Get-Credential
PS> Connect-IBMStorageVirtualize -Cluster 1.1.1.1 -Credential $cred -AllowCredentialCaching

Connects and caches credentials in memory.
Token refresh happens automatically.

.EXAMPLE
PS> $cred = Get-Credential
PS> Connect-IBMStorageVirtualize -Cluster 1.1.1.1 -Credential $cred

Connects using credentials without storing them.
Token refresh will require reconnect.

.EXAMPLE
$cred = New-Object System.Management.Automation.PSCredential("superuser", (ConvertTo-SecureString "password" -AsPlainText -Force))
PS> Connect-IBMStorageVirtualize -Cluster 1.1.1.1 -Credential $cred -Primary

Connects and sets the session as primary.

.INPUTS
None.

.OUTPUTS
None.

.NOTES
- Requires network connectivity to the IBM Storage Virtualize REST API.
- Authentication tokens are stored internally and reused automatically.
- Credentials are NOT stored unless explicitly requested.
- Use Get-IBMSVSession to view sessions.
- Use Disconnect-IBMStorageVirtualize to remove sessions.
#>

function Connect-IBMStorageVirtualize {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "Credential")]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Cluster,

        [Parameter(Mandatory, ParameterSetName = "Credential")]
        [pscredential]$Credential,

        [Parameter(ParameterSetName = "Credential")]
        [switch]$AllowCredentialCaching,

        [Parameter(Mandatory, ParameterSetName = "Secret")]
        [ValidateNotNullOrEmpty()]
        [string]$SecretName,

        [Parameter(ParameterSetName = "Secret")]
        [string]$VaultName,

        [string]$Domain,

        [switch]$ValidateCerts,

        [switch]$Primary,

        [int]$TimeoutSec = 30
    )

    if ($PSCmdlet.ShouldProcess("Cluster $Cluster", "Connect")) {
        $HostName = if ($Domain) { "$Cluster.$Domain" } else { $Cluster }
        $BaseUrl = "https://${HostName}:7443/rest/v1"

        if ($PSCmdlet.ParameterSetName -eq "Secret") {
            if (-not (Get-Command Get-Secret -ErrorAction SilentlyContinue)) {
                throw (Resolve-Error -ErrorInput "SecretManagement module not available. Install: Install-Module Microsoft.PowerShell.SecretManagement" -Category ResourceUnavailable)
            }
            try {
                if ($PSBoundParameters.ContainsKey('VaultName')) {
                    $cred = Get-Secret -Name $SecretName -Vault $VaultName -ErrorAction Stop
                }
                else {
                    $cred = Get-Secret -Name $SecretName -ErrorAction Stop
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

        if ($Primary -and $script:primarysession -and $script:primarysession -ne $Cluster) {
            throw (Resolve-Error -ErrorInput "Primary session already set to $($script:primarysession). Only one primary session allowed." -Category InvalidOperation)
        }

        try {
            $result = Set-CertPolicy -ValidateCerts $ValidateCerts.IsPresent
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            $response = Invoke-RestMethod -Uri "$BaseUrl/auth" -Method Post -Headers @{
                "Content-Type"    = "application/json"
                "X-Auth-Username" = $Credential.UserName
                "X-Auth-Password" = $Credential.GetNetworkCredential().Password
            } -TimeoutSec $TimeoutSec
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
            Primary          = $Primary
            Credential       = if ($AllowCredentialCaching) { $Credential } else { $null }
            SecretName       = $SecretName
            VaultName        = $VaultName
            Token            = $response.token
            LastRestAuthTime = Get-Date
            ValidateCerts    = $ValidateCerts.IsPresent
            SVCVersion       = $null
        }

        $script:sessions[$Cluster] = $sessionObj

        if ($Primary) {
            $script:primarysession = $Cluster
        }

        $msg = "Connected successfully to $Cluster"
        if ($Primary) { $msg += " (Primary)" }

        Write-IBMSVLog -Level INFO -Message $msg

        if ($PSCmdlet.ParameterSetName -eq "Credential") {
            if (-not $AllowCredentialCaching) {
                Write-IBMSVLog -Level WARN -Message "Credential not cached. Token refresh will require reconnect. Use -SecretName or -AllowCredentialCaching."
            }
            else {
                Write-IBMSVLog -Level WARN -Message "Credential is being cached in session memory for automatic token refresh."
            }
        }

        $result = Invoke-IBMSVPluginRegistration -Session $sessionObj -UserName $Credential.Username
        if ($result.err) {
            throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
        }
    }
}
