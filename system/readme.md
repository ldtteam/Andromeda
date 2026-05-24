## Andromeda system.
This part of the repository will contain an Ansible workspace for managing the Nodes and VMs.

### Hardware
- Mikrotik RouterOS box as primary Firewall
- 4 Proxmox Nodes
  - Adhil: _10.2.0.2/16_
  - Nembus: _10.3.0.2/16_
  - Titawin: _10.1.0.2/16_
  - Veritate: _10.4.0.2/16_

#### Proxmox cluster
All four proxmox hardware nodes are bound together into one Datacenter, but do not use CEPH for cluster storage sharing or loadbalancing.
The nodes are configured as follows:
- Adhil contains VMs in the Proxmox id range: 3000-3999 for the kubernetes nodes, and 1001 for the rancher contol node, last but not least 9000-9999 for the template VMs
- Nembus contains VMs in the Proxmox id range: 4000-4999 for the kubernetes nodes, and 1002 for the rancher control node, last but not least 10000-10999 for the template VMs
- Titawin contains VMs in the Proxmox id range: 2000-2999 for the kubernetes nodes, and 1000 for the rancher control node, last but not least 8000-8999 for the template VMs
- Veritate contains VMS in the Proxmox id range: 5000-5999 for the kubernetes nodes, and 1003 for the rancher control node, last but not least 11000-11999 for the template VMs

Sometimes a temporary VM might also be present on each machine to handle other workloads.

### Virtual Machines:
Each hardware node based on proxmox runs the same workload, a rancher control node for the rancher control cluster, and a set of 4 andromeda kubernetes cluster nodes, based on RKE2 in an HA setup.
Those four cluster operation nodes can be split into two categories:
- System, containing the Kubernetes cluster and brainpower
- Worker, running the applications

### Maintenance automation
- Node package updates (existing): `scripts/update-kubernetes-nodes.sh`
- Worker disk expansion (new): `scripts/expand-kubernetes-worker-disks.sh`

#### Expand worker VM disks
This operation runs one worker node at a time and performs:
1. `kubectl drain` of the worker node
2. `qm disk resize` on its mapped Proxmox host
3. Partition/filesystem growth inside the VM
4. Optional reboot, then `kubectl uncordon`

Prerequisite:
- Define `proxmox_vmid` and `proxmox_host` on each worker host in `inventory/kubernetes.yml`.
  Worker names are not used to infer VM IDs.

Example:
```bash
./scripts/expand-kubernetes-worker-disks.sh --size 20G
```

Common options:
- `--limit <pattern>` target subset of workers
- `--skip-nodes <n1,n2>` exclude specific workers
- `--force-reboot` reboot after expansion
- `--extra-vars key=value` pass extra Ansible vars
