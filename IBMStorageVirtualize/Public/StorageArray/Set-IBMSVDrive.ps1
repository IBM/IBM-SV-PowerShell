<#
.SYNOPSIS
Manages drive operations on an IBM Storage Virtualize system.

.DESCRIPTION
The Set-IBMSVDrive cmdlet manages drive-related operations including changing drive state
and performing tasks such as format, certify, recover, erase, and triggerdump.

.PARAMETER Id
Specifies the drive ID to manage.

.PARAMETER State
Specifies the desired usability state of the drive.
Valid values: unused, candidate, spare, failed.

Mutually exclusive with -Task parameter.

.PARAMETER Task
Specifies a task to be performed on the drive.
Valid values: format, certify, recover, erase, triggerdump.

Mutually exclusive with -State parameter.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary session is used.

.EXAMPLE
PS> Set-IBMSVDrive -Id 5 -State candidate
Changes the drive state to candidate for drive ID 5.

.EXAMPLE
PS> Set-IBMSVDrive -Id 5 -Task format
Formats drive ID 5.

.EXAMPLE
PS> Set-IBMSVDrive -Id 5 -Task triggerdump
Triggers a drive dump for drive ID 5.

.EXAMPLE
PS> Set-IBMSVDrive -Id 5 -Task recover
Recovers drive ID 5.

.EXAMPLE
PS> Set-IBMSVDrive -Id 5 -State spare -WhatIf
Shows what would happen without applying changes.

.INPUTS
System.Int

You can pipe a drive ID to this cmdlet.

.OUTPUTS
None.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Supports -WhatIf and -Confirm.
- -State and -Task parameters are mutually exclusive.
- If a different task is already in progress on the drive, the cmdlet will throw an error.
- For triggerdump task, no progress check is performed before execution.

.LINK
https://www.ibm.com/docs/en/search/chdrive

.LINK
https://www.ibm.com/docs/en/search/triggerdrivedump

.LINK
https://www.ibm.com/docs/en/search/lsdriveprogress
#>

function Set-IBMSVDrive {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int]$Id,

        [ValidateSet("unused", "candidate", "failed", "spare")]
        [string]$State,

        [ValidateSet("format", "certify", "recover", "erase", "triggerdump")]
        [string]$Task,

        [string]$Cluster
    )

    process {
        # --- Parameter validation ---
        if (-not $State -and -not $Task) {
            throw (Resolve-Error -ErrorInput "Either -State or -Task parameter must be specified." -Category InvalidArgument)
        }

        if ($State -and $Task) {
            throw (Resolve-Error -ErrorInput "Parameters -State and -Task are mutually exclusive." -Category InvalidArgument)
        }

        # --- Execute drive command ---
        if ($PSCmdlet.ShouldProcess("Drive ID '$Id'", 'Modify')) {

            if ($Task) {
                if ($Task -eq 'triggerdump') {
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "triggerdrivedump" -CmdArgs $Id
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                    Write-IBMSVLog -Level INFO -Message "Drive dump triggered for drive ID $Id."
                }
                else {
                    $progressResult = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsdriveprogress" -CmdArgs $Id
                    if ($progressResult -and $progressResult.PSObject.Properties.Name -contains "err") {
                        throw (Resolve-Error -ErrorInput $progressResult -Category InvalidOperation)
                    }
                    if (-not $progressResult) {
                        throw (Resolve-Error -ErrorInput "Drive ID '$Id' does not exist." -Category ObjectNotFound)
                    }
                    $currentTask = $null
                    if (-not [string]::IsNullOrWhiteSpace($progressResult.task)) {
                        $currentTask = $progressResult.task
                    }

                    if ($currentTask) {
                        if ($currentTask -eq $Task) {
                            Write-IBMSVLog -Level INFO -Message "Task '$Task' is already in progress on drive ID $Id."
                            return
                        }

                        if ($currentTask -in @('format', 'certify', 'recover', 'erase')) {
                            throw (Resolve-Error -ErrorInput "CMMVC6625E Task '$currentTask' is already in progress on drive ID $Id. Cannot start task '$Task'." -Category InvalidOperation)
                        }
                    }

                    $cmdOpts = @{ task = $Task }
                    $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chdrive" -CmdOpts $cmdOpts -CmdArgs $Id
                    if ($result.err) {
                        throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                    }
                    Write-IBMSVLog -Level INFO -Message "Task '$Task' started on drive ID $Id."
                }
            }
            elseif ($State) {
                $cmdOpts = @{ use = $State }
                $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "chdrive" -CmdOpts $cmdOpts -CmdArgs $Id
                if ($result.err) {
                    throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
                }
                Write-IBMSVLog -Level INFO -Message "Drive ID $Id state changed to '$State'."
            }
        }
    }
}
