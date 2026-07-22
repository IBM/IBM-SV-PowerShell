<#
.SYNOPSIS
Creates a new replication policy on an IBM Storage Virtualize system.

.DESCRIPTION
The New-IBMSVReplicationPolicy cmdlet creates a replication policy on an IBM Storage Virtualize system.

.PARAMETER Name
Specifies the name of the replication policy to create.

.PARAMETER Topology
Specifies the policy topology.
Valid values: 2-site-async-dr, 2-site-ha, async-dr.
Required for creating a replication policy.

.PARAMETER Location1System
Specifies the name or ID of the system in location 1 of the topology.
Required for 2-site-async-dr and 2-site-ha topologies.
Not valid for async-dr topology.

.PARAMETER Location1IOGrp
Specifies the ID of the I/O group of the system in location 1 of the topology.
Required for 2-site-async-dr and 2-site-ha topologies.
Not valid for async-dr topology.

.PARAMETER Location2System
Specifies the name or ID of the system in location 2 of the topology.
Required for 2-site-async-dr and 2-site-ha topologies.
Not valid for async-dr topology.

.PARAMETER Location2IOGrp
Specifies the ID of the I/O group of the system in location 2 of the topology.
Required for 2-site-async-dr and 2-site-ha topologies.
Not valid for async-dr topology.

.PARAMETER RpoAlert
Specifies the RPO alert threshold in seconds.
The minimum value is 60 (1 minute) and the maximum value is 86400 (1 day).
The value must be a multiple of 60 seconds.

.PARAMETER Partition
Specifies the name of the storage partition to be assigned to async-dr replication policy.
Required for async-dr topology.
Not valid for 2-site-async-dr and 2-site-ha topologies.
Supported from Storage Virtualize family systems 8.7.1.0 or later.

.PARAMETER Snapshots
Specifies whether snapshots created for volumes and volume groups associated with the policy will be replicated to the remote system.
Valid values: yes, no.
Valid only for 2-site-ha topology.
Supported from Storage Virtualize family systems 8.7.3.0 or later.

.PARAMETER Cluster
Specifies the FlashSystem cluster to connect to.
If not provided, the primary cluster is used.

.EXAMPLE
PS> New-IBMSVReplicationPolicy -Name replication_policy0 -Topology 2-site-async-dr -Location1System "10.10.10.1" -Location1IOGrp 0 -Location2System "10.10.10.2" -Location2IOGrp 0 -RpoAlert 60
Creates a 2-site async DR replication policy.

.EXAMPLE
PS> New-IBMSVReplicationPolicy -Name replication_policy1 -Topology 2-site-ha -Location1System "10.10.10.1" -Location1IOGrp 0 -Location2System "10.10.10.2" -Location2IOGrp 0
Creates a 2-site HA replication policy.

.EXAMPLE
PS> New-IBMSVReplicationPolicy -Name replication_policy2 -Topology async-dr -Partition partition0 -RpoAlert 60
Creates an async DR replication policy with partition.

.EXAMPLE
PS> New-IBMSVReplicationPolicy -Name replication_policy3 -Topology 2-site-ha -Location1System "10.10.10.1" -Location1IOGrp 0 -Location2System "10.10.10.2" -Location2IOGrp 0 -Snapshots yes
Creates a 2-site HA replication policy with HA snapshots enabled.

.INPUTS
System.String
You can pipe objects with a Name property to this cmdlet.

.OUTPUTS
System.Object
Returns the created replication policy, or the existing replication policy if it already exists.

.NOTES
- Requires an authenticated session via Connect-IBMStorageVirtualize.
- Performs an existence check before creation.
- Supports -WhatIf and -Confirm.

.LINK
https://www.ibm.com/docs/en/search/mkreplicationpolicy
#>

