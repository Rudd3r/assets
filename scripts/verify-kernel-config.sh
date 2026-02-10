#!/bin/bash
#
# Kernel Configuration Verification Script
#
# This script verifies that a kernel configuration includes all features
# required for the QEMU sandbox environment.
#
# Usage: ./verify-kernel-config.sh <kernel-config-file>
#

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
CONFIG_FILE="${1:-}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME <kernel-config-file>

Verifies that a kernel configuration includes all features required for
the QEMU sandbox environment.

Arguments:
  kernel-config-file    Path to kernel .config file
                        (e.g., build/kernel/config-6.12.4 or /boot/config-\$(uname -r))

Examples:
  # Verify a built kernel
  $SCRIPT_NAME build/kernel/config-6.12.4

  # Verify running kernel
  $SCRIPT_NAME /boot/config-\$(uname -r)

  # Verify kernel in source tree
  $SCRIPT_NAME build/kernel-source/linux-6.12.4/.config

Exit codes:
  0 - All required features are present
  1 - One or more required features are missing
  2 - Invalid usage or file not found
EOF
}

if [[ -z "$CONFIG_FILE" ]] || [[ "$CONFIG_FILE" == "-h" ]] || [[ "$CONFIG_FILE" == "--help" ]]; then
    show_help
    exit 2
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Error: Config file not found: $CONFIG_FILE${NC}" >&2
    echo >&2
    show_help
    exit 2
fi

echo -e "${BLUE}Verifying kernel configuration: $CONFIG_FILE${NC}"
echo

# Check if a config option is enabled (y or m)
check_config() {
    local option=$1
    local severity=${2:-required}  # required, recommended, optional
    local description=${3:-}
    
    if grep -q "^${option}=y" "$CONFIG_FILE" || grep -q "^${option}=m" "$CONFIG_FILE"; then
        echo -e "${GREEN}✓${NC} $option"
        if [[ -n "$description" ]]; then
            echo -e "  ${description}"
        fi
        return 0
    else
        if [[ "$severity" == "required" ]]; then
            echo -e "${RED}✗${NC} $option (REQUIRED)"
        elif [[ "$severity" == "recommended" ]]; then
            echo -e "${YELLOW}⚠${NC} $option (RECOMMENDED)"
        else
            echo -e "  $option (optional)"
        fi
        if [[ -n "$description" ]]; then
            echo -e "  ${description}"
        fi
        return 1
    fi
}

MISSING_REQUIRED=0
MISSING_RECOMMENDED=0

echo -e "${BLUE}=== Core Virtualization ===${NC}"
check_config CONFIG_HYPERVISOR_GUEST required "Detect and optimize for VM environments" || ((MISSING_REQUIRED++))
check_config CONFIG_PARAVIRT required "Paravirtualization support" || ((MISSING_REQUIRED++))
check_config CONFIG_KVM_GUEST recommended "KVM-specific optimizations" || ((MISSING_RECOMMENDED++))
echo

echo -e "${BLUE}=== VirtIO Core ===${NC}"
check_config CONFIG_VIRTIO required "Core VirtIO support" || ((MISSING_REQUIRED++))
check_config CONFIG_VIRTIO_PCI required "VirtIO over PCI bus" || ((MISSING_REQUIRED++))
check_config CONFIG_VIRTIO_MMIO recommended "VirtIO over MMIO" || ((MISSING_RECOMMENDED++))
echo

echo -e "${BLUE}=== VirtIO Drivers ===${NC}"
check_config CONFIG_VIRTIO_BLK required "VirtIO block device driver" || ((MISSING_REQUIRED++))
check_config CONFIG_VIRTIO_NET required "VirtIO network device driver" || ((MISSING_REQUIRED++))
check_config CONFIG_VIRTIO_CONSOLE recommended "VirtIO console/serial driver" || ((MISSING_RECOMMENDED++))
check_config CONFIG_HW_RANDOM_VIRTIO recommended "VirtIO RNG for entropy" || ((MISSING_RECOMMENDED++))
check_config CONFIG_VIRTIO_BALLOON recommended "Memory balloon for dynamic memory" || ((MISSING_RECOMMENDED++))
echo

