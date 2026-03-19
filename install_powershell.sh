#!/usr/bin/env bash
# install_powershell.sh
#
# Installs PowerShell on the current Linux distribution by registering
# Microsoft's package repository and using the native package manager.
#
# No PowerShell version numbers or direct package download URLs are
# hard-coded; the script always installs the latest version available
# from Microsoft's official repositories based on the detected distro
# and version.
#
# Supported distributions:
#   Debian-based : Ubuntu (20.04+), Debian (10+)
#   RPM-based    : RHEL (7–9), CentOS Stream (8–9), Fedora (37+),
#                  Rocky Linux (8–9), AlmaLinux (8–9)
#   Zypper-based : openSUSE Leap (15+), SLES (15+)
#
# Usage:
#   bash install_powershell.sh
#   sudo bash install_powershell.sh   # when not running as root

set -euo pipefail

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
        x86_64 | aarch64 | armv7l)
            # Supported — the package manager resolves the correct binary automatically.
            # Note: arm64 is an alias for aarch64 on some platforms; uname -m returns aarch64.
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

    log_section "Installing prerequisites (wget, apt-transport-https, software-properties-common)..."
    $sudo_cmd apt-get update -q
    $sudo_cmd apt-get install -y -q wget apt-transport-https software-properties-common

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

    # For Fedora, use prod.repo, otherwise packages-microsoft-prod.repo
    if [[ "$distro" == "fedora" ]]; then
        local prod_repo_url="${MICROSOFT_PACKAGES_URL}/config/${distro}/${version}/prod.repo"
    else
        local prod_repo_url="${MICROSOFT_PACKAGES_URL}/config/${distro}/${version}/packages-microsoft-prod.repo"
    fi

    if command -v dnf &>/dev/null; then
        log_section "Registering Microsoft package repository (dnf) for ${distro} ${version}..."
        $sudo_cmd dnf install -y "$prod_repo_url"

        log_section "Installing PowerShell..."
        $sudo_cmd dnf install -y powershell

    elif command -v yum &>/dev/null; then
        log_section "Registering Microsoft package repository (yum) for ${distro} ${version}..."
        # Ensure curl is available for downloading the repo file
        if ! command -v curl &>/dev/null; then
            yum install -y curl
        fi
        # yum cannot install a URL directly; download the repo file first
        $sudo_cmd curl -fsSL "$prod_repo_url" \
            -o /etc/yum.repos.d/packages-microsoft-prod.repo

        log_section "Installing PowerShell..."
        $sudo_cmd yum install -y powershell

    else
        echo "ERROR: No supported package manager found (dnf or yum)." >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# openSUSE / SLES: register Microsoft repo then install via zypper
# ---------------------------------------------------------------------------
install_zypper() {
    local version="$1"  # major version: 15
    local sudo_cmd
    sudo_cmd="$(get_sudo)"

    log_section "Importing Microsoft GPG key..."
    $sudo_cmd rpm --import "${MICROSOFT_PACKAGES_URL}/keys/microsoft.asc"

    log_section "Registering Microsoft package repository (zypper) for openSUSE/SLES ${version}..."
    local repo_url="${MICROSOFT_PACKAGES_URL}/yumrepos/microsoft-sles${version}-prod"
    $sudo_cmd zypper addrepo --gpgcheck --refresh "$repo_url" microsoft-prod

    log_section "Installing PowerShell..."
    $sudo_cmd zypper install -y powershell
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    detect_os
    detect_arch

    echo "Detected OS  : ${OS_PRETTY_NAME}"
    echo "Architecture : ${ARCH}"

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
            local major_version="${OS_VERSION_ID%%.*}"
            install_zypper "$major_version"
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
