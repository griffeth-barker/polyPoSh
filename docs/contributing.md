# Contributing to polyPoSh

Thanks for your interest in contributing! This document covers how to report issues, propose changes, and submit pull requests.

## Getting Started

1. Fork the repository and clone your fork.
2. Create a feature branch off `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes, then [run the tests](#testing) before opening a pull request.

## What to Work On

Check the [issue tracker](https://github.com/griffeth-barker/polyposh/issues) for open issues. Issues labelled **good first issue** are a good starting point. If you want to work on something not already tracked, open an issue first so we can discuss the approach before you invest time in it.

## Making Changes

### The script

All installation logic lives in `polypo.sh`. The structure is:

- **Detection** (`detect_arch`, `detect_os`) — reads `uname -m` and `/etc/os-release`
- **Install functions** — one per package manager: `install_deb`, `install_rpm`, `install_zypper`, `install_tarball`, `install_macos`
- **Main** — dispatches to the correct function

When adding support for a new distribution or architecture:

1. Add the distro's `ID` value (from `/etc/os-release`) to the `case` block in `main`.
2. Add or reuse an install function. Prefer reusing an existing one (e.g. a new RPM-based distro can usually reuse `install_rpm`).
3. Add the distro to the test matrix in both `tests/run_tests.sh` and `.github/workflows/test.yml`.

### Shell script style

- The script uses `set -euo pipefail`. Do not disable this.
- Use `local` for all variables inside functions.
- Use `get_sudo` rather than hardcoding `sudo` — the script needs to run as root in containers.
- Prefer `command -v <tool> &>/dev/null` to check for tool availability before using it.
- Do not hardcode PowerShell version numbers. The script always installs the latest version.

### Changelog

Every user-visible change must have a [CHANGELOG.md](../CHANGELOG.md) entry under `## [Unreleased]`, following the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format:

- **Added** — new features or platform support
- **Fixed** — bug fixes
- **Changed** — changes to existing behaviour
- **Removed** — removed features

## Testing

Tests run `polypo.sh` inside Docker containers (Linux) or directly on the host (macOS).

```bash
# Run all Linux tests (requires Docker)
bash tests/run_tests.sh

# Test specific distributions
bash tests/run_tests.sh ubuntu:22.04 fedora:40

# Test arm64 Linux (requires an arm64 host or QEMU)
DOCKER_PLATFORM=linux/arm64 bash tests/run_tests.sh ubuntu:22.04 debian:12

# Test macOS (run directly — Docker cannot emulate macOS)
bash tests/run_tests.sh
```

CI runs the full matrix automatically on every push and pull request via GitHub Actions. You can see the workflow in [`.github/workflows/test.yml`](../.github/workflows/test.yml).

If you are adding support for a new distribution, add it to the test matrix **before** opening your pull request.

## Pull Request Guidelines

- Keep PRs focused — one feature or fix per PR.
- Reference the issue your PR addresses (e.g. `Closes #42`).
- Fill in the PR description with what changed and why.
- All CI checks must pass before a PR can be merged.
- A maintainer will review and merge once the checks are green.

## Reporting Bugs

Open an issue with:

- The output of `bash polypo.sh` (or the error you saw)
- Your OS and architecture (`uname -sm` and `cat /etc/os-release` on Linux, `sw_vers` on macOS)
- Whether you were running as root or a regular user

## Code of Conduct

Be respectful and constructive. Contributions of all experience levels are welcome.
