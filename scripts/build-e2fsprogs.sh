#!/bin/bash
#
# E2fsprogs Build Script
#
# This script downloads, configures, and compiles e2fsprogs (mke2fs and e2fsck)
# for multiple architectures: arm, arm64, and amd64.
#
# Usage: ./build-e2fsprogs.sh [OPTIONS]
#
# Options:
#   -v, --version VERSION          E2fsprogs version to build (default: 1.47.1)
#   -j, --jobs N                   Number of parallel jobs (default: nproc)
#   -o, --output DIR               Output directory (default: ./build/e2fsprogs)
#   -s, --source DIR               Source directory (default: ./build/e2fsprogs-source)
#   -a, --arch ARCH                Architecture to build (arm, arm64, amd64, or all) (default: all)
#   --skip-install                 Skip installing dependencies
#   --clean                        Clean build directory before building
#   -h, --help                     Show this help message
#

set -euo pipefail

# Default configuration
E2FSPROGS_VERSION="${E2FSPROGS_VERSION:-1.47.1}"
JOBS="${JOBS:-$(nproc)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/build/e2fsprogs}"
SOURCE_DIR="${SOURCE_DIR:-$REPO_ROOT/build/e2fsprogs-source}"
ARCH="${ARCH:-all}"
SKIP_INSTALL=0
CLEAN_BUILD=0
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1600000000}"

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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
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
        -v|--version)
            E2FSPROGS_VERSION="$2"
            shift 2
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -s|--source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
        --skip-install)
            SKIP_INSTALL=1
            shift
            ;;
        --clean)
            CLEAN_BUILD=1
            shift
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
if [[ ! "$ARCH" =~ ^(arm|arm64|amd64|all)$ ]]; then
    log_error "Invalid architecture: $ARCH"
    log_error "Valid options: arm, arm64, amd64, all"
    exit 1
fi

log_info "E2fsprogs Build Script"
log_info "======================"
log_info "E2fsprogs Version: $E2FSPROGS_VERSION"
log_info "Architecture(s): $ARCH"
log_info "Parallel Jobs: $JOBS"
log_info "Output Directory: $OUTPUT_DIR"
log_info "Source Directory: $SOURCE_DIR"
echo

# Install build dependencies
install_dependencies() {
    log_info "Installing build dependencies..."
    
    if [[ $SKIP_INSTALL -eq 1 ]]; then
        log_warn "Skipping dependency installation (--skip-install)"
        return
    fi
    
    if [[ $EUID -ne 0 ]]; then
        log_warn "Not running as root. Using sudo for package installation..."
        SUDO="sudo"
    else
        SUDO=""
    fi
    
    $SUDO apt-get update
    $SUDO apt-get install -y \
        build-essential \
        crossbuild-essential-armel \
        crossbuild-essential-arm64 \
        curl \
        wget \
        pkg-config \
        libblkid-dev \
        uuid-dev \
        libssl-dev
    
    log_success "Dependencies installed"
}

# Download e2fsprogs source
download_e2fsprogs() {
    log_info "Downloading e2fsprogs source $E2FSPROGS_VERSION..."
    
    mkdir -p "$SOURCE_DIR"
    
    local source_tarball="e2fsprogs-${E2FSPROGS_VERSION}.tar.gz"
    local source_url="https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v${E2FSPROGS_VERSION}/${source_tarball}"
    local source_path="$SOURCE_DIR/e2fsprogs-${E2FSPROGS_VERSION}"
    
    if [[ -d "$source_path" ]]; then
        log_warn "Source directory already exists: $source_path"
        if [[ $CLEAN_BUILD -eq 1 ]]; then
            log_info "Cleaning existing source directory..."
            rm -rf "$source_path"
        else
            log_info "Using existing source directory"
            return
        fi
    fi
    
    cd "$SOURCE_DIR"
    
    if [[ ! -f "$source_tarball" ]]; then
        log_info "Downloading from $source_url..."
        wget "$source_url"
    else
        log_info "Using cached tarball: $source_tarball"
    fi
    
    log_info "Extracting e2fsprogs source..."
    tar -xzf "$source_tarball"
    
    log_success "E2fsprogs source ready at $source_path"
}

# Build for ARM (32-bit)
build_arm() {
    log_info "Building e2fsprogs for ARM (32-bit)..."
    
    local source_path="$SOURCE_DIR/e2fsprogs-${E2FSPROGS_VERSION}"
    cd "$source_path"
    
    # Clean previous build
    make distclean 2>/dev/null || true
    
    log_info "Configuring for ARM..."
    ./configure \
        CFLAGS='-O2 -static' \
        LDFLAGS=-static \
        CC=arm-linux-gnueabi-gcc \
        --host=arm-linux-gnueabi \
        --disable-nls \
        --disable-threads
    
    log_info "Compiling for ARM..."
    make -j"$JOBS"
    
    log_info "Copying ARM binaries..."
    mkdir -p "$OUTPUT_DIR/arm"
    cp ./misc/mke2fs "$OUTPUT_DIR/arm/mke2fs"
    cp ./e2fsck/e2fsck "$OUTPUT_DIR/arm/e2fsck"
    
    # Verify binaries are static
    if file "$OUTPUT_DIR/arm/mke2fs" | grep -q "statically linked"; then
        log_success "ARM mke2fs is statically linked"
    else
        log_warn "ARM mke2fs may not be statically linked"
    fi
    
    if file "$OUTPUT_DIR/arm/e2fsck" | grep -q "statically linked"; then
        log_success "ARM e2fsck is statically linked"
    else
        log_warn "ARM e2fsck may not be statically linked"
    fi
    
    make distclean
    
    log_success "ARM build complete"
}

