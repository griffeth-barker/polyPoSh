# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-05-27

First formally versioned release.

### Added
- ARM64 (`aarch64`) support: when Microsoft's Linux package repos do not carry
  arm64 PowerShell packages, the script now downloads the official tarball from
  GitHub Releases and installs it to `/opt/microsoft/powershell/7/`
- ARM32 (`armv7l`) support via the same GitHub Releases tarball path
- Rocky Linux 9 and AlmaLinux 9 to the test matrix
- openSUSE Leap 15.5 to the test matrix (x86\_64 only; Leap 15.x ships glibc
  2.31 which is below the 2.33 minimum required by the PowerShell arm64 build)
- `test-arm64` CI job running on GitHub Actions `ubuntu-24.04-arm` hosted
  runners, covering Ubuntu 22.04, Debian 12, Fedora 40, and Rocky Linux 9
- `DOCKER_PLATFORM` environment variable in `tests/run_tests.sh` to allow
  arm64 local testing (`DOCKER_PLATFORM=linux/arm64 bash tests/run_tests.sh`)
- `SCRIPT_VERSION` constant in `polypo.sh`

### Fixed
- Script header comments still referenced old filename `install_powershell.sh`
  after the script was renamed to `polypo.sh`
- `tests/run_tests.sh` Docker volume mount and in-container command still
  referenced `install_powershell.sh`
- GitHub Actions workflow volume mount and step name still referenced
  `install_powershell.sh`
- Contributing documentation had a typo in the filename
  (`docs/contrbuting.md` → `docs/contributing.md`); the README link was
  already correct and now resolves properly
- Tests failing on Apple Silicon hosts: Docker containers are now pinned to
  `--platform linux/amd64` to match the architectures Microsoft's Linux package
  repos support
- `install_zypper` registered the `microsoft-sles*-prod` zypper repo, which
  does not contain PowerShell; switched to the RHEL 9 repo
  (`packages.microsoft.com/rhel/9/prod`), which is RPM-ABI-compatible with
  openSUSE Leap 15+. Uses `zypper download` + `rpm -i --nodeps` to bypass
  the `openssl-libs`/`icu-libs` package-name mismatch between the RHEL-built
  RPM and openSUSE's package naming conventions
- `detect_arch` comment incorrectly stated that the package manager resolves
  the correct arm binary automatically; updated to accurately describe the
  x86\_64 (package manager) and arm (tarball) installation paths

[Unreleased]: https://github.com/griffeth-barker/polyposh/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/griffeth-barker/polyposh/releases/tag/v1.0.0
