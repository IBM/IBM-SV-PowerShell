[CmdletBinding()]
param(
    [string]$InventoryPath
)

if (-not (Get-Module -ListAvailable -Name IBMStorageVirtualize)) {
    Import-Module IBMStorageVirtualize -ErrorAction Stop
}

# --- Load inventory file ---------------------------------
if (-not $InventoryPath) {
    throw "InventoryPath parameter is required. Please provide the path to the inventory file."
}
if (-not (Test-Path -LiteralPath $InventoryPath -PathType Leaf)) {
    throw "No inventory file found at '$InventoryPath'."
}

$Inventory = Get-Content -LiteralPath $InventoryPath -Raw | ConvertFrom-Json -AsHashtable

# --- Default settings -------------------
if (-not $Inventory.TruststoreName) { $Inventory.TruststoreName = "ts_dr0" }
if (-not $Inventory.Partnership.LinkBandwidthMbits) { $Inventory.Partnership.LinkBandwidthMbits = 100 }
if (-not $Inventory.ReplicationPolicyName) { $Inventory.ReplicationPolicyName = "dr_policy0" }
if (-not $Inventory.RpoAlertSeconds) { $Inventory.RpoAlertSeconds = 60 }

# --- Build credentials from inventory values --------------------------------
$PrimaryCredential = [pscredential]::new(
    $Inventory.Clusters[0].Username,
    (ConvertTo-SecureString $Inventory.Clusters[0].Password -AsPlainText -Force)
)
$SecondaryCredential = [pscredential]::new(
    $Inventory.Clusters[1].Username,
    (ConvertTo-SecureString $Inventory.Clusters[1].Password -AsPlainText -Force)
)
$PrimaryClusterIP = $Inventory.Clusters[0].IP
$SecondaryClusterIP = $Inventory.Clusters[1].IP

# ===========================================================================
Write-Host "Fetch auth tokens and connect to both clusters"

Connect-IBMStorageVirtualize -Cluster $PrimaryClusterIP   -Credential $PrimaryCredential   -AllowCredentialCaching -AutoAddHostKey -Primary
Connect-IBMStorageVirtualize -Cluster $SecondaryClusterIP -Credential $SecondaryCredential -AllowCredentialCaching -AutoAddHostKey

# ===========================================================================
Write-Host "Create truststore on both systems"

New-IBMSVTruststore `
    -Name          $Inventory.TruststoreName `
    -RemoteCluster $SecondaryClusterIP | Out-Null

# ===========================================================================
Write-Host "Create partnership on both systems"

