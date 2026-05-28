#!/usr/bin/env bash
# polypo.sh
#
# Installs PowerShell on the current Linux distribution.
#
# x86_64  : registers Microsoft's package repository and installs via the
#            native package manager (apt / dnf / zypper).
# aarch64 : Microsoft does not publish arm64 packages in their Linux repos;
#            the latest release tarball is downloaded from GitHub instead.
# armv7l  : same tarball approach as aarch64, using the arm32 build.
#
# No PowerShell version numbers are hard-coded; the script always installs
# the latest version available from Microsoft's repos (x86_64) or the
# latest GitHub release (arm).
#
# Supported distributions:
#   Debian-based : Ubuntu (20.04+), Debian (10+)
#   RPM-based    : RHEL (7–9), CentOS Stream (8–9), Fedora (37+),
#                  Rocky Linux (8–9), AlmaLinux (8–9)
#   Zypper-based : openSUSE Leap (15+), SLES (15+)
#
# Usage:
#   bash polypo.sh
#   sudo bash polypo.sh   # when not running as root

set -euo pipefail

SCRIPT_VERSION="1.0.0"
MICROSOFT_PACKAGES_URL="https://packages.microsoft.com"

# ---------------------------------------------------------------------------
# Helper: print a section header
# ---------------------------------------------------------------------------
log_section() {
    echo ""
    echo ">>> $*"
}

# ---------------------------------------------------------------------------
# Helper: sudo prefix (empty string when already root)
# ---------------------------------------------------------------------------
get_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        echo ""
    else
        if ! command -v sudo &>/dev/null; then
            echo "ERROR: Not running as root and 'sudo' is not available." >&2
            exit 1
        fi
        echo "sudo"
    fi
}

# ---------------------------------------------------------------------------
# Detect OS and architecture
# ---------------------------------------------------------------------------
detect_os() {
    if [ ! -f /etc/os-release ]; then
        echo "ERROR: /etc/os-release not found — cannot determine Linux distribution." >&2
        exit 1
    fi

    # shellcheck source=/dev/null
    . /etc/os-release

    OS_ID="${ID,,}"
    OS_VERSION_ID="${VERSION_ID:-}"
    OS_PRETTY_NAME="${PRETTY_NAME:-$OS_ID}"
}

detect_arch() {
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)
            # Package manager path — Microsoft publishes PowerShell for x86_64
            # in their Linux repos for all supported distributions.
            ;;
        aarch64 | armv7l)
            # Tarball path — Microsoft does not publish arm packages in their
            # Linux repos; the GitHub release tarball is used instead.
            ;;
        *)
            echo "ERROR: Unsupported architecture: $ARCH" >&2
            exit 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Debian / Ubuntu: register Microsoft repo then install via apt
# ---------------------------------------------------------------------------
install_deb() {
    local distro="$1"   # ubuntu | debian
    local version="$2"  # e.g. 22.04 | 11
    local sudo_cmd
    sudo_cmd="$(get_sudo)"

    log_section "Installing prerequisites (wget, apt-transport-https)..."
    $sudo_cmd apt-get update -q
    $sudo_cmd apt-get install -y -q wget apt-transport-https

    log_section "Registering Microsoft package repository for ${distro} ${version}..."
    local prod_deb_url="${MICROSOFT_PACKAGES_URL}/config/${distro}/${version}/packages-microsoft-prod.deb"
    wget -q "$prod_deb_url" -O /tmp/packages-microsoft-prod.deb
    $sudo_cmd dpkg -i /tmp/packages-microsoft-prod.deb
    rm -f /tmp/packages-microsoft-prod.deb

    log_section "Installing PowerShell..."
    $sudo_cmd apt-get update -q
    $sudo_cmd apt-get install -y powershell
}

