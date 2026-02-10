#!/bin/bash
#
# QEMU Kernel Build Script for Debian Trixie
#
# This script downloads, configures, and compiles a Linux kernel optimized for QEMU
# with support for virtio, 9p, networking, and other essential features.
#
# Usage: ./build-qemu-kernel.sh [OPTIONS]
#
# Options:
#   -k, --kernel-version VERSION   Kernel version to build (default: 6.12.4)
#   -j, --jobs N                   Number of parallel jobs (default: nproc)
#   -o, --output DIR               Output directory (default: ./build/kernel)
#   -s, --source DIR               Source directory (default: ./build/kernel-source)
#   --skip-install                 Skip installing dependencies
#   --clean                        Clean build directory before building
#   -h, --help                     Show this help message
#

set -euo pipefail

# Default configuration
KERNEL_VERSION="${KERNEL_VERSION:-6.12.4}"
KERNEL_MAJOR_VERSION=$(echo "$KERNEL_VERSION" | cut -d. -f1)
JOBS="${JOBS:-$(nproc)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/build/kernel}"
SOURCE_DIR="${SOURCE_DIR:-$REPO_ROOT/build/kernel-source}"
SKIP_INSTALL=0
CLEAN_BUILD=0

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
        -k|--kernel-version)
            KERNEL_VERSION="$2"
            KERNEL_MAJOR_VERSION=$(echo "$KERNEL_VERSION" | cut -d. -f1)
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

log_info "QEMU Kernel Build Script"
log_info "========================="
log_info "Kernel Version: $KERNEL_VERSION"
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
        bc \
        bison \
        flex \
        libelf-dev \
        libssl-dev \
        libncurses-dev \
        kmod \
        cpio \
        wget \
        xz-utils \
        git \
        fakeroot \
        dwarves \
        rsync \
        python3
    
    log_success "Dependencies installed"
}

# Download kernel source
download_kernel() {
    log_info "Downloading kernel source $KERNEL_VERSION..."
    
    mkdir -p "$SOURCE_DIR"

    local kernel_dir="$1"
    local kernel_tarball="linux-${KERNEL_VERSION}.tar.xz"
    local kernel_url="https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR_VERSION}.x/${kernel_tarball}"

    if [[ -d "$kernel_dir" ]]; then
        log_warn "Kernel source directory already exists: $kernel_dir"
        if [[ $CLEAN_BUILD -eq 1 ]]; then
            log_info "Cleaning existing source directory..."
            rm -rf "$kernel_dir"
        else
            log_info "Using existing source directory"
            echo "$kernel_dir"
            return
        fi
    fi
    
    cd "$SOURCE_DIR"
    
    if [[ ! -f "$kernel_tarball" ]]; then
        log_info "Downloading from $kernel_url..."
        wget "$kernel_url"
    else
        log_info "Using cached tarball: $kernel_tarball"
    fi
    
    log_info "Extracting kernel source..."
    tar -xf "$kernel_tarball"
    
    log_success "Kernel source ready at $kernel_dir"
    echo "$kernel _dir"
}