if ($Inventory.Partnership.Type -eq 'FC') {
    New-IBMSVPartnership `
        -Type               'FC' `
        -RemoteCluster      $SecondaryClusterIP `
        -LinkBandwidthMbits $Inventory.Partnership.LinkBandwidthMbits | Out-Null
}
else {
    for ($i = 0; $i -lt $Inventory.Clusters.Count; $i++) {
        $cluster = $Inventory.Clusters[$i]
        $ipParam = $Inventory.Partnership.IPParameters[$i]

        New-IBMSVPortset `
            -Name    $Inventory.Partnership.PortsetName `
            -Type    'highspeedreplication' `
            -Cluster $cluster.IP | Out-Null

        New-IBMSVIP `
            -IPAddress    $ipParam.IP `
            -Node         $ipParam.NodeName `
            -Port         $ipParam.PortID `
            -Vlan         $ipParam.Vlan `
            -SubnetPrefix $ipParam.SubnetPrefix `
            -Portset      $Inventory.Partnership.PortsetName `
            -Cluster      $cluster.IP | Out-Null
    }

    New-IBMSVPartnership `
        -Type               'IP' `
        -RemoteCluster      $SecondaryClusterIP `
        -Link1              $Inventory.Partnership.PortsetName `
        -LinkBandwidthMbits $Inventory.Partnership.LinkBandwidthMbits | Out-Null
}

# ===========================================================================
Write-Host "Enable PBR on partnership on both sides"

Set-IBMSVPartnership `
    -RemoteCluster $SecondaryClusterIP `
    -PBRinUse      'yes'

# ===========================================================================
Write-Host "Set up replication pool link on secondary cluster"

$replicationPoolLinkUid = (Get-IBMSVPool -ObjectName $Inventory.Pools[0]).replication_pool_link_uid

Set-IBMSVPool `
    -Cluster                $SecondaryClusterIP `
    -Name                   $Inventory.Pools[1] `
    -ReplicationPoolLinkUid $replicationPoolLinkUid

# ===========================================================================

$primaryClusterId = (Get-IBMSVSystem).id
$secondaryClusterId = (Get-IBMSVSystem -Cluster $SecondaryClusterIP).id

if ($Inventory.PartitionName) {
    Write-Host "Create partition '$($Inventory.PartitionName)' on both clusters"

    New-IBMSVPartition `
        -Name  $Inventory.PartitionName `
        -Draft | Out-Null

    $remotePartitionData = New-IBMSVPartition `
        -Cluster $SecondaryClusterIP `
        -Name    $Inventory.PartitionName
}

# ===========================================================================

if (-not $Inventory.VolumeGroupName -and $Inventory.Volumes) {
    Write-Host "Create volume group (vg_<first_volume_name>)"

    $Inventory.VolumeGroupName = "vg_$($Inventory.Volumes[0])"

    New-IBMSVVolumeGroup `
        -Name      $Inventory.VolumeGroupName | Out-Null
}

# ===========================================================================
if ($Inventory.Volumes) {
    Write-Host "Move volumes to volume group '$($Inventory.VolumeGroupName)'"

    foreach ($vol in $Inventory.Volumes) {
        Set-IBMSVVolume `
            -Name        $vol `
            -VolumeGroup $Inventory.VolumeGroupName
    }
}

# ===========================================================================
if ($Inventory.PartitionName) {
    if ($Inventory.VolumeGroupName) {
        Write-Host "Move volume group '$($Inventory.VolumeGroupName)' to partition '$($Inventory.PartitionName)'"
        Set-IBMSVVolumeGroup `
            -Name           $Inventory.VolumeGroupName `
            -DraftPartition $Inventory.PartitionName
    }

    Write-Host "Publish partition '$($Inventory.PartitionName)' on primary cluster"
    Set-IBMSVPartition `
        -Name    $Inventory.PartitionName `
        -Publish

    Write-Host "Set DR-Link partition UUID on primary cluster"
    Set-IBMSVPartition `
        -Name                $Inventory.PartitionName `
        -DRLinkPartitionUUID $remotePartitionData.uuid `
        -RemoteSystem        $secondaryClusterId
}

# ===========================================================================

if ($Inventory.PartitionName) {
    Write-Host "Create 'async-dr' replication policy '$($Inventory.ReplicationPolicyName)' on primary cluster with partition '$($Inventory.PartitionName)'"
    New-IBMSVReplicationPolicy `
        -Name      $Inventory.ReplicationPolicyName `
        -Partition $Inventory.PartitionName `
        -Topology  'async-dr' `
        -RpoAlert  $Inventory.RpoAlertSeconds | Out-Null
}
else {
    Write-Host "Create '2-site-async-dr' replication policy '$($Inventory.ReplicationPolicyName)' on primary cluster"
    New-IBMSVReplicationPolicy `
        -Name            $Inventory.ReplicationPolicyName `
        -Topology        '2-site-async-dr' `
        -Location1System $primaryClusterId `
        -Location1IOGrp  0 `
        -Location2System $secondaryClusterId `
        -Location2IOGrp  0 `
        -RpoAlert        $Inventory.RpoAlertSeconds | Out-Null
}

# ===========================================================================

if ($Inventory.VolumeGroupName) {
    Write-Host "Assign replication policy to volume group '$($Inventory.VolumeGroupName)'"
    Set-IBMSVVolumeGroup `
        -Name              $Inventory.VolumeGroupName `
        -ReplicationPolicy $Inventory.ReplicationPolicyName
}

Write-Host "PBR setup complete. This starts data-sync."

Disconnect-IBMStorageVirtualize -Cluster $PrimaryClusterIP
Disconnect-IBMStorageVirtualize -Cluster $SecondaryClusterIP
