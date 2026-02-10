#!/bin/bash
#
# QEMU Initrd Download Script
#
# This script downloads the Debian Trixie initrd for the specified architecture.
#
# Usage: ./download-qemu-initrd.sh [OPTIONS]
#
# Options:
#   -a, --arch ARCH      Architecture (amd64 or arm64) (default: amd64)
#   -o, --output DIR     Output directory (default: ./build/)
#   -h, --help           Show this help message
#

set -euo pipefail

# Default configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/build/}"
ARCH="${ARCH:-amd64}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

show_help() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# //g' | sed 's/^#//g'
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# Validate architecture
if [[ ! "$ARCH" =~ ^(amd64|arm64)$ ]]; then
    log_error "Invalid architecture: $ARCH"
    log_error "Valid options: amd64, arm64"
    exit 1
fi

log_info "Downloading Debian Trixie initrd for $ARCH..."

mkdir -p "${OUTPUT_DIR}"

# Set architecture-specific URL
case "$ARCH" in
    amd64)
        INITRD_URL="http://ftp.us.debian.org/debian/dists/trixie/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz"
        ;;
    arm64)
        INITRD_URL="http://ftp.us.debian.org/debian/dists/trixie/main/installer-arm64/current/images/netboot/debian-installer/arm64/initrd.gz"
        ;;
esac

log_info "Downloading from: $INITRD_URL"

wget -O "${OUTPUT_DIR}initrd.gz" "$INITRD_URL"

log_success "Initrd downloaded to: ${OUTPUT_DIR}initrd.gz"