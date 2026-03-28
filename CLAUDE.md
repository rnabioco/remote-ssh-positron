# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains SLURM batch scripts for launching Positron (an IDE) on Alpine (CU Boulder) and amc-bodhi (CU Anschutz) HPC clusters. The scripts allocate compute resources and provide SSH connection instructions for remote development.

## Architecture

The repository is intentionally minimal:

- `positron-remote-alpine.sh`: SLURM batch script for Alpine (CU Boulder)
- `positron-remote-bodhi.sh`: SLURM batch script for amc-bodhi (CU Anschutz)
- Both scripts use a ProxyJump SSH configuration pattern to connect through the login node to the allocated compute node

## Usage

Submit the job to Alpine (the script self-submits to SLURM):
```bash
./positron-remote-alpine.sh
```
or
```bash
bash positron-remote-alpine.sh
```

The script will display the job ID and tell you where to find the connection info once the job starts.

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

The SLURM directives in `positron-remote-alpine.sh` control resource allocation:

- `--time`: Maximum job duration (currently 8 hours)
- `--mem`: Memory allocation (currently 24gb)
- `--cpus-per-task`: Number of CPU cores (currently 4)
- `--partition`: Alpine partition (amilan for general compute)
- `--qos`: Quality of service tier

These parameters should be adjusted based on computational requirements. Alpine documentation: https://curc.readthedocs.io/en/latest/compute/alpine.html

## How It Works

When you run `./positron-remote-alpine.sh`:
1. The script checks if it's running under SLURM (via the `POSITRON_SLURM_EXEC` environment variable)
2. If not, it submits itself to SLURM using `sbatch` and exits, displaying the job ID and log location
3. When SLURM runs the script on a compute node, it displays the SSH connection info in the log file

## SSH Configuration Pattern

The script generates a temporary SSH config entry using:
1. **ProxyJump**: Routes connection through `login-ci.rc.colorado.edu`
2. **Dynamic hostname**: Uses the allocated compute node's hostname
3. **Job-specific alias**: `positron-alpine-${SLURM_JOB_ID}` for easy identification
4. **ForwardAgent**: Enables SSH agent forwarding for git operations on the compute node

This pattern enables Positron's Remote-SSH extension to connect directly to the compute node while respecting Alpine's security model.

## Prerequisites

- Positron or VS Code with Remote-SSH extension (recommended in `.vscode/extensions.json`)
- SSH key configured for Alpine access (must be in Alpine's `~/.ssh/authorized_keys`)
- Access to Alpine HPC cluster
