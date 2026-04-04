# Configuration

Resources are configured via SLURM directives in `positron-remote.sh`.

## Default Settings

| Setting | Alpine | amc-bodhi |
|---------|--------|-----------|
| `--time` | 8 hours | 8 hours |
| `--mem` | 24 GB | 24 GB |
| `--partition` | `amilan` | `positron` |
| `--qos` | `normal` | `positron` |
| `--cpus-per-task` | 4 | 8 |

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
