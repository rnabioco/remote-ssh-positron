# Positron Remote SSH

Launch [Positron](https://github.com/posit-dev/positron) on **Alpine** (CU Boulder) or **amc-bodhi** (CU Anschutz) HPC clusters with a single command.

---

## How It Works

The script allocates a compute node on your HPC cluster via SLURM and provides SSH connection instructions for remote development with Positron. It uses a **ProxyJump** SSH pattern to connect through the login node to your allocated compute node.

```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│  Your Machine│──SSH──▶│  Login Node  │──SSH──▶│ Compute Node │
│  (Positron)  │       │  (gateway)   │       │ (workspace)  │
└──────────────┘       └──────────────┘       └──────────────┘
```

The workflow is three steps:

1. **Setup** — copy SSH keys and configure scratch storage (once per cluster)
2. **Submit** — run the script on the cluster to allocate a compute node
3. **Connect** — paste the SSH config into Positron and connect

## Supported Clusters

| Cluster | Institution | Partition | Memory | CPUs | VPN Required |
|---------|-------------|-----------|--------|------|--------------|
| **Alpine** | CU Boulder Research Computing | `amilan` | 24 GB | 4 | No |
| **amc-bodhi** | CU Anschutz Medical Campus | `positron` | 24 GB | 8 | Yes |

## Prerequisites

- Access to Alpine or amc-bodhi HPC cluster
- [Positron](https://github.com/posit-dev/positron) installed on your local machine
- SSH key configured for cluster access
- **amc-bodhi only**: Connected to AMC VPN

## Get Started

Head to the [Quick Start](quickstart.md) guide to get up and running, or run [Setup](setup.md) if this is your first time.