# Configure kernel for QEMU
configure_kernel() {
    local kernel_dir="$1"
    
    log_info "Configuring kernel for QEMU..."
    
    cd "$kernel_dir"
    
    # Start with a minimal x86_64 config
    make defconfig
    
    # Enable required features using scripts/config
    log_info "Enabling QEMU-specific features..."
    
    # Core virtualization and QEMU support
    scripts/config --enable CONFIG_HYPERVISOR_GUEST
    scripts/config --enable CONFIG_PARAVIRT
    scripts/config --enable CONFIG_PARAVIRT_SPINLOCKS
    scripts/config --enable CONFIG_KVM_GUEST
    
    # VirtIO support (essential for QEMU)
    scripts/config --enable CONFIG_VIRTIO
    scripts/config --enable CONFIG_VIRTIO_PCI
    scripts/config --enable CONFIG_VIRTIO_PCI_LEGACY
    scripts/config --enable CONFIG_VIRTIO_BALLOON
    scripts/config --enable CONFIG_VIRTIO_INPUT
    scripts/config --enable CONFIG_VIRTIO_MMIO
    scripts/config --enable CONFIG_VIRTIO_MMIO_CMDLINE_DEVICES
    
    # VirtIO block device
    scripts/config --enable CONFIG_VIRTIO_BLK
    scripts/config --enable CONFIG_SCSI_VIRTIO
    
    # VirtIO network
    scripts/config --enable CONFIG_VIRTIO_NET
    
    # VirtIO console
    scripts/config --enable CONFIG_VIRTIO_CONSOLE
    scripts/config --enable CONFIG_HW_RANDOM_VIRTIO
    
    # 9P filesystem support (for host filesystem sharing)
    scripts/config --enable CONFIG_NET_9P
    scripts/config --enable CONFIG_NET_9P_VIRTIO
    scripts/config --enable CONFIG_9P_FS
    scripts/config --enable CONFIG_9P_FS_POSIX_ACL
    scripts/config --enable CONFIG_9P_FS_SECURITY
    
    # Networking support
    scripts/config --enable CONFIG_NET
    scripts/config --enable CONFIG_INET
    scripts/config --enable CONFIG_PACKET
    scripts/config --enable CONFIG_UNIX
    scripts/config --enable CONFIG_IPV6
    scripts/config --enable CONFIG_NETDEVICES
    scripts/config --enable CONFIG_NET_CORE
    
    # Filesystem support
    scripts/config --enable CONFIG_EXT4_FS
    scripts/config --enable CONFIG_EXT4_FS_POSIX_ACL
    scripts/config --enable CONFIG_EXT4_FS_SECURITY
    scripts/config --enable CONFIG_EXT3_FS
    scripts/config --enable CONFIG_EXT2_FS
    scripts/config --enable CONFIG_TMPFS
    scripts/config --enable CONFIG_TMPFS_POSIX_ACL
    scripts/config --enable CONFIG_PROC_FS
    scripts/config --enable CONFIG_SYSFS
    scripts/config --enable CONFIG_DEVTMPFS
    scripts/config --enable CONFIG_DEVTMPFS_MOUNT
    
    # TTY and console support
    scripts/config --enable CONFIG_TTY
    scripts/config --enable CONFIG_SERIAL_8250
    scripts/config --enable CONFIG_SERIAL_8250_CONSOLE
    scripts/config --enable CONFIG_PRINTK
    
    # Essential system features
    scripts/config --enable CONFIG_BLK_DEV
    scripts/config --enable CONFIG_BLK_DEV_INITRD
    scripts/config --enable CONFIG_RD_GZIP
    scripts/config --enable CONFIG_RD_BZIP2
    scripts/config --enable CONFIG_RD_LZMA
    scripts/config --enable CONFIG_RD_XZ
    scripts/config --enable CONFIG_RD_LZO
    scripts/config --enable CONFIG_RD_LZ4
    scripts/config --enable CONFIG_RD_ZSTD
    
    # PCI support
    scripts/config --enable CONFIG_PCI
    scripts/config --enable CONFIG_PCI_MSI
    
    # ACPI support
    scripts/config --enable CONFIG_ACPI
    
    # Enable modules
    scripts/config --enable CONFIG_MODULES
    scripts/config --enable CONFIG_MODULE_UNLOAD
    
    # Disable debugging features to speed up build and reduce size
    scripts/config --disable CONFIG_DEBUG_KERNEL
    scripts/config --disable CONFIG_DEBUG_INFO
    scripts/config --disable CONFIG_DEBUG_INFO_BTF
    scripts/config --disable CONFIG_GDB_SCRIPTS
    
    # Other useful features
    scripts/config --enable CONFIG_BINFMT_ELF
    scripts/config --enable CONFIG_BINFMT_SCRIPT
    scripts/config --enable CONFIG_POSIX_TIMERS
    scripts/config --enable CONFIG_FUTEX
    scripts/config --enable CONFIG_EPOLL
    scripts/config --enable CONFIG_SIGNALFD
    scripts/config --enable CONFIG_TIMERFD
    scripts/config --enable CONFIG_EVENTFD
    
    # Update config with dependencies
    log_info "Resolving configuration dependencies..."
    make olddefconfig
    
    log_success "Kernel configuration complete"
}

# Build kernel
build_kernel() {
    local kernel_dir="$1"
    
    log_info "Building kernel (this may take a while)..."
    
    cd "$kernel_dir"
    
    # Build kernel and modules
    make -j"$JOBS" bzImage modules
    
    log_success "Kernel build complete"
}

# Install kernel to output directory
install_kernel() {
    local kernel_dir="$1"
    
    log_info "Installing kernel to $OUTPUT_DIR..."
    
    mkdir -p "$OUTPUT_DIR"
    
    cd "$kernel_dir"
    
    # Copy kernel image
    cp arch/x86_64/boot/bzImage "$OUTPUT_DIR/vmlinuz-${KERNEL_VERSION}"
    
    # Install modules
    make INSTALL_MOD_PATH="$OUTPUT_DIR" modules_install
    
    # Copy config for reference
    cp .config "$OUTPUT_DIR/config-${KERNEL_VERSION}"
    
    # Copy System.map for reference
    cp System.map "$OUTPUT_DIR/System.map-${KERNEL_VERSION}"
    
    # Create symlinks for convenience
    cd "$OUTPUT_DIR"
    ln -sf "vmlinuz-${KERNEL_VERSION}" vmlinuz
    ln -sf "config-${KERNEL_VERSION}" config
    ln -sf "System.map-${KERNEL_VERSION}" System.map
    
    log_success "Kernel installed to $OUTPUT_DIR"
}

# Main execution
main() {
    log_info "Starting QEMU kernel build process..."
    echo
    kernel_dir="$SOURCE_DIR/linux-${KERNEL_VERSION}"
    
    install_dependencies
    echo
    
    download_kernel "$kernel_dir"
    echo
    
    configure_kernel "$kernel_dir"
    echo
    
    build_kernel "$kernel_dir"
    echo
    
    install_kernel "$kernel_dir"
    echo
    
    log_success "==========================="
    log_success "Kernel build complete!"
    log_success "==========================="
    echo
    log_info "Kernel image: $OUTPUT_DIR/vmlinuz"
    log_info "Kernel version: $KERNEL_VERSION"
    log_info "Modules: $OUTPUT_DIR/lib/modules/${KERNEL_VERSION}"
    echo
    log_info "You can use this kernel with QEMU:"
    log_info "  qemu-system-x86_64 -kernel $OUTPUT_DIR/vmlinuz -initrd <initrd> ..."
    echo
    log_info "To test the kernel with your sandbox:"
    log_info "  cd $REPO_ROOT"
    log_info "  make example -- --kernel=$OUTPUT_DIR/vmlinuz"
    echo
}

# Run main function
main
