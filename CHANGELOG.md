# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-26

First tagged release.

### Added

- Single `positron-remote.sh` for Alpine and Bodhi: submits a Slurm job that holds an
  allocation for Positron Remote SSH and prints connection info.
- `setup` subcommand: SSH key exchange, Alpine scratch symlink, and a stable
  `positron-<cluster>` SSH alias that resolves the current node on connect.
- `status`, `connect`, `stop` and `reset` subcommands.
- `POSITRON_IDLE_TIMEOUT` to release the allocation after a period with no SSH session.
- `POSITRON_ACCOUNT` to choose the Slurm account to bill.
- `--version` flag.
- Documentation site (zensical) deployed to GitHub Pages.

### Changed

- Bodhi submits under the `rbi` account by default, since the `positron` QOS is attached
  to it. The pre-submit QOS check now verifies the account actually billed, and fails
  with a hint to set `POSITRON_ACCOUNT`. Fixes `invalid qos specification` for users
  whose default account is not `rbi` (#3, #4).
- Alpine uses the `acpu` partition and `cpu-normal` QOS (1 day max), following CURC's
  current documentation. Docs now show `amc-general` as the example Anschutz allocation
  (#5).
- Resources are configured per cluster (Alpine 24 GB / 24 h, Bodhi 24 GB / 8 h, 8 CPUs).

[Unreleased]: https://github.com/rnabioco/remote-ssh-positron/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/rnabioco/remote-ssh-positron/releases/tag/v0.1.0
