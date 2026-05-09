<#
.SYNOPSIS
Updates license configuration and feature activation on an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVLicense cmdlet updates system license configuration.

It maps to chlicense, activatefeature, and deactivatefeature commands depending on requested changes.

The cmdlet is idempotent:
- Only properties that differ from the current configuration are modified.
- If no changes are required, no operation is performed.

Supports -WhatIf and -Confirm for safe execution.

.PARAMETER Flash
Specifies the Flash license value.

.PARAMETER Remote
Specifies the Remote Copy license value.

.PARAMETER Virtualization
Specifies the Virtualization license value.

.PARAMETER Compression
Specifies the Compression license value.

.PARAMETER PhysicalFlash
Specifies whether the Physical Flash license is enabled.
Valid values: on, off.

.PARAMETER EasyTier
Specifies the Easy Tier license value.

.PARAMETER Cloud
Specifies the Cloud license value.

.PARAMETER LicenseKey
Specifies the license keys for feature activation.

The provided list represents the desired final state:
- New keys are activated.
- Existing keys not in the list are deactivated.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.

If not provided, the primary session is used.

.EXAMPLE
PS> Set-IBMSVLicense -Flash 50 -Virtualization 100

Updates license configurations.

.EXAMPLE
PS> Set-IBMSVLicense -Compression 10

Updates the Compression.

.EXAMPLE
PS> Set-IBMSVLicense -LicenseKey "KEY1","KEY2"

Ensures only the specified license keys are active.

.EXAMPLE
PS> Set-IBMSVLicense -EasyTier 20 -Cloud 5 -WhatIf

Shows what would happen without applying changes.

.INPUTS
None.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Only modified properties are sent to the backend.
- Fully supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/chlicense

.LINK
https://www.ibm.com/docs/en/search/activatefeature

.LINK
https://www.ibm.com/docs/en/search/deactivatefeature
#>

function Set-IBMSVLicense {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        [int]$Flash,

        [int]$Remote,

        [int]$Virtualization,

        [int]$Compression,

        [ValidateSet("on", "off")]
        [string]$PhysicalFlash,

        [int]$EasyTier,

        [int]$Cloud,

        [string[]]$LicenseKey,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        if ($LicenseKey) {
            $res = ConvertTo-NormalizedValue -Name 'LicenseKey' -Value ($LicenseKey -join ",") -Separator ","
            if ($res.err) {
                throw (Resolve-Error -ErrorInput $res.err -Category InvalidArgument)
            }
            $LicenseKey = $res.out
        }
        # --- Update License ---
        if ($PSCmdlet.ShouldProcess("License", "Modify")) {

            # --- Getting Info ---
            $requiresLicenseData = ($Flash -or $Remote -or $Virtualization -or $Compression -or $PhysicalFlash -or $EasyTier -or $Cloud)
            $licenseData = if ($requiresLicenseData) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lslicense" -CmdArgs ("-gui")
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                $result
            }
            else {
                $null
            }

            # --- Probe logic ---
            $props = @{}
            $existingLicenseIdMap = $null; $activateKeys = $null; $deactivateKeys = $null
            $paramsMapping = @(
                @{ Key = 'Flash'; Existing = [int]$licenseData.license_flash }
                @{ Key = 'Remote'; Existing = [int]$licenseData.license_remote }
                @{ Key = 'Virtualization'; Existing = [int]$licenseData.license_virtualization }
                @{ Key = 'PhysicalFlash'; Existing = $licenseData.license_physical_flash; paramName = 'physical_flash' }
                @{ Key = 'EasyTier'; Existing = [int]$licenseData.license_easy_tier }
                @{ Key = 'Cloud'; Existing = [int]$licenseData.license_cloud_enclosures }
            )
            foreach ($item in $paramsMapping) {
                if ($PSBoundParameters.ContainsKey($item.Key)) {
                    $inputValue = Get-Variable -Name $item.Key -ValueOnly
                    $paramName = if ($item.paramName) { $item.paramName } else { $item.Key.ToLower() }
                    if ($inputValue -and $inputValue -ne $item.Existing) {
                        if ($inputValue -is [System.Management.Automation.SwitchParameter]) { $inputValue = $true }
                        $props[$paramName] = $inputValue
                    }
                }
            }

            if ($PSBoundParameters.ContainsKey('Compression')) {
                $systemData = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lssystem" -CmdArgs ("-gui")
                if ($systemData.err) {
                    throw (Resolve-Error -ErrorInput $systemData -Category InvalidOperation)
                }
                if (($systemData.product_name -eq "IBM Storwize V7000") -or ($systemData.product_name -eq "IBM FlashSystem 7000")) {
                    if ($Compression -ne [int]$licenseData.license_compression_enclosures) { $props["compression"] = $Compression }
                }
                else {
                    if ($Compression -ne [int]$licenseData.license_compression_capacity) { $props["compression"] = $Compression }
                }
            }

            if ($LicenseKey) {
                $featureData = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsfeature" -CmdArgs ("-gui")
                if ($featureData.err) {
                    throw (Resolve-Error -ErrorInput $featureData -Category InvalidOperation)
                }
                $inputLicenseKeys = $LicenseKey.Split(",")

                $existingLicenseKeys = @()
                $existingLicenseIdMap = @{}
                foreach ($item in $featureData) {
                    if ($item.license_key) {
                        $existingLicenseKeys += $item.license_key
                        $existingLicenseIdMap[$item.license_key] = $item.id
                    }
                }
                $activateKeys = $inputLicenseKeys  | Where-Object { $_ -notin $existingLicenseKeys }
                $deactivateKeys = $existingLicenseKeys | Where-Object { $_ -notin $inputLicenseKeys }
                if ($activateKeys.Count -gt 0 -or $deactivateKeys.Count -gt 0) { $props["feature"] = $true }
            }

            if ($props.Count -eq 0) { Write-IBMSVLog -Level INFO -Message "No changes required."; return }

            # --- Apply changes ---
            if ($props.ContainsKey('feature')) {
                foreach ($key in $deactivateKeys) {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "deactivatefeature" -CmdArgs $existingLicenseIdMap[$key]
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                }
                foreach ($key in $activateKeys) {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "activatefeature" -CmdOpts @{ licensekey = $key }
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                }
                $props.remove('feature')
            }

            foreach ($key in $props.Keys) {
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chlicense" -CmdOpts @{ $key = $props[$key] }
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
            }

            Write-IBMSVLog -Level INFO -Message "System configuration updated successfully."
        }
    }
}
