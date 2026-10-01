# PowerShell Script to Set Up Policy-Based Replication (PBR)

## Table of Contents

- [Objective](#objective)
- [Prerequisites](#prerequisites)
- [Overview](#overview)
- [Tasks Performed](#tasks-performed)
- [Inventory File](#inventory-file)

## Objective

Configure **Policy-Based Replication (PBR)** for async disaster recovery (DR) between two IBM FlashSystem clusters using the `IBMStorageVirtualize` PowerShell module.

## Prerequisites

- `IBMStorageVirtualize` PowerShell module installed:
  ```powershell
  Install-Module IBMStorageVirtualize
  ```
- Network connectivity (FC or IP) between the primary and secondary clusters.

## Overview

- `IBMSV_PBR.ps1` performs end-to-end PBR setup between two clusters, including truststore creation, partnership, partition management, and replication policy assignment. All configuration is read from a JSON inventory file. Edit inventory file with your values and run:
  ```powershell
  .\IBMSV_PBR.ps1 -InventoryPath <inventory_file_path>
  ```
- **Partition-based PBR** (set `PartitionName`): Creates a matching draft partition, optionally moves a volume group into it, publishes it on the primary, links it to the remote partition via DR-Link UUID, and creates an `async-dr` replication policy scoped to that partition. The replication policy is then assigned to the volume group.
- **Non-partition-based PBR** (omit `PartitionName`): Creates a `2-site-async-dr` replication policy referencing both cluster system IDs directly. The replication policy is then assigned to the volume group.
- Optionally, set `Volumes` and/or `VolumeGroup` to attach existing volumes/volumegroup:
  - Volumes must already exist on the primary cluster; the script does not create them.
  - If both `Volumes` and `VolumeGroup` parameters are set: volumes are moved into the specified `VolumeGroup`, which is then moved into the partition (partition mode) or kept standalone (non-partition mode). The replication policy is assigned to the `VolumeGroup`.
  - If only `Volumes` parameter is set: a volume group named `vg_<first_volume>` is auto-created, the volumes are moved into it, and the replication policy is assigned to it.
  - If only `VolumeGroup` parameter is set: the volume group is moved into the partition (partition mode) or kept standalone (non-partition mode), and the replication policy is assigned to volume group.

## Tasks Performed

- Connects to both clusters and fetches authentication tokens.
- Creates mTLS truststores on both clusters.
- Creates an FC or IP partnership between the primary and secondary clusters.
- Enables Policy-Based Replication (PBR) on the partnership on both sides.
- Performs pool linking between pools of primary and secondary clusters.
- *(Partition mode only)* Creates a draft partition on primary cluster.
- *(Optional)* Creates a volume group named `vg_<first_volume>` if `Volumes` is set but `VolumeGroup` is not.
- Moves the specified existing volumes into the volume group.
- *(Partition mode only)* Moves the volume group into the draft partition, publishes partition on the primary, and set the DR-Link partition UUID referencing the secondary cluster.
- Creates a `async-dr` replication policy scoped to the partition (partition mode) or `2-site-async-dr` referencing both cluster IDs (non-partition mode).
- *(If `VolumeGroup` is set)* Assigns the replication policy to the volume group.

## Inventory File

Configuration is defined in a JSON file passed to `-InventoryPath`. The table below describes every supported key.

| Key | Description | Default |
|---|---|---|
| `Cluster[0].IP` | IP address of the primary cluster. | — |
| `Cluster[0].Username` | Username for the primary cluster. | — |
| `Cluster[0].Password` | Password for the primary cluster. | — |
| `Cluster[1].IP` | IP address of the secondary cluster. | — |
| `Cluster[1].Username` | Username for the secondary cluster. | — |
| `Cluster[1].Password` | Password for the secondary cluster. | — |
| `TruststoreName` | Name for the truststore to be created on both clusters. | `ts_dr0` |
| `Partnership.Type` | Partnership type: `FC` or `IP`. | — |
| `Partnership.LinkBandwidthMbits` | Partnership link bandwidth in Mbits. | `100` |
| `Partnership.PortsetName` | *(IP type only)* Name of the portset to be created on each cluster. | — |
| `Partnership.IPParameters[0..1]` | *(IP type only)* Per-cluster IP settings: `IP`, `NodeName`, `PortID`, `Vlan`, `SubnetPrefix`. | — |
| `Pool[0]` | Name of the storage pool on the primary cluster. | — |
| `Pool[1]` | Name of the storage pool on the secondary cluster. | — |
| `ReplicationPolicyName` | Name of the replication policy to be created. | `rp0-dr` |
| `RpoAlertSeconds` | RPO alert threshold in seconds. | `60` |
| `PartitionName` | *(Optional)* Name of the storage partition to be created on both clusters. When set, enables partition mode (`async-dr` policy). When omitted, a `2-site-async-dr` policy is created instead. | — |
| `VolumeGroupName` | *(Optional)* Name of an existing volume group to be moved into the partition. If omitted but `Volumes` is set, volume group name is auto-generated as `vg_<first_volume>`. | — |
| `Volumes` | *(Optional)* JSON array of existing volume names to be moved into the volume group, e.g. `["vol_a","vol_b"]`. | — |