# ---------------------------------------------------------------------------
# RHEL / Fedora / CentOS / Rocky / AlmaLinux: register repo then install
# via dnf (preferred) or yum
# ---------------------------------------------------------------------------
install_rpm() {
    local distro="$1"   # rhel | fedora
    local version="$2"  # major version: 8 | 9 | 39 …
    local sudo_cmd
    sudo_cmd="$(get_sudo)"

    # The Microsoft Fedora-specific repos (packages.microsoft.com/fedora/*) do NOT
    # contain a PowerShell package — they only ship procdump/procmon tooling.
    # PowerShell is published in the RHEL repos.  Fedora 37+ is binary-compatible
    # with RHEL 9 (same glibc / RPM ABI), so we use the RHEL 9 repo for Fedora.
    # All Microsoft RHEL config dirs (7, 8, 9) only publish "prod.repo" — there
    # is no "packages-microsoft-prod.repo" file at those paths.
    local prod_repo_url repo_dest
    if [ "$distro" = "fedora" ]; then
        prod_repo_url="${MICROSOFT_PACKAGES_URL}/config/rhel/9/prod.repo"
        repo_dest="/etc/yum.repos.d/packages-microsoft-prod.repo"
    else
        prod_repo_url="${MICROSOFT_PACKAGES_URL}/config/${distro}/${version}/prod.repo"
        repo_dest="/etc/yum.repos.d/packages-microsoft-prod.repo"
    fi

    # Determine which package manager is available
    local pkg_mgr
    if command -v dnf &>/dev/null; then
        pkg_mgr="dnf"
    elif command -v yum &>/dev/null; then
        pkg_mgr="yum"
    else
        echo "ERROR: No supported package manager found (dnf or yum)." >&2
        exit 1
    fi

    # Ensure curl is available to download the .repo file
    if ! command -v curl &>/dev/null; then
        log_section "Installing curl prerequisite..."
        $sudo_cmd "$pkg_mgr" install -y curl
    fi

    log_section "Importing Microsoft GPG key..."
    # The GPG key must be imported before the repo is registered so that dnf/yum
    # can verify the signed repo metadata (repomd.xml).  Without this, dnf5
    # (Fedora 39+) silently rejects the repo metadata and reports every package
    # in the repo as "No match", even though the repo file was placed correctly.
    $sudo_cmd rpm --import "${MICROSOFT_PACKAGES_URL}/keys/microsoft.asc"

    log_section "Registering Microsoft package repository for ${distro} ${version}..."
    # .repo files must be placed in /etc/yum.repos.d/ — they are not RPM packages
    # and cannot be installed via 'dnf/yum install <url>'.
    $sudo_cmd curl -fsSL "$prod_repo_url" -o "$repo_dest"

    log_section "Installing PowerShell..."
    $sudo_cmd "$pkg_mgr" install -y powershell
}

# ---------------------------------------------------------------------------
# openSUSE / SLES: register Microsoft repo then install via zypper + rpm
# ---------------------------------------------------------------------------
install_zypper() {
    local sudo_cmd
    sudo_cmd="$(get_sudo)"

    log_section "Importing Microsoft GPG key..."
    $sudo_cmd rpm --import "${MICROSOFT_PACKAGES_URL}/keys/microsoft.asc"

    log_section "Registering Microsoft package repository (zypper)..."
    # The microsoft-sles*-prod repos do not contain PowerShell; the RHEL 9
    # repo does and is RPM-ABI-compatible with openSUSE Leap 15+.
    $sudo_cmd zypper addrepo --gpgcheck --refresh \
        "${MICROSOFT_PACKAGES_URL}/rhel/9/prod" microsoft-prod

    log_section "Installing prerequisites (libopenssl3, libicu)..."
    # The powershell RPM (built for RHEL) declares openssl-libs and icu-libs
    # as dependencies, but those package names do not exist on openSUSE.
    # Install the openSUSE equivalents first, then use rpm --nodeps below
    # to bypass the package-name mismatch.
    $sudo_cmd zypper --non-interactive --gpg-auto-import-keys install -y \
        libopenssl3 libicu

    log_section "Installing PowerShell..."
    # Download via zypper (handles GPG verification and version resolution),
    # then install the cached RPM directly to skip the unsatisfiable dep check.
    $sudo_cmd zypper --non-interactive --gpg-auto-import-keys download powershell
    local rpm_file
    rpm_file="$(find /var/cache/zypp/packages/microsoft-prod -name 'powershell-[0-9]*.rpm' | head -1)"
    $sudo_cmd rpm -i --nodeps "$rpm_file"
}

