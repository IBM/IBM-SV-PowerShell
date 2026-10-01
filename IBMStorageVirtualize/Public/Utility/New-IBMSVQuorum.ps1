<#
.SYNOPSIS
Generates and downloads a quorum application from an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVQuorum cmdlet invokes the mkquorumapp command to generate a Java
quorum application on the storage system, then immediately downloads the resulting
ip_quorum.jar file to the local machine using Get-IBMSVFile.

The quorum application can be used in two scenarios:
- High availability tie-break: specify -PartnerSystem to generate a quorum app for
  a policy-based replication partnership between two systems.
- Single-system tie-break: omit -PartnerSystem to generate a standalone quorum app.

.PARAMETER PartnerSystem
Specifies the system ID or name of the remote system in the policy-based replication
high availability partnership.
When specified, the quorum app is configured for HA tie-break with that partner system.
When omitted, the quorum app is configured for single-system tie-break.

.PARAMETER Ip6
Specifies that the quorum application uses IPv6 service addresses to connect to the
system that generated the quorum application.
If not specified, IPv4 is used.

.PARAMETER NoMetadata
Specifies that the quorum application is generated without metadata that stores
configuration data for node recovery operations.
Cannot be specified together with -PartnerSystem.

.PARAMETER PartnerIp6
Specifies that the quorum application uses IPv6 service addresses to connect to the
partner system.
If not specified, IPv4 is used to connect to the partner system.
Requires -PartnerSystem.

.PARAMETER OutFilePath
Specifies the local directory or full file path where the downloaded ip_quorum.jar
should be saved.
If a directory is specified, the file is saved as ip_quorum.jar inside that directory.
If not specified, ip_quorum.jar is saved to the current working directory.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> New-IBMSVQuorum
Generates a quorum application for single-system tie-break and downloads it as
ip_quorum.jar to the current working directory.

.EXAMPLE
PS> New-IBMSVQuorum -Ip6
Generates a single-system tie-break quorum application configured to connect via IPv6.

.EXAMPLE
PS> New-IBMSVQuorum -NoMetadata
Generates a single-system tie-break quorum application without node recovery metadata.

.EXAMPLE
PS> New-IBMSVQuorum -PartnerSystem "cluster2"
Generates a quorum application for the HA partnership with 'cluster2' and downloads
ip_quorum.jar to the current working directory.

.EXAMPLE
PS> New-IBMSVQuorum -PartnerSystem "cluster2" -Ip6 -PartnerIp6
Generates an HA quorum application with IPv6 addresses for both the local and partner systems.

.EXAMPLE
PS> New-IBMSVQuorum -PartnerSystem "cluster2" -OutFilePath "C:\quorum\"
Generates and downloads ip_quorum.jar into the C:\quorum directory.

.EXAMPLE
PS> New-IBMSVQuorum -PartnerSystem "cluster2" -OutFilePath "C:\quorum\myquorum.jar"
Generates and downloads the quorum JAR file, saving it as C:\quorum\myquorum.jar.

.INPUTS
None.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Always downloads the generated file using Get-IBMSVFile immediately after generation.
- -NoMetadata cannot be combined with -PartnerSystem.
- -PartnerIp6 requires -PartnerSystem.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkquorumapp
#>

function New-IBMSVQuorum {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [string]$PartnerSystem,

        [switch]$Ip6,

        [switch]$NoMetadata,

        [switch]$PartnerIp6,

        [string]$OutFilePath,

        [string]$Cluster
    )

    process {
        # --- Parameter validation ---
        if ($PSBoundParameters.ContainsKey('NoMetadata') -and $PartnerSystem) {
            throw (Resolve-Error -ErrorInput "-NoMetadata cannot be specified together with -PartnerSystem." -Category InvalidArgument)
        }

        if ($PSBoundParameters.ContainsKey('PartnerIp6') -and -not $PartnerSystem) {
            throw (Resolve-Error -ErrorInput "-PartnerIp6 requires -PartnerSystem to be specified." -Category InvalidArgument)
        }

        # --- Generate Quorum Application ---
        if ($PSCmdlet.ShouldProcess("Quorum application", "Generate$(if ($PartnerSystem) { " for partnership with '$PartnerSystem'" })")) {

            Write-IBMSVLog -Level DEBUG -Message "Generating quorum application$(if ($PartnerSystem) { " for partner system: $PartnerSystem" })."

            $opts = @{}
            if ($PSBoundParameters.ContainsKey('PartnerSystem')) { $opts['partnersystem'] = $PartnerSystem }
            if ($PSBoundParameters.ContainsKey('Ip6')) { $opts['ip_6'] = $true }
            if ($PSBoundParameters.ContainsKey('NoMetadata')) { $opts['nometadata'] = $true }
            if ($PSBoundParameters.ContainsKey('PartnerIp6')) { $opts['partnerip6'] = $true }
            if ($opts.Count -eq 0) { $opts = $null }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "mkquorumapp" -CmdOpts $opts
            if ($result -and $result.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }

            Write-IBMSVLog -Level INFO -Message "Quorum application generated successfully on system."

            Get-IBMSVFile -Prefix "/dumps" -Filename "ip_quorum.jar" -OutFilePath $OutFilePath -Cluster $Cluster
        }
    }
}
