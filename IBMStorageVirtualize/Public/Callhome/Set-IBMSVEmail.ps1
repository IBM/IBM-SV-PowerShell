<#
.SYNOPSIS
Configures email and contact information for IBM Storage Virtualize system notifications.

.DESCRIPTION
The Set-IBMSVEmail cmdlet configures email settings and contact information used
for system notifications, alerts, and callhome functionality on an IBM Storage
Virtualize system.

It maps to the chemail command.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER ReplyEmail
Specifies the reply-to email address.

.PARAMETER FromEmail
Specifies the sender email address.

Cannot be used with -RemoveFromEmail.

.PARAMETER RemoveFromEmail
Removes the configured sender email address.

.PARAMETER PrimaryContactName
Specifies the primary contact name.

.PARAMETER PrimaryContactPhone
Specifies the primary contact phone number.

.PARAMETER PrimaryAlternatePhone
Specifies an alternate phone number for the primary contact.

.PARAMETER Location
Specifies the system location.

.PARAMETER SecondaryContactName
Specifies the secondary contact name.

.PARAMETER SecondaryContactPhone
Specifies the secondary contact phone number.

.PARAMETER SecondaryAlternatePhone
Specifies an alternate phone number for the secondary contact.

.PARAMETER RemoveSecondaryContact
Removes all secondary contact information.

.PARAMETER Organization
Specifies the organization name.

.PARAMETER Address
Specifies the street address.

.PARAMETER City
Specifies the city.

.PARAMETER StateCode
Specifies the state or province.

.PARAMETER PostalCode
Specifies the postal or ZIP code.

.PARAMETER CountryCode
Specifies the country code.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Set-IBMSVEmail -ReplyEmail "admin@example.com" -FromEmail "noreply@example.com"

.EXAMPLE
PS> Set-IBMSVEmail -PrimaryContactName "Jane Doe" -PrimaryContactPhone "1234567890"

.EXAMPLE
PS> Set-IBMSVEmail -RemoveSecondaryContact

.INPUTS
None.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs validation of parameter combinations before execution.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chemail
#>

function Set-IBMSVEmail {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string]$ReplyEmail,

        [string]$FromEmail,

        [switch]$RemoveFromEmail,

        [string]$PrimaryContactName,

        [string]$PrimaryContactPhone,

        [string]$PrimaryAlternatePhone,

        [string]$Location,

        [string]$SecondaryContactName,

        [string]$SecondaryContactPhone,

        [string]$SecondaryAlternatePhone,

        [switch]$RemoveSecondaryContact,

        [string]$Organization,

        [string]$Address,

        [string]$City,

        [string]$StateCode,

        [string]$PostalCode,

        [string]$CountryCode,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        if ($FromEmail -and $RemoveFromEmail) {
            throw (Resolve-Error -ErrorInput "Parameters -FromEmail and -RemoveFromEmail are mutually exclusive." -Category InvalidArgument)
        }
        if (($SecondaryContactName -or $SecondaryContactPhone -or $SecondaryAlternatePhone) -and $RemoveSecondaryContact) {
            throw (Resolve-Error -ErrorInput "Parameters -SecondaryContactName, -SecondaryContactPhone, or -SecondaryAlternatePhone are mutually exclusive with -RemoveSecondaryContact." -Category InvalidArgument)
        }

        if ($PSCmdlet.ShouldProcess("Email Configuration", "Modify")) {
            $opts = @{}
            if ($ReplyEmail) { $opts["reply"] = $ReplyEmail }
            if ($FromEmail) { $opts["from"] = $FromEmail }
            if ($RemoveFromEmail) { $opts["nofrom"] = $true }
            if ($PrimaryContactName) { $opts["contact"] = $PrimaryContactName }
            if ($PrimaryContactPhone) { $opts["primary"] = $PrimaryContactPhone }
            if ($PrimaryAlternatePhone) { $opts["alternate"] = $PrimaryAlternatePhone }
            if ($SecondaryContactName) { $opts["contact2"] = $SecondaryContactName }
            if ($SecondaryContactPhone) { $opts["primary2"] = $SecondaryContactPhone }
            if ($SecondaryAlternatePhone) { $opts["alternate2"] = $SecondaryAlternatePhone }
            if ($RemoveSecondaryContact) { $opts["nocontact2"] = $true }
            if ($Organization) { $opts["organization"] = $Organization }
            if ($Location) { $opts["location"] = $Location }
            if ($Address) { $opts["address"] = $Address }
            if ($City) { $opts["city"] = $City }
            if ($StateCode) { $opts["state"] = $StateCode }
            if ($PostalCode) { $opts["zip"] = $PostalCode }
            if ($CountryCode) { $opts["country"] = $CountryCode }

            if ($opts.Count -gt 0) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chemail" -CmdOpts $opts
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                Write-IBMSVLog -Level INFO -Message "Email configuration updated successfully."
            }
            else {
                Write-IBMSVLog -Level INFO -Message "No changes required."
            }
        }
    }
}