# ---------------------------------------------------------------------------
# aarch64 / armv7l: install via tarball from GitHub Releases.
# Microsoft does not publish arm packages in their Linux repos; official
# arm builds are distributed as tarballs from the PowerShell GitHub repo.
# ---------------------------------------------------------------------------
install_tarball() {
    local sudo_cmd
    sudo_cmd="$(get_sudo)"

    # Map uname -m to the GitHub release asset suffix.
    local arch_suffix
    case "$ARCH" in
        aarch64) arch_suffix="linux-arm64" ;;
        armv7l)  arch_suffix="linux-arm32" ;;
    esac

    log_section "Installing prerequisites (curl, tar, libicu)..."
    # curl fetches the GitHub release metadata and tarball.
    # tar extracts the tarball (absent from some minimal container images).
    # libicu is required by PowerShell's .NET runtime for globalization;
    # it is normally pulled in automatically when installing via a package
    # manager, but must be installed explicitly for the tarball path.
    # On Debian/Ubuntu, libicu-dev depends on the versioned libicuNN runtime
    # package for that distro, making it the most reliable install target.
    # RHEL-based images often ship curl-minimal which conflicts with curl;
    # only install curl if no curl implementation is already present.
    if command -v apt-get &>/dev/null; then
        $sudo_cmd apt-get update -q
        $sudo_cmd apt-get install -y -q curl tar libicu-dev
    elif command -v dnf &>/dev/null; then
        command -v curl &>/dev/null || $sudo_cmd dnf install -y curl
        $sudo_cmd dnf install -y tar libicu
    elif command -v yum &>/dev/null; then
        command -v curl &>/dev/null || $sudo_cmd yum install -y curl
        $sudo_cmd yum install -y tar libicu
    elif command -v zypper &>/dev/null; then
        $sudo_cmd zypper --non-interactive install -y curl tar gzip libicu
    else
        echo "ERROR: No supported package manager found to install prerequisites." >&2
        exit 1
    fi

    log_section "Fetching latest PowerShell release from GitHub..."
    local version
    version=$(curl -fsSL "https://api.github.com/repos/PowerShell/PowerShell/releases/latest" \
        | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')

    if [ -z "$version" ]; then
        echo "ERROR: Could not determine the latest PowerShell version from GitHub." >&2
        exit 1
    fi

    local tarball="powershell-${version}-${arch_suffix}.tar.gz"
    local url="https://github.com/PowerShell/PowerShell/releases/download/v${version}/${tarball}"

    log_section "Downloading PowerShell ${version} for ${ARCH}..."
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    curl -fsSL "$url" -o "${tmp_dir}/${tarball}"

    log_section "Installing PowerShell..."
    local install_dir="/opt/microsoft/powershell/7"
    $sudo_cmd mkdir -p "$install_dir"
    $sudo_cmd tar -xzf "${tmp_dir}/${tarball}" -C "$install_dir"
    $sudo_cmd chmod +x "${install_dir}/pwsh"
    $sudo_cmd ln -sf "${install_dir}/pwsh" /usr/local/bin/pwsh

    rm -rf "$tmp_dir"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    detect_os
    detect_arch

    echo "Detected OS  : ${OS_PRETTY_NAME}"
    echo "Architecture : ${ARCH}"

    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "armv7l" ]; then
        install_tarball
        echo ""
        echo "PowerShell installed successfully!"
        pwsh --version
        return
    fi

    case "$OS_ID" in
        ubuntu)
            install_deb "ubuntu" "$OS_VERSION_ID"
            ;;
        debian)
            install_deb "debian" "$OS_VERSION_ID"
            ;;
        fedora)
            install_rpm "fedora" "$OS_VERSION_ID"
            ;;
        rhel | centos | rocky | almalinux)
            # Microsoft repo configs use the major version number only
            local major_version="${OS_VERSION_ID%%.*}"
            install_rpm "rhel" "$major_version"
            ;;
        opensuse* | sles)
            install_zypper
            ;;
        *)
            echo "ERROR: Unsupported or unrecognized Linux distribution: ${OS_ID}" >&2
            echo "Supported: Ubuntu, Debian, Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux, openSUSE, SLES" >&2
            exit 1
            ;;
    esac

    echo ""
    echo "PowerShell installed successfully!"
    pwsh --version
}

main
