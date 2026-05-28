#!/usr/bin/env bash
# tests/run_tests.sh
#
# Runs polypo.sh inside Docker containers for each supported Linux
# distribution and verifies that PowerShell is installed and functional
# afterwards.
#
# Prerequisites:
#   - Docker must be installed and running on the host.
#
# Usage:
#   bash tests/run_tests.sh                        # test x86_64 (default)
#   DOCKER_PLATFORM=linux/arm64 bash tests/run_tests.sh  # test aarch64
#
# To test only specific distributions pass their image names as arguments:
#   bash tests/run_tests.sh ubuntu:22.04 debian:11

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="${SCRIPT_DIR}/../polypo.sh"

# Platform for Docker containers. Microsoft's Linux repos only publish
# PowerShell for x86_64, so the default is linux/amd64. Set
# DOCKER_PLATFORM=linux/arm64 to test the tarball installation path.
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

# Default list of distributions to test (image:tag pairs)
DEFAULT_DISTROS=(
    "ubuntu:22.04"
    "ubuntu:20.04"
    "debian:12"
    "debian:11"
    "fedora:40"
    "fedora:39"
    "rockylinux:9"
    "almalinux:9"
    "opensuse/leap:15.5"
)

# Use command-line arguments as distros when provided, otherwise use defaults
if [ "$#" -gt 0 ]; then
    DISTROS=("$@")
else
    DISTROS=("${DEFAULT_DISTROS[@]}")
fi

# Verify docker is available
if ! command -v docker &>/dev/null; then
    echo "ERROR: Docker is not installed or not in PATH." >&2
    exit 1
fi

PASS=0
FAIL=0
ERRORS=()

for distro in "${DISTROS[@]}"; do
    echo "=========================================="
    echo "Testing: ${distro}"
    echo "=========================================="

    if docker run --rm \
        --platform "${PLATFORM}" \
        --volume "${INSTALL_SCRIPT}:/polypo.sh:ro" \
        "${distro}" \
        bash -c "bash /polypo.sh && pwsh --version"; then
        echo ""
        echo "PASS: ${distro}"
        PASS=$((PASS + 1))
    else
        echo ""
        echo "FAIL: ${distro}"
        FAIL=$((FAIL + 1))
        ERRORS+=("${distro}")
    fi
    echo ""
done

echo "=========================================="
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "=========================================="

if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo ""
    echo "Failed distributions:"
    for err in "${ERRORS[@]}"; do
        echo "  - ${err}"
    done
    exit 1
fi

echo "All tests passed!"
