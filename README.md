# Positron over Remote SSH

Launch [Positron](https://github.com/posit-dev/positron) on Alpine (CU Boulder) or amc-bodhi (CU Anschutz) HPC clusters.

## Overview

This script allocates a compute node on your HPC cluster and provides SSH connection instructions for remote development with Positron. It uses a ProxyJump SSH configuration to connect through the login node to your allocated compute node.

- **Alpine** (CU Boulder): Uses SLURM job scheduler
- **amc-bodhi** (CU Anschutz): Uses SLURM job scheduler

## Prerequisites

- Access to Alpine or amc-bodhi HPC cluster
- Positron installed on your local machine
- SSH key configured for cluster access
- **amc-bodhi only**: Connected to AMC VPN

## Setup (One-time)

Run the setup command from your **local machine**:

```bash
# For Alpine:
./positron-remote.sh setup alpine

# For amc-bodhi:
./positron-remote.sh setup bodhi
```

This will:
1. Copy your local SSH public key to the cluster (via `ssh-copy-id`)
2. Create a Positron Server symlink on scratch storage (Alpine only — `$HOME` has limited space, `/scratch/alpine` has more room)
3. Print recommended Positron settings

**Important notes (Alpine):**
- `/scratch/alpine` is purged every 90 days of files not accessed
- If the directory is purged, Positron will automatically reinstall the server when you next connect
- You may need to re-run `./positron-remote.sh setup alpine` to recreate the symlink
- For more details on how Positron Remote-SSH works, see: https://positron.posit.co/remote-ssh.html#how-it-works-troubleshooting

### Recommended Positron Settings

By default, R and Python sessions terminate when Positron disconnects. On HPC, brief network interruptions are common and you don't want to lose your session within a running SLURM allocation. Add this to your Positron `settings.json` (local machine):

```json
{
    "kernelSupervisor.shutdownTimeout": "never"
}
```

This keeps R/Python sessions alive on the remote host so you can reconnect without losing your work.

## Quick Start (Alpine)

### 1. Submit the job to Alpine

```bash
./positron-remote.sh alpine
```

### 2. Check job status

```bash
squeue -u $USER
```

Wait until your job is in the "R" (running) state.

### 3. View connection instructions

   ```bash
   cat logs/positron-<JOB_ID>.out
   ```

Replace `<JOB_ID>` with your actual job ID from `squeue`.

### 4. Connect from Positron

- Open Positron on your **local machine**
   - Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
   - Select "Remote-SSH: Open SSH Configuration File"
- Paste in your SSH config (from the log file) and save:

  ```
  Host positron-alpine-<JOB_ID>
      HostName <compute-node>
      User <your-username>
      ProxyJump <your-username>@login-ci.rc.colorado.edu
      ForwardAgent yes
      ServerAliveInterval 60
      ServerAliveCountMax 3
  ```

- Select "Remote-SSH: Connect to Host"
- Choose `positron-alpine-<JOB_ID>` from the list
- Positron will install its server components on the remote node automatically

### 5. When finished

Always cancel your job to free resources:
   ```bash
   scancel <JOB_ID>
   ```

## Quick Start (amc-bodhi)

**Important:** You must be connected to the AMC VPN before proceeding.

### 1. Submit the job to amc-bodhi

```bash
./positron-remote.sh bodhi
```

### 2. Check job status

```bash
squeue -u $USER
```

Wait until your job is in the "R" (running) state.

### 3. View connection instructions

```bash
cat logs/positron-<JOB_ID>.out
```

Replace `<JOB_ID>` with your actual job ID from `squeue`.

### 4. Connect from Positron

- Open Positron on your **local machine**
   - Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
   - Select "Remote-SSH: Open SSH Configuration File"
- Paste in your SSH config (from the log file) and save:

  ```
  Host positron-bodhi-<JOB_ID>
      HostName <compute-node>
      User <your-username>
      ProxyJump <your-username>@amc-bodhi.ucdenver.pvt
      ForwardAgent yes
      ServerAliveInterval 60
      ServerAliveCountMax 3
  ```

- Select "Remote-SSH: Connect to Host"
- Choose `positron-bodhi-<JOB_ID>` from the list
- Positron will install its server components on the remote node automatically

### 5. When finished

Always cancel your job to free resources:
```bash
scancel <JOB_ID>
```

## Configuration

Resources are configured via SLURM directives in `positron-remote.sh`. Default values per cluster:

| Setting | Alpine | amc-bodhi |
|---------|--------|-----------|
| `--time` | 8 hours | 8 hours |
| `--mem` | 24 GB | 20 GB |
| `--partition` | amilan | normal |
| `--qos` | normal | normal |

See [Alpine documentation](https://curc.readthedocs.io/en/latest/compute/alpine.html) for available options.

## Troubleshooting

### Job won't start
- Check queue status: `squeue -u $USER`
- Check available resources: `sinfo`
- Verify your account has hours: `curc-quota`

### Can't connect via SSH
- Ensure SSH config was added to your **local** `~/.ssh/config` (not on Alpine)
- Verify job is running: `squeue -u $USER`
- Check log file for correct hostname and job ID
- Verify your local SSH public key is on the cluster (re-run `./positron-remote.sh setup alpine`)

### Connection drops
- SSH connection may timeout if idle. The job itself will continue running.
- Reconnect using the same SSH host entry.
- The SSH config generated by the script includes `ServerAliveInterval` and `ServerAliveCountMax` to reduce idle timeouts.

### Connection fails after updating Positron
- The Positron client and server must be **exactly the same version**. If you update Positron on your local machine, the remote `~/.positron-server` may have an old version.
- Delete the remote server and reconnect:
  ```bash
  # On Alpine:
  rm -rf /scratch/alpine/${USER}/.positron-server
  # Or if not using the scratch symlink:
  rm -rf ~/.positron-server
  ```
- Positron will automatically reinstall the correct server version on reconnect.

### Extensions missing in remote session
- Extensions installed on your local machine are not automatically available on the remote host.
- After connecting to a remote session, install any needed extensions from the Extensions panel — they will be installed on the remote server.

### R interpreter not discovered

R interpreter discovery can be unreliable on remote systems. If you don't see R under "Start Session" (even though Python interpreters appear):

**If you find you are able to use R versions available in the modules system, please let me know.**

1. **Install R through mamba/conda** on the remote system:
   ```bash
   mamba install -c conda-forge r-base
   ```

2. **Enable conda discovery** in Positron settings (on your local machine):
   - Press `Cmd+,` (Mac) or `Ctrl+,` (Windows/Linux) to open Settings
   - Search for "Positron R Interpreters Conda Discovery"
   - Enable the checkbox, or add to your `settings.json`:
     ```json
     {
         "positron.r.interpreters.condaDiscovery": true
     }
     ```

3. **Manually trigger interpreter discovery**:
   - Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
   - Select "Interpreter: Discover all interpreters"

After these steps, R should appear in the interpreter dropdown and start successfully.

**Note:** There are multiple discussions in the [Positron repository](https://github.com/posit-dev/positron/discussions) about interpreter discovery issues, though solutions may vary by system configuration.

## Notes

- The compute node allocation will run for the full time requested or until you cancel it
- Always remember to `scancel` your job when done to free resources
- Log files are stored in the `logs/` directory with the pattern `positron-<JOB_ID>.out`

## Resources

- [Alpine Documentation](https://curc.readthedocs.io/en/latest/compute/alpine.html)
- [Positron Documentation](https://github.com/posit-dev/positron)
- [Positron Remote SSH Documentation](https://positron.posit.co/remote-ssh.html)
- [CU Research Computing Support](https://curc.readthedocs.io/)
