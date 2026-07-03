# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains a unified SLURM batch script for launching Positron (an IDE) on Alpine (CU Boulder) and amc-bodhi (CU Anschutz) HPC clusters. The script allocates compute resources, provides SSH connection instructions, and includes a one-time setup subcommand.

## Architecture

The repository is intentionally minimal:

- `positron-remote.sh`: Unified SLURM batch script supporting both Alpine and amc-bodhi clusters
  - Cluster-specific config (partition, memory, proxy host, account) via a `case` statement in `get_cluster_config()`
  - A subcommand dispatcher: `setup`, `status`, `connect`, `stop`, `reset`, plus a bare cluster arg to submit
  - `setup` automates SSH key exchange, scratch symlink creation, and writing a stable `positron-<cluster>` SSH alias to the local `~/.ssh/config`
  - Cluster is selected via argument: `./positron-remote.sh alpine` or `./positron-remote.sh bodhi`
  - The in-allocation payload traps SIGTERM for graceful `positron-server` shutdown and optionally auto-releases the node after an idle period
- Uses a ProxyJump/ProxyCommand SSH pattern to connect through the login node to the allocated compute node

## Usage

Submit the job (the script self-submits to SLURM):
```bash
./positron-remote.sh alpine    # Alpine (default)
./positron-remote.sh bodhi     # amc-bodhi
```

One-time setup (run from local machine — also writes a stable `positron-<cluster>` SSH alias to `~/.ssh/config`):
```bash
./positron-remote.sh setup alpine
./positron-remote.sh setup bodhi
```

Management subcommands (run from the cluster login node; each takes `alpine` or `bodhi`):
```bash
./positron-remote.sh status alpine    # state, node, time left
./positron-remote.sh connect alpine   # reprint connection instructions
./positron-remote.sh stop alpine      # cancel the job
./positron-remote.sh reset alpine     # wipe the remote ~/.positron-server (version drift)
```

View connection info:
```bash
cat logs/positron-<JOB_ID>.out
```

## Key Configuration Parameters

Cluster-specific SLURM settings live in `get_cluster_config()` and are passed via `sbatch` CLI overrides:

- `--time`: Maximum job duration (24h Alpine, 8h bodhi)
- `--mem`: Memory allocation (24gb Alpine, 24G bodhi)
- `--cpus-per-task`: Number of CPU cores (8 on both)
- `--partition`: Cluster partition (amilan for Alpine, positron for bodhi)
- `--qos`: Quality of service tier (normal for Alpine, positron for bodhi)

Optional environment variables (read at submit time):

- `POSITRON_ACCOUNT`: SLURM account/allocation to bill (Alpine); defaults to the user's default allocation
- `POSITRON_IDLE_TIMEOUT`: minutes with no active SSH session before the job auto-`scancel`s itself (`0` = disabled)

These parameters should be adjusted based on computational requirements. Alpine documentation: https://curc.readthedocs.io/en/latest/compute/alpine.html

## How It Works

When you run `./positron-remote.sh alpine`:
1. The script checks if it's running under SLURM (via the `POSITRON_SLURM_EXEC` environment variable)
2. If not, it submits itself to SLURM using `sbatch` with cluster-specific overrides and exits
3. The cluster name is passed to the SLURM execution via `POSITRON_CLUSTER` environment variable
4. When SLURM runs the script on a compute node, it displays the SSH connection info in the log file

## SSH Configuration Pattern

There are two connection paths:

1. **Stable alias (preferred)**: `setup` writes a `positron-<cluster>` `Host` block to the
   local `~/.ssh/config` whose `ProxyCommand` SSHes to the login node and runs `squeue` to
   resolve the *currently running* Positron node on the fly (`nc <node> 22`). This lets the
   user reconnect to any future job/node without editing SSH config. The block is written
   idempotently between `# >>> positron-remote <cluster> >>>` markers. Host-key checking is
   disabled for this alias because the underlying compute node changes between jobs.
2. **Job-specific fallback**: `show_connection_info` also prints an explicit
   `positron-<cluster>-${SLURM_JOB_ID}` block using **ProxyJump** + the allocated node's
   hostname, for users who skipped `setup`.

Both use **ForwardAgent** for git operations on the compute node. This pattern enables
Positron's Remote-SSH extension to connect directly to the compute node while respecting
the cluster's security model.

## Prerequisites

- Positron or VS Code with Remote-SSH extension (recommended in `.vscode/extensions.json`)
- SSH key configured for cluster access (use `./positron-remote.sh setup` to automate)
- Access to Alpine or amc-bodhi HPC cluster
