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
if (-not $Inventory.TruststoreName) { $Inventory.TruststoreName = "ts_ha0" }
if (-not $Inventory.Partnership.LinkBandwidthMbits) { $Inventory.Partnership.LinkBandwidthMbits = 100 }
if (-not $Inventory.ReplicationPolicyName) { $Inventory.ReplicationPolicyName = "ha_policy0" }
if (-not $Inventory.QuorumFilePath) { $Inventory.QuorumFilePath = $PWD.Path }

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
Write-Host "Set up quorum application"

$primaryCluster = (Get-IBMSVSystem)
$secondaryCluster = (Get-IBMSVSystem -Cluster $SecondaryClusterIP)

New-IBMSVQuorum `
    -PartnerSystem $secondaryCluster.name `
    -OutFile       $Inventory.QuorumFilePath

# ===========================================================================
Write-Host "Create HA policy on primary cluster"

$primaryClusterId = $primaryCluster.id
$secondaryClusterId = $secondaryCluster.id

New-IBMSVReplicationPolicy `
    -Name            $Inventory.ReplicationPolicyName `
    -Topology        '2-site-ha' `
    -Location1System $primaryClusterId `
    -Location1IOGrp  0 `
    -Location2System $secondaryClusterId `
    -Location2IOGrp  0 | Out-Null

# ===========================================================================
Write-Host "Create partition '$($Inventory.PartitionName)' on primary cluster"

New-IBMSVPartition `
    -Name $Inventory.PartitionName `
    -Draft | Out-Null

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
if ($Inventory.VolumeGroupName) {
    Write-Host "Move volume group '$($Inventory.VolumeGroupName)' to partition '$($Inventory.PartitionName)'"

    Set-IBMSVVolumeGroup `
        -Name           $Inventory.VolumeGroupName `
        -DraftPartition $Inventory.PartitionName
}

# ===========================================================================
Write-Host "Publish partition '$($Inventory.PartitionName)'"

Set-IBMSVPartition `
    -Name    $Inventory.PartitionName `
    -Publish

# ===========================================================================
Write-Host "Convert a non-HA partition to HA partition (by assigning HA policy)"

Set-IBMSVPartition `
    -Name              $Inventory.PartitionName `
    -ReplicationPolicy $Inventory.ReplicationPolicyName `

Write-Host "Quorum application downloaded: $($Inventory.QuorumFilePath)"
Write-Host "PBHA setup complete. This starts data-sync."

Disconnect-IBMStorageVirtualize -Cluster $PrimaryClusterIP
Disconnect-IBMStorageVirtualize -Cluster $SecondaryClusterIP