echo -e "${BLUE}=== 9P Filesystem ===${NC}"
check_config CONFIG_NET_9P required "9P protocol support" || ((MISSING_REQUIRED++))
check_config CONFIG_NET_9P_VIRTIO required "9P over VirtIO transport" || ((MISSING_REQUIRED++))
check_config CONFIG_9P_FS required "9P filesystem driver" || ((MISSING_REQUIRED++))
check_config CONFIG_9P_FS_POSIX_ACL recommended "POSIX ACL support for 9P" || ((MISSING_RECOMMENDED++))
check_config CONFIG_9P_FS_SECURITY recommended "Security features for 9P" || ((MISSING_RECOMMENDED++))
echo

echo -e "${BLUE}=== Networking ===${NC}"
check_config CONFIG_NET required "Networking support" || ((MISSING_REQUIRED++))
check_config CONFIG_INET required "TCP/IP networking" || ((MISSING_REQUIRED++))
check_config CONFIG_PACKET recommended "Packet sockets" || ((MISSING_RECOMMENDED++))
check_config CONFIG_UNIX recommended "Unix domain sockets" || ((MISSING_RECOMMENDED++))
echo

echo -e "${BLUE}=== Filesystems ===${NC}"
check_config CONFIG_EXT4_FS required "Ext4 filesystem" || ((MISSING_REQUIRED++))
check_config CONFIG_TMPFS required "tmpfs (RAM-based filesystem)" || ((MISSING_REQUIRED++))
check_config CONFIG_PROC_FS required "/proc filesystem" || ((MISSING_REQUIRED++))
check_config CONFIG_SYSFS required "/sys filesystem" || ((MISSING_REQUIRED++))
check_config CONFIG_DEVTMPFS required "Automatic device node creation" || ((MISSING_REQUIRED++))
echo

echo -e "${BLUE}=== Console and TTY ===${NC}"
check_config CONFIG_TTY required "TTY support" || ((MISSING_REQUIRED++))
check_config CONFIG_SERIAL_8250 recommended "8250/16550 serial driver" || ((MISSING_RECOMMENDED++))
check_config CONFIG_SERIAL_8250_CONSOLE recommended "Serial console support" || ((MISSING_RECOMMENDED++))
echo

echo -e "${BLUE}=== Initrd Support ===${NC}"
check_config CONFIG_BLK_DEV_INITRD required "Initial RAM disk support" || ((MISSING_REQUIRED++))
check_config CONFIG_RD_GZIP recommended "gzip compressed initrd" || ((MISSING_RECOMMENDED++))
check_config CONFIG_RD_XZ recommended "XZ compressed initrd" || ((MISSING_RECOMMENDED++))
echo

echo -e "${BLUE}=== Hardware Support ===${NC}"
check_config CONFIG_PCI required "PCI bus support" || ((MISSING_REQUIRED++))
check_config CONFIG_ACPI recommended "ACPI support" || ((MISSING_RECOMMENDED++))
echo

echo "================================================================"
if [[ $MISSING_REQUIRED -eq 0 ]] && [[ $MISSING_RECOMMENDED -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo "  This kernel is fully compatible with the QEMU sandbox."
    exit 0
elif [[ $MISSING_REQUIRED -eq 0 ]]; then
    echo -e "${YELLOW}⚠ All required features present, but some recommended features are missing.${NC}"
    echo "  Missing recommended features: $MISSING_RECOMMENDED"
    echo "  This kernel should work, but some features may not be optimal."
    exit 0
else
    echo -e "${RED}✗ Verification failed!${NC}"
    echo "  Missing required features: $MISSING_REQUIRED"
    echo "  Missing recommended features: $MISSING_RECOMMENDED"
    echo
    echo "This kernel is NOT compatible with the QEMU sandbox."
    echo "Please rebuild the kernel with the missing features enabled."
    exit 1
fi
