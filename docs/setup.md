# Setup

One-time setup to configure SSH access and scratch storage.

## Run Setup

From your **local machine**, run:

=== "Alpine"

    ```bash
    ./positron-remote.sh setup alpine
    ```

=== "amc-bodhi"

    ```bash
    ./positron-remote.sh setup bodhi
    ```

!!! note "amc-bodhi"
    You must be connected to the **AMC VPN** before running setup for amc-bodhi.

Setup will:

1. Copy your local SSH public key to the cluster (via `ssh-copy-id`)
2. Create a Positron Server symlink on scratch storage (Alpine only)
3. Print recommended Positron settings

## Recommended Positron Settings

By default, R and Python sessions terminate when Positron disconnects. On HPC, brief network interruptions are common and you don't want to lose your session within a running SLURM allocation.

Add this to your Positron `settings.json` (on your **local machine**):

```json
{
    "kernelSupervisor.shutdownTimeout": "never"
}
```

This keeps R/Python sessions alive on the remote host so you can reconnect without losing your work.

## Alpine Scratch Storage

!!! warning "Scratch purge policy"
    `/scratch/alpine` is purged every **90 days** for files not accessed. If the directory is purged, Positron will automatically reinstall the server when you next connect. You may need to re-run `./positron-remote.sh setup alpine` to recreate the symlink.

The setup command creates a symlink from `~/.positron-server` to `/scratch/alpine/$USER/.positron-server` because Alpine home directories have limited space.

For more details on how Positron Remote-SSH works, see the [Positron Remote SSH documentation](https://positron.posit.co/remote-ssh.html#how-it-works-troubleshooting).
