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
3. Write a stable `positron-<cluster>` alias to your local `~/.ssh/config`
4. Print recommended Positron settings

## Reconnecting Without Editing

Every job lands on a different compute node, but the alias written in step 3 resolves
the current node automatically. After setup you never edit `~/.ssh/config` again — just
submit a job and connect to `positron-alpine` (or `positron-bodhi`) in Positron.

The alias uses a dynamic `ProxyCommand` that runs `squeue` on the login node to find
your running Positron job, so it requires `nc` (netcat) on the login node — available by
default on the CURC and AMC login nodes. Host-key checking is disabled for this alias
because the underlying compute node changes between jobs.

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