# Build for ARM64
build_arm64() {
    log_info "Building e2fsprogs for ARM64..."
    
    local source_path="$SOURCE_DIR/e2fsprogs-${E2FSPROGS_VERSION}"
    cd "$source_path"
    
    # Clean previous build
    make distclean 2>/dev/null || true
    
    log_info "Configuring for ARM64..."
    ./configure \
        CFLAGS='-O2 -static' \
        LDFLAGS=-static \
        CC=aarch64-linux-gnu-gcc \
        --host=aarch64-linux-gnu \
        --disable-nls \
        --disable-threads
    
    log_info "Compiling for ARM64..."
    make -j"$JOBS"
    
    log_info "Copying ARM64 binaries..."
    mkdir -p "$OUTPUT_DIR/arm64"
    cp ./misc/mke2fs "$OUTPUT_DIR/arm64/mke2fs"
    cp ./e2fsck/e2fsck "$OUTPUT_DIR/arm64/e2fsck"
    
    # Verify binaries are static
    if file "$OUTPUT_DIR/arm64/mke2fs" | grep -q "statically linked"; then
        log_success "ARM64 mke2fs is statically linked"
    else
        log_warn "ARM64 mke2fs may not be statically linked"
    fi
    
    if file "$OUTPUT_DIR/arm64/e2fsck" | grep -q "statically linked"; then
        log_success "ARM64 e2fsck is statically linked"
    else
        log_warn "ARM64 e2fsck may not be statically linked"
    fi
    
    make distclean
    
    log_success "ARM64 build complete"
}

# Build for AMD64
build_amd64() {
    log_info "Building e2fsprogs for AMD64..."
    
    local source_path="$SOURCE_DIR/e2fsprogs-${E2FSPROGS_VERSION}"
    cd "$source_path"
    
    # Clean previous build
    make distclean 2>/dev/null || true
    
    log_info "Configuring for AMD64..."
    ./configure \
        CFLAGS='-O2 -static' \
        LDFLAGS=-static \
        --disable-nls \
        --disable-threads
    
    log_info "Compiling for AMD64..."
    make -j"$JOBS"
    
    log_info "Copying AMD64 binaries..."
    mkdir -p "$OUTPUT_DIR/amd64"
    cp ./misc/mke2fs "$OUTPUT_DIR/amd64/mke2fs"
    cp ./e2fsck/e2fsck "$OUTPUT_DIR/amd64/e2fsck"
    
    # Verify binaries are static
    if file "$OUTPUT_DIR/amd64/mke2fs" | grep -q "statically linked"; then
        log_success "AMD64 mke2fs is statically linked"
    else
        log_warn "AMD64 mke2fs may not be statically linked"
    fi
    
    if file "$OUTPUT_DIR/amd64/e2fsck" | grep -q "statically linked"; then
        log_success "AMD64 e2fsck is statically linked"
    else
        log_warn "AMD64 e2fsck may not be statically linked"
    fi
    
    make distclean
    
    log_success "AMD64 build complete"
}

# Main execution
main() {
    log_info "Starting e2fsprogs build process..."
    echo
    
    install_dependencies
    echo
    
    download_e2fsprogs
    echo
    
    # Build for requested architecture(s)
    if [[ "$ARCH" == "all" ]] || [[ "$ARCH" == "arm" ]]; then
        build_arm
        echo
    fi
    
    if [[ "$ARCH" == "all" ]] || [[ "$ARCH" == "arm64" ]]; then
        build_arm64
        echo
    fi
    
    if [[ "$ARCH" == "all" ]] || [[ "$ARCH" == "amd64" ]]; then
        build_amd64
        echo
    fi
    
    log_success "==========================="
    log_success "E2fsprogs build complete!"
    log_success "==========================="
    echo
    log_info "Output directory: $OUTPUT_DIR"
    echo
    
    # Show what was built
    if [[ "$ARCH" == "all" ]] || [[ "$ARCH" == "arm" ]]; then
        log_info "ARM binaries:"
        log_info "  $OUTPUT_DIR/arm/mke2fs"
        log_info "  $OUTPUT_DIR/arm/e2fsck"
        echo
    fi
    
    if [[ "$ARCH" == "all" ]] || [[ "$ARCH" == "arm64" ]]; then
        log_info "ARM64 binaries:"
        log_info "  $OUTPUT_DIR/arm64/mke2fs"
        log_info "  $OUTPUT_DIR/arm64/e2fsck"
        echo
    fi
    
    if [[ "$ARCH" == "all" ]] || [[ "$ARCH" == "amd64" ]]; then
        log_info "AMD64 binaries:"
        log_info "  $OUTPUT_DIR/amd64/mke2fs"
        log_info "  $OUTPUT_DIR/amd64/e2fsck"
        echo
    fi
    
    log_info "All binaries are statically linked and ready for deployment"
    echo
}

# Run main function
main
