# Positron Remote SSH

Launch [Positron](https://github.com/posit-dev/positron) on **Alpine** (CU Boulder) or **amc-bodhi** (CU Anschutz) HPC clusters with a single command.

---

## How It Works

The script allocates a compute node on your HPC cluster via SLURM and provides SSH connection instructions for remote development with Positron. It uses a **ProxyJump** SSH pattern to connect through the login node to your allocated compute node. See the [Positron Remote SSH docs](https://positron.posit.co/remote-ssh.html) for more on how Remote SSH works.

```mermaid
graph LR
  A["🖥️ Your Machine\n(Positron)"] -->|SSH| B["🌐 Login Node\n(gateway)"]
  B -->|ProxyJump| C["⚡ Compute Node\n(workspace)"]
```

The workflow is three steps:

1. **Setup** — copy SSH keys, configure scratch storage, and write a reusable SSH alias (once per cluster)
2. **Submit** — run the script on the cluster to allocate a compute node
3. **Connect** — choose the `positron-<cluster>` alias in Positron and connect

!!! info "Resource enforcement"
    Positron connects by SSH-ing directly to the compute node. Whether the
    `positron-server` process is held to your allocation's CPU/memory limits depends on
    the cluster running [`pam_slurm_adopt`](https://slurm.schedmd.com/pam_slurm_adopt.html),
    which adopts inbound SSH sessions into your running job. To verify, run
    `cat /proc/self/cgroup` in a Positron terminal after connecting — an adopted session
    shows a path containing `job_<your-job-id>`.

## Supported Clusters

| Cluster | Institution | Partition | Memory | CPUs | Time | VPN Required |
|---------|-------------|-----------|--------|------|------|--------------|
| **Alpine** | CU Boulder Research Computing | `amilan` | 24 GB | 8 | 24 h | No |
| **amc-bodhi** | CU Anschutz Medical Campus | `positron` | 24 GB | 8 | 8 h | Yes |

## Prerequisites

- Access to Alpine or amc-bodhi HPC cluster
- [Positron](https://github.com/posit-dev/positron) installed on your local machine
- SSH key configured for cluster access
- **amc-bodhi only**: Connected to AMC VPN

## Get Started

Head to the [Quick Start](quickstart.md) guide to get up and running, or run [Setup](setup.md) if this is your first time.
