# Alpine Positron

Launch [Positron](https://github.com/posit-dev/positron) on Alpine (CU Boulder) or amc-bodhi (CU Anschutz) HPC clusters.

## Overview

These scripts allocate a compute node on your HPC cluster and provide SSH connection instructions for remote development with Positron. The scripts use a ProxyJump SSH configuration to connect through the login node to your allocated compute node.

- **Alpine** (CU Boulder): Uses SLURM job scheduler (`alpine-positron.sh`)
- **amc-bodhi** (CU Anschutz): Uses LSF job scheduler (`bodhi-positron.sh`)

## Prerequisites

- Access to Alpine or amc-bodhi HPC cluster
- Positron installed on your local machine
- SSH key configured for cluster access
- **amc-bodhi only**: Connected to AMC VPN

## Setup (One-time)

### 1. Add your local machine's SSH key to Alpine

If you haven't already, you need to add your local machine's public SSH key to Alpine's authorized_keys file. This allows your local machine to authenticate with Alpine compute nodes via the ProxyJump connection.

1. **On your local machine**, copy your public key:
   ```bash
   cat ~/.ssh/id_rsa.pub
   ```
   Or if you use a different key:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

2. **Log into Alpine** and add the key to authorized_keys:
   ```bash
   ssh <your-username>@login.rc.colorado.edu
   ```

3. **On Alpine**, add your public key:
   ```bash
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   echo "your-public-key-content" >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

   Replace `your-public-key-content` with the output from step 1.

### 2. Configure Positron Server location on Alpine

By default, Positron installs its server components to `~/.positron-server`, but `$HOME` on Alpine has limited space. To avoid filling up your home directory, set up Positron Server on `/scratch/alpine`:

**On Alpine** (login or compute node):
```bash
# Create directory on scratch (larger allocation)
mkdir -p /scratch/alpine/${USER}/.positron-server

# Create symlink from home to scratch
ln -s /scratch/alpine/${USER}/.positron-server ~/.positron-server
```

**Important notes:**
- `/scratch/alpine` is purged every 90 days of files not accessed
- If the directory is purged, Positron will automatically reinstall the server when you next connect
- You may need to recreate the symlink if it's removed: `ln -s /scratch/alpine/${USER}/.positron-server ~/.positron-server`
- For more details on how Positron Remote-SSH works, see: https://positron.posit.co/remote-ssh.html#how-it-works-troubleshooting

## Quick Start (Alpine)

### 1. Submit the job to Alpine

```bash
sbatch alpine-positron.sh
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
  Host positron-<JOB_ID>
      HostName <compute-node>
      User <your-username>
      ProxyJump <your-username>@login-ci.rc.colorado.edu
  ```

- Select "Remote-SSH: Connect to Host"
- Choose `positron-<JOB_ID>` from the list
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
bsub < bodhi-positron.sh
```

### 2. Check job status

```bash
bjobs
```

Wait until your job is in the "RUN" state.

### 3. View connection instructions

```bash
cat logs/positron-<JOB_ID>.out
```

Replace `<JOB_ID>` with your actual job ID from `bjobs`.

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
  ```

- Select "Remote-SSH: Connect to Host"
- Choose `positron-bodhi-<JOB_ID>` from the list
- Positron will install its server components on the remote node automatically

### 5. When finished

Always cancel your job to free resources:
```bash
bkill <JOB_ID>
```

## Configuration

### Alpine (`alpine-positron.sh`)

Resources are configured via SLURM directives:

- `--time=08:00:00` - Maximum job duration (8 hours)
- `--mem=20gb` - Memory allocation (20 GB)
- `--partition=amilan` - Alpine partition for general compute
- `--qos=normal` - Quality of service tier

See [Alpine documentation](https://curc.readthedocs.io/en/latest/compute/alpine.html) for available options.

### amc-bodhi (`bodhi-positron.sh`)

Resources are configured via LSF directives:

- `-W 8:00` - Maximum job duration (8 hours)
- `-R "rusage[mem=20000]"` - Memory allocation (20 GB)
- `-q normal` - Queue for general compute
- `-n 1` - Number of tasks

## Troubleshooting

### Job won't start
- Check queue status: `squeue -u $USER`
- Check available resources: `sinfo`
- Verify your account has hours: `curc-quota`

### Can't connect via SSH
- Ensure SSH config was added to your **local** `~/.ssh/config` (not on Alpine)
- Verify job is running: `squeue -u $USER`
- Check log file for correct hostname and job ID
- Verify your local SSH public key is in Alpine's `~/.ssh/authorized_keys` (see Setup section)

### Connection drops
- SSH connection may timeout if idle. The job itself will continue running.
- Reconnect using the same SSH host entry.

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
