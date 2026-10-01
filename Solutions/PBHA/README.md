# PowerShell Script to Set Up Policy-Based High Availability (PBHA)

## Table of Contents

- [Objective](#objective)
- [Prerequisites](#prerequisites)
- [Overview](#overview)
- [Tasks Performed](#tasks-performed)
- [Inventory File](#inventory-file)

## Objective

Set up **Policy-Based High Availability (PBHA)** between two IBM FlashSystem clusters using the `IBMStorageVirtualize` PowerShell module.

## Prerequisites

- `IBMStorageVirtualize` PowerShell module installed:
  ```powershell
  Install-Module IBMStorageVirtualize
  ```
- Network connectivity (FC or IP) between the primary and secondary clusters.
- A host with a **Java Runtime Environment (JRE)** available to run the quorum application.

## Overview

- `IBMSV_PBHA.ps1` establishes PBHA between two clusters, including quorum setup, partition creation, and HA policy assignment. Configuration is read from a JSON inventory file. Edit inventory file with your values and run:
  ```powershell
  .\IBMSV_PBHA.ps1 -InventoryPath <inventory_file_path>
  ```
- `PartitionName` is **required**. A partition is always created on the primary cluster and the HA policy is assigned to it.
- Optionally, set `Volumes` and/or `VolumeGroup` to be attached to the partition:
  - Volumes must already exist on the primary cluster; the script does not create them.
  - If `Volumes` and `VolumeGroup` parameters are set: volumes are moved into the specified `VolumeGroup`, which is then moved into the partition.
  - If only `Volumes` parameter is set: a volume group named `vg_<first_volume>` is auto-created and the volumes are moved into it.
  - If only `VolumeGroup` parameter is set: volume group is moved into the partition as-is.
- The quorum application (`ip_quorum.jar`) is downloaded at the end of the script. If `QuorumFilePath` is set, the file is saved there; otherwise it is saved in the directory from where the script was executed.
- User needs to copy quorum app to the host where it should run. Start it as `java -jar ip_quorum.jar`.
- If the quorum between the clusters is ever broken, re-run task `Set up quorum application` to regenerate and re-download the file.

## Tasks Performed

- Connects to both clusters and fetches authentication tokens.
- Creates mTLS truststores on both clusters.
- Creates an FC or IP partnership between the primary and secondary clusters.
- Enables Policy-Based Replication (PBR) on the partnership on both sides.
- Performs pool linking between pools of primary and secondary clusters.
- Generates and downloads the quorum application from the primary cluster.
- Creates a `2-site-ha` replication policy referencing both cluster system IDs.
- Creates a draft storage partition on the primary cluster.
- Creates a volume group named `vg_<first_volume>` if `Volumes` is set but `VolumeGroup` is not.
- Moves the specified existing volumes into the volume group.
- *(If `VolumeGroup` is set)* Moves the volume group into the draft partition.
- Publishes the partition on the primary cluster.
- Assigns the replication policy to the partition.

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
| `TruststoreName` | Name for the truststore to be created on both clusters. | `ts_ha0` |
| `Partnership.Type` | Partnership type: `FC` or `IP`. | — |
| `Partnership.LinkBandwidthMbits` | Partnership link bandwidth in Mbits. | `100` |
| `Partnership.PortsetName` | *(IP type only)* Name of the portset to be created on each cluster. | — |
| `Partnership.IPParameters[0..1]` | *(IP type only)* Per-cluster IP settings: `IP`, `NodeName`, `PortID`, `Vlan`, `SubnetPrefix`. | — |
| `Pool[0]` | Name of the storage pool on the primary cluster. | — |
| `Pool[1]` | Name of the storage pool on the secondary cluster. | — |
| `ReplicationPolicyName` | Name of the `2-site-ha` replication policy to be created. | `ha_policy0` |
| `QuorumFilePath` | Directory path where the quorum application file is saved. | current working directory |
| `PartitionName` | **Required.** Name of the storage partition to create; the replication policy is assigned to it. | — |
| `VolumeGroupName` | *(Optional)* Name of an existing volume group to move into the partition. If omitted but `Volumes` is set, a name is auto-generated as `vg_<first_volume>`. | — |
| `Volumes` | *(Optional)* JSON array of existing volume names to move into the volume group, e.g. `["vol_a","vol_b"]`. | — |

> [!NOTE]
> The script assigns the replication policy to the partition after it is published. On IBM FlashSystem software **9.1.2 and later**, this command requires the **remote (secondary) cluster to also be running 9.1.2 or later**. If the remote cluster is on an earlier version, the command fails with:
> ```
  CMMVC1593E The command failed because the partner system is running a software version prior to 9.1.2.0.
  ```