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

If you ran [Setup](setup.md), a stable `positron-<cluster>` alias is already in your
local `~/.ssh/config` and resolves the current node automatically — no editing needed:

1. Open Positron on your **local machine**
2. Press ++cmd+shift+p++ (Mac) or ++ctrl+shift+p++ (Windows/Linux)
3. Select **Remote-SSH: Connect to Host**
4. Choose `positron-alpine` (or `positron-bodhi`)
5. Positron will install its server components on the remote node automatically

!!! tip "Didn't run setup?"
    The log file (`cat logs/positron-<JOB_ID>.out`) also prints an explicit
    job-specific `Host` block you can paste into `~/.ssh/config` as a fallback.

## 5. Manage the Job

```bash
./positron-remote.sh status alpine    # state, node, time left
./positron-remote.sh connect alpine   # reprint connection instructions
./positron-remote.sh stop alpine      # cancel the job
```

## 6. When Finished

Always cancel your job to free resources:

```bash
./positron-remote.sh stop alpine      # or: scancel <JOB_ID>
```

!!! warning
    The compute node allocation runs for the full time requested (Alpine 24 h,
    amc-bodhi 8 h) or until you cancel it. Always stop it when done — or submit with
    `POSITRON_IDLE_TIMEOUT=<minutes>` to auto-release after an idle period.
