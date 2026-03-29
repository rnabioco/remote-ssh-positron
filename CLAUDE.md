# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains a unified SLURM batch script for launching Positron (an IDE) on Alpine (CU Boulder) and amc-bodhi (CU Anschutz) HPC clusters. The script allocates compute resources, provides SSH connection instructions, and includes a one-time setup subcommand.

## Architecture

The repository is intentionally minimal:

- `positron-remote.sh`: Unified SLURM batch script supporting both Alpine and amc-bodhi clusters
  - Cluster-specific config (partition, memory, proxy host) via a `case` statement
  - `setup` subcommand automates SSH key exchange and scratch symlink creation
  - Cluster is selected via argument: `./positron-remote.sh alpine` or `./positron-remote.sh bodhi`
- Uses a ProxyJump SSH configuration pattern to connect through the login node to the allocated compute node

## Usage

Submit the job (the script self-submits to SLURM):
```bash
./positron-remote.sh alpine    # Alpine (default)
./positron-remote.sh bodhi     # amc-bodhi
```

One-time setup (run from local machine):
```bash
./positron-remote.sh setup alpine
./positron-remote.sh setup bodhi
```

Monitor job status:
```bash
squeue -u $USER
```

Cancel the job when done:
```bash
scancel <JOB_ID>
```

View connection info:
```bash
cat logs/positron-<JOB_ID>.out
```

## Key Configuration Parameters

Cluster-specific SLURM settings are passed via `sbatch` CLI overrides:

- `--time`: Maximum job duration (currently 8 hours)
- `--mem`: Memory allocation (24gb Alpine, 20gb bodhi)
- `--cpus-per-task`: Number of CPU cores (currently 4)
- `--partition`: Cluster partition (amilan for Alpine, normal for bodhi)
- `--qos`: Quality of service tier

These parameters should be adjusted based on computational requirements. Alpine documentation: https://curc.readthedocs.io/en/latest/compute/alpine.html

## How It Works

When you run `./positron-remote.sh alpine`:
1. The script checks if it's running under SLURM (via the `POSITRON_SLURM_EXEC` environment variable)
2. If not, it submits itself to SLURM using `sbatch` with cluster-specific overrides and exits
3. The cluster name is passed to the SLURM execution via `POSITRON_CLUSTER` environment variable
4. When SLURM runs the script on a compute node, it displays the SSH connection info in the log file

## SSH Configuration Pattern

The script generates a temporary SSH config entry using:
1. **ProxyJump**: Routes connection through the cluster's login node
2. **Dynamic hostname**: Uses the allocated compute node's hostname
3. **Job-specific alias**: `positron-{alpine|bodhi}-${SLURM_JOB_ID}` for easy identification
4. **ForwardAgent**: Enables SSH agent forwarding for git operations on the compute node

This pattern enables Positron's Remote-SSH extension to connect directly to the compute node while respecting the cluster's security model.

## Prerequisites

- Positron or VS Code with Remote-SSH extension (recommended in `.vscode/extensions.json`)
- SSH key configured for cluster access (use `./positron-remote.sh setup` to automate)
- Access to Alpine or amc-bodhi HPC cluster