function New-IBMSVReplicationPolicy {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet("2-site-async-dr", "2-site-ha", "async-dr")]
        [string]$Topology,

        [string]$Location1System,

        [int]$Location1IOGrp,

        [string]$Location2System,

        [int]$Location2IOGrp,

        [int]$RpoAlert,

        [string]$Partition,

        [ValidateSet("yes", "no")]
        [string]$Snapshots,

        [string]$Cluster
    )

    process {
        # --- Parameter-level validation ---
        $locationParams = @('Location1System', 'Location1IOGrp', 'Location2System', 'Location2IOGrp')

        if ($Topology -eq "async-dr") {
            if (-not $Partition) {
                throw (Resolve-Error -ErrorInput "Partition must be accompanied by 'async-dr'." -Category InvalidArgument)
            }

            $invalidParams = $locationParams | Where-Object { $PSBoundParameters.ContainsKey($_) } | ForEach-Object { "-$_" }

            if ($invalidParams.Count -gt 0) {
                throw (Resolve-Error -ErrorInput "For topology 'async-dr', the following parameters are invalid: $($invalidParams -join ', ')." -Category InvalidArgument)
            }
        }

        if ($Topology -in @("2-site-async-dr", "2-site-ha")) {
            if ($Partition) {
                throw (Resolve-Error -ErrorInput "Parameter -Partition is only valid for topology 'async-dr'." -Category InvalidArgument)
            }

            $missingParams = $locationParams | Where-Object { -not $PSBoundParameters.ContainsKey($_) } | ForEach-Object { "-$_" }

            if ($missingParams.Count -gt 0) {
                throw (Resolve-Error -ErrorInput "For topology '$Topology', the following parameters are required: $($missingParams -join ', ')." -Category InvalidArgument)
            }
        }

        if ($Topology -ne "2-site-ha") {
            if ($PSBoundParameters.ContainsKey('Snapshots')) {
                throw (Resolve-Error -ErrorInput "Parameter -Snapshots is only valid for topology '2-site-ha'." -Category InvalidArgument)
            }
            if (-not $RpoAlert) {
                throw (Resolve-Error -ErrorInput "Parameter -RpoAlert is required when the topology is set to '2-site-async-dr' or 'async-dr'." -Category InvalidArgument)
            }
        }
        elseif ($RpoAlert) {
            throw (Resolve-Error -ErrorInput "Parameter -RpoAlert is required when the topology is set to '2-site-async-dr' or 'async-dr'." -Category InvalidArgument)
        }

        # --- Create Replication Policy ---
        if ($PSCmdlet.ShouldProcess("Replication Policy '$Name'", "Create")) {

            # --- Existence check ---
            $existing = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsreplicationpolicy" -CmdArgs ($Name)
            if ($existing) {
                if ($existing.err) {
                    throw (Resolve-Error -ErrorInput $existing -Category InvalidOperation)
                }
                Write-IBMSVLog -Level INFO -Message "Replication Policy '$Name' already exists. Returning existing object."
                return $existing
            }

            $opts = @{
                name     = $Name
                topology = $Topology
            }

            foreach ($field in @('Location1System', 'Location1IOGrp', 'Location2System', 'Location2IOGrp', 'Partition', 'RpoAlert', 'Snapshots')) {
                if ($PSBoundParameters.ContainsKey($field)) {
                    $value = $PSBoundParameters[$field]
                    if ($null -ne $value -and ($value -isnot [string] -or $value -ne '')) {
                        if ($value -is [System.Management.Automation.SwitchParameter]) {
                            $opts[$field.ToLower()] = $value.IsPresent
                        }
                        else {
                            $opts[$field.ToLower()] = $value
                        }
                    }
                }
            }

            $result = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "mkreplicationpolicy" -CmdOpts $opts
            if ($result.err) {
                throw (Resolve-Error -ErrorInput $result -Category InvalidOperation)
            }
            Write-IBMSVLog -Level INFO -Message "Replication Policy '$Name' created successfully."

            $current = Invoke-IBMSVRestRequest -Cluster $Cluster -Cmd "lsreplicationpolicy" -CmdArgs ($Name)
            if ($current -and $current.err) {
                throw (Resolve-Error -ErrorInput $current -Category InvalidOperation)
            }
            return $current
        }
    }
}
