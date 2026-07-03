# Configuration

Resources are configured via SLURM directives in `positron-remote.sh`.

## Default Settings

| Setting | Alpine | amc-bodhi |
|---------|--------|-----------|
| `--time` | 24 hours | 8 hours |
| `--mem` | 24 GB | 24 GB |
| `--partition` | `amilan` | `positron` |
| `--qos` | `normal` | `positron` |
| `--cpus-per-task` | 8 | 8 |

## Billing Account (Alpine)

Alpine jobs bill against a project allocation. If you belong to more than one, set
which account to charge with the `POSITRON_ACCOUNT` environment variable:

```bash
POSITRON_ACCOUNT=ucb-general ./positron-remote.sh alpine
```

If unset, SLURM uses your default allocation. List your accounts with
`sacctmgr show assoc user=$USER format=account -n -p` or `curc-quota`.

## Idle Auto-Release (optional)

By default the allocation is held for the full `--time`. To automatically `scancel`
the job after a period with no active SSH session (freeing core-hours if you forget to
stop it), set `POSITRON_IDLE_TIMEOUT` to a number of minutes:

```bash
POSITRON_IDLE_TIMEOUT=30 ./positron-remote.sh alpine
```

Use a generous value — a brief network drop counts as idle. `0` (the default) disables it.

## Customizing Resources

Edit `positron-remote.sh` and modify the `get_cluster_config()` function to change the defaults for your cluster. The relevant variables are:

- `PARTITION` — SLURM partition name
- `QOS` — Quality of service tier
- `MEM` — Memory allocation
- `CPUS` — Number of CPU cores

The SLURM header directives (`#SBATCH`) set the base defaults, and the cluster-specific overrides are passed via `sbatch` CLI arguments at submission time.

## Installation

You can install the script to `~/.local/bin` for easy access:

```bash
make install
```

To uninstall:

```bash
make uninstall
```

## Resources

- [Alpine Documentation](https://curc.readthedocs.io/en/latest/compute/alpine.html)
- [Positron Documentation](https://github.com/posit-dev/positron)
- [Positron Remote SSH Documentation](https://positron.posit.co/remote-ssh.html)
- [CU Research Computing](https://curc.readthedocs.io/)
