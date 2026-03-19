#!/usr/bin/env bash
# tests/run_tests.sh
#
# Runs install_powershell.sh inside Docker containers for each supported
# Linux distribution and verifies that PowerShell is installed and
# functional afterwards.
#
# Prerequisites:
#   - Docker must be installed and running on the host.
#
# Usage:
#   bash tests/run_tests.sh
#
# To test only specific distributions pass their image names as arguments:
#   bash tests/run_tests.sh ubuntu:22.04 debian:11

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="${SCRIPT_DIR}/../install_powershell.sh"

# Default list of distributions to test (image:tag pairs)
DEFAULT_DISTROS=(
    "ubuntu:22.04"
    "ubuntu:20.04"
    "debian:12"
    "debian:11"
    "fedora:40"
    "fedora:39"
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
        --volume "${INSTALL_SCRIPT}:/install_powershell.sh:ro" \
        "${distro}" \
        bash -c "bash /install_powershell.sh && pwsh --version"; then
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
