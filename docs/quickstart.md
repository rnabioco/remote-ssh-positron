# Quick Start

!!! tip "First time?"
    Run [Setup](setup.md) before your first use.

## 1. Submit the Job

SSH into the cluster and run:

=== "Alpine"

    ```bash
    ./positron-remote.sh alpine
    ```

=== "amc-bodhi"

    ```bash
    ./positron-remote.sh bodhi
    ```

!!! note "amc-bodhi"
    You must be connected to the **AMC VPN** before submitting.

## 2. Check Job Status

```bash
squeue -u $USER
```

Wait until your job is in the **R** (running) state.

## 3. View Connection Instructions

```bash
cat logs/positron-<JOB_ID>.out
```

Replace `<JOB_ID>` with your actual job ID from `squeue`.

## 4. Connect from Positron

1. Open Positron on your **local machine**
2. Press ++cmd+shift+p++ (Mac) or ++ctrl+shift+p++ (Windows/Linux)
3. Select **Remote-SSH: Open SSH Configuration File**
4. Paste the SSH config from the log file and save:

=== "Alpine"

    ```
    Host positron-alpine-<JOB_ID>
        HostName <compute-node>
        User <your-username>
        ProxyJump <your-username>@login-ci.rc.colorado.edu
        ForwardAgent yes
        ServerAliveInterval 60
        ServerAliveCountMax 3
    ```

=== "amc-bodhi"

    ```
    Host positron-bodhi-<JOB_ID>
        HostName <compute-node>
        User <your-username>
        ProxyJump <your-username>@amc-bodhi.ucdenver.pvt
        ForwardAgent yes
        ServerAliveInterval 60
        ServerAliveCountMax 3
    ```

5. Select **Remote-SSH: Connect to Host**
6. Choose your `positron-{alpine|bodhi}-<JOB_ID>` entry
7. Positron will install its server components on the remote node automatically

## 5. When Finished

Always cancel your job to free resources:

```bash
scancel <JOB_ID>
```

!!! warning
    The compute node allocation runs for the full time requested (8 hours by default) or until you cancel it. Always `scancel` when done.
