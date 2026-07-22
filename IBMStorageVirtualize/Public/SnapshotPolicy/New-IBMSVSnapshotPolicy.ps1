<#
.SYNOPSIS
Creates a new snapshot policy on an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVSnapshotPolicy cmdlet creates a snapshot policy on an IBM Storage Virtualize system.

.PARAMETER Name
Specifies the name of the snapshot policy to create.

.PARAMETER BackupUnit
Specifies the backup unit in the mentioned metric.
Valid values: minute, hour, day, week, month.
Required for creating a snapshot policy.

.PARAMETER BackupInterval
Specifies the backup interval.
Required for creating a snapshot policy.

.PARAMETER BackupStartTime
Specifies the start time of backup in the format YYMMDDHHMM.

.PARAMETER RetentionDays
Specifies the retention days for the backup.
Required for creating a snapshot policy.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> New-IBMSVSnapshotPolicy -Name policy0 -BackupUnit day -BackupInterval 1 -BackupStartTime 2102281800 -RetentionDays 15
Creates a snapshot policy with daily backups.

.EXAMPLE
PS> New-IBMSVSnapshotPolicy -Name policy1 -BackupUnit hour -BackupInterval 6 -BackupStartTime 2102281200 -RetentionDays 7
Creates a snapshot policy with backups every 6 hours.

.EXAMPLE
PS> New-IBMSVSnapshotPolicy -Name policy2 -BackupUnit week -BackupInterval 1 -BackupStartTime 2102280000 -RetentionDays 30
Creates a snapshot policy with weekly backups.

.EXAMPLE
PS> New-IBMSVSnapshotPolicy -Name policy3 -BackupUnit month -BackupInterval 1 -BackupStartTime 2102010000 -RetentionDays 365
Creates a snapshot policy with monthly backups.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
System.Object
Returns the created snapshot policy object, or the existing snapshot policy object if it already exists.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mksnapshotpolicy
#>

function New-IBMSVSnapshotPolicy {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet("minute", "hour", "day", "week", "month")]
        [string]$BackupUnit,

        [Parameter(Mandatory)]
        [Int64]$BackupInterval,

        [string]$BackupStartTime,

        [Parameter(Mandatory)]
        [int]$RetentionDays,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        if ($BackupStartTime -and $BackupStartTime -notmatch '^\d{10}$') {
            throw (Resolve-Error -ErrorInput "Parameter -BackupStartTime must be in format YYMMDDHHMM." -Category InvalidArgument)
        }

        # --- Create Snapshot Policy ---
        if ($PSCmdlet.ShouldProcess("Snapshot Policy '$Name'", "Create")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lssnapshotpolicy" -CmdArgs ($Name)
            if ($existing) {
                if ($existing.PSObject.Properties.Name -contains "err") {
                    throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
                }
                Write-IBMSVLog -Level INFO -Message "Snapshot Policy '$Name' already exists. Returning existing object."
                return $existing
            }

            $opts = @{
                name           = $Name
                backupunit     = $BackupUnit
                backupinterval = $BackupInterval
                retentiondays  = $RetentionDays
            }
            if ($PSBoundParameters.ContainsKey('BackupStartTime')) {
                $opts['backupstarttime'] = $BackupStartTime
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "mksnapshotpolicy" -CmdOpts $opts
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Snapshot Policy [$($result.id)] '$Name' created successfully"

            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lssnapshotpolicy" -CmdArgs ($Name)
            if ($current -and $current.PSObject.Properties.Name -contains "err") {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            return $current
        }
    }
}
