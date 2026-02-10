# Kernel Configuration Reference

This document explains the kernel configuration choices made by `build-qemu-kernel.sh` and why they are necessary for the sandbox environment.

## Configuration Philosophy

The kernel is configured with a **minimal but complete** set of features needed for QEMU virtualization. This approach:
- Reduces build time (compared to full distribution kernels)
- Minimizes kernel size and memory footprint
- Includes only features actually used by the sandbox
- Disables debugging features for better performance

## Core Features

### Virtualization Support

**Why needed:** These features optimize the kernel for running inside a virtual machine.

```
CONFIG_HYPERVISOR_GUEST=y      # Detect and optimize for VM environments
CONFIG_PARAVIRT=y              # Paravirtualization support
CONFIG_PARAVIRT_SPINLOCKS=y    # Efficient spinlocks in VMs
CONFIG_KVM_GUEST=y             # KVM-specific optimizations
```

### VirtIO Drivers

**Why needed:** VirtIO is QEMU's standard for high-performance I/O in virtual machines.

```
CONFIG_VIRTIO=y                           # Core VirtIO support
CONFIG_VIRTIO_PCI=y                       # VirtIO over PCI bus
CONFIG_VIRTIO_PCI_LEGACY=y                # Support for older QEMU versions
CONFIG_VIRTIO_MMIO=y                      # VirtIO over MMIO (alternative transport)
CONFIG_VIRTIO_MMIO_CMDLINE_DEVICES=y      # Allow kernel cmdline device registration
```

### VirtIO Block Devices

**Why needed:** For disk images and block storage in QEMU.

```
CONFIG_VIRTIO_BLK=y            # VirtIO block device driver
CONFIG_SCSI_VIRTIO=y           # VirtIO SCSI support
```

Without these, the kernel cannot access disk images passed to QEMU with `-drive` or `-hda` options.

### VirtIO Network

**Why needed:** For network connectivity inside the VM.

```
CONFIG_VIRTIO_NET=y            # VirtIO network device driver
```

This driver works with QEMU's `-netdev` and `-device virtio-net` options.

### VirtIO Console

**Why needed:** For serial console and logging.

```
CONFIG_VIRTIO_CONSOLE=y        # VirtIO console/serial driver
CONFIG_HW_RANDOM_VIRTIO=y      # VirtIO RNG for entropy
```

### VirtIO Memory Balloon

**Why needed:** The memory balloon device enables dynamic memory management between host and guest.

```
CONFIG_VIRTIO_BALLOON=y        # Memory balloon for dynamic memory
```

The memory balloon driver allows the hypervisor to reclaim memory from the guest VM when needed, or return memory to the guest. This is useful for:
- Overcommitting memory across multiple VMs
- Dynamic memory allocation based on actual usage
- Memory pressure management on the host

**Usage in sandbox:**
Enable the balloon device in your QEMU session configuration:
```go
session := &domain.Session{
    Memory:        "512M",
    BalloonDevice: true,  // Enable virtio-balloon device
    // ... other settings
}
```

### Other VirtIO Features

```
CONFIG_VIRTIO_INPUT=y          # VirtIO input devices (keyboard, mouse)
```

## 9P Filesystem Support

**Why needed:** The sandbox uses 9P to share directories between host and guest without disk images.

```
CONFIG_NET_9P=y                # 9P protocol support
CONFIG_NET_9P_VIRTIO=y         # 9P over VirtIO transport
CONFIG_9P_FS=y                 # 9P filesystem driver
CONFIG_9P_FS_POSIX_ACL=y       # POSIX ACL support for 9P
CONFIG_9P_FS_SECURITY=y        # Security features for 9P
```

**Usage in sandbox:**
```go
FSShares: []domain.FSShare{
    {
        HostPath:   "/path/on/host",
        MountTag:   "host_share",
        MountPoint: "/mnt/host",
        ReadOnly:   true,
    },
}
```

**QEMU options generated:**
```
-virtfs local,path=/path/on/host,mount_tag=host_share,security_model=mapped-xattr,readonly=on
```

## Networking

**Why needed:** For network configuration and connectivity in the VM.

```
CONFIG_NET=y                   # Networking support
CONFIG_INET=y                  # TCP/IP networking
CONFIG_PACKET=y                # Packet sockets (for raw network access)
CONFIG_UNIX=y                  # Unix domain sockets
CONFIG_IPV6=y                  # IPv6 support
CONFIG_NETDEVICES=y            # Network device support
CONFIG_NET_CORE=y              # Core networking options
```

## Filesystem Support

**Why needed:** For mounting disk images and managing in-VM filesystems.

### Ext Filesystems
```
CONFIG_EXT4_FS=y               # Ext4 filesystem
CONFIG_EXT4_FS_POSIX_ACL=y     # POSIX ACLs for ext4
CONFIG_EXT4_FS_SECURITY=y      # Security labels for ext4
CONFIG_EXT3_FS=y               # Ext3 filesystem
CONFIG_EXT2_FS=y               # Ext2 filesystem
```

The sandbox creates ext4 disk images, so ext4 support is essential.

### Virtual Filesystems
```
CONFIG_TMPFS=y                 # tmpfs (RAM-based filesystem)
CONFIG_TMPFS_POSIX_ACL=y       # POSIX ACLs for tmpfs
CONFIG_PROC_FS=y               # /proc filesystem
CONFIG_SYSFS=y                 # /sys filesystem
CONFIG_DEVTMPFS=y              # Automatic device node creation
CONFIG_DEVTMPFS_MOUNT=y        # Auto-mount devtmpfs at boot
```

These are needed for basic system functionality and the init system.

## Console and TTY

**Why needed:** For serial console output and debugging.

```
CONFIG_TTY=y                   # TTY support
CONFIG_SERIAL_8250=y           # 8250/16550 serial driver
CONFIG_SERIAL_8250_CONSOLE=y   # Serial console support
CONFIG_PRINTK=y                # Kernel logging
```

**QEMU usage:**
```bash
qemu-system-x86_64 -nographic -append "console=ttyS0"
```

## Initrd Support

**Why needed:** The sandbox uses initrd to bootstrap the custom init system.

```
CONFIG_BLK_DEV_INITRD=y        # Initial RAM disk support
CONFIG_RD_GZIP=y               # gzip compressed initrd
CONFIG_RD_BZIP2=y              # bzip2 compressed initrd
CONFIG_RD_LZMA=y               # LZMA compressed initrd
CONFIG_RD_XZ=y                 # XZ compressed initrd
CONFIG_RD_LZO=y                # LZO compressed initrd
CONFIG_RD_LZ4=y                # LZ4 compressed initrd
CONFIG_RD_ZSTD=y               # Zstandard compressed initrd
```

Multiple compression formats allow flexibility in initrd creation.

## Hardware Support

### PCI
```
CONFIG_PCI=y                   # PCI bus support
CONFIG_PCI_MSI=y               # Message Signaled Interrupts
```

VirtIO devices typically use PCI in QEMU.

### ACPI
```
CONFIG_ACPI=y                  # ACPI support
```

For power management and device configuration.

## Module Support

**Why needed:** Allows loading additional drivers if needed.

```
CONFIG_MODULES=y               # Loadable module support
CONFIG_MODULE_UNLOAD=y         # Allow module unloading
```

## Binary Formats

**Why needed:** For executing programs in the VM.

```
CONFIG_BINFMT_ELF=y            # ELF binary support
CONFIG_BINFMT_SCRIPT=y         # Script (#!) support
```

## System Features

**Why needed:** Standard POSIX and Linux features used by userspace.

```
CONFIG_POSIX_TIMERS=y          # POSIX timers
CONFIG_FUTEX=y                 # Fast userspace mutexes
CONFIG_EPOLL=y                 # Event polling mechanism
CONFIG_SIGNALFD=y              # Signal file descriptors
CONFIG_TIMERFD=y               # Timer file descriptors
CONFIG_EVENTFD=y               # Event file descriptors
```

## Disabled Features

### Debugging
```
CONFIG_DEBUG_KERNEL=n          # Kernel debugging features
CONFIG_DEBUG_INFO=n            # Debug information
CONFIG_DEBUG_INFO_BTF=n        # BTF debug info
CONFIG_GDB_SCRIPTS=n           # GDB helper scripts
```

**Why disabled:** These features significantly increase kernel size and build time. They're only needed when debugging kernel issues.

**When to enable:** If you need to debug kernel crashes or modules, re-enable these features:
```bash
cd build/kernel-source/linux-x.x.x
scripts/config --enable CONFIG_DEBUG_KERNEL
scripts/config --enable CONFIG_DEBUG_INFO
make olddefconfig
make -j$(nproc) bzImage modules
```

## Customizing the Configuration

### Adding New Features

To add additional kernel features, edit the `configure_kernel()` function in `build-qemu-kernel.sh`:

```bash
configure_kernel() {
    local kernel_dir="$1"
    cd "$kernel_dir"
    make defconfig
    
    # Your custom configuration here
    scripts/config --enable CONFIG_YOUR_FEATURE
    scripts/config --module CONFIG_YOUR_MODULE
    
    make olddefconfig
}
```

### Interactive Configuration

For interactive configuration using menuconfig:

```bash
# Build source and configure
./scripts/build-qemu-kernel.sh --kernel-version 6.12.4

# Enter the source directory
cd build/kernel-source/linux-6.12.4

# Run menuconfig
make menuconfig

# Build with your custom config
make -j$(nproc) bzImage modules
make INSTALL_MOD_PATH="../../kernel" modules_install
cp arch/x86_64/boot/bzImage ../../kernel/vmlinuz
```

### Checking Current Configuration

To see what's enabled in a built kernel:

```bash
# View full configuration
cat build/kernel/config-6.12.4

# Search for specific options
grep VIRTIO build/kernel/config-6.12.4

# Check if a feature is enabled
grep CONFIG_9P_FS build/kernel/config-6.12.4
```

### Verifying Required Features

After building a kernel, verify it has the required features:

```bash
#!/bin/bash
KERNEL_CONFIG="build/kernel/config-6.12.4"

check_config() {
    local option=$1
    if grep -q "^${option}=y" "$KERNEL_CONFIG" || grep -q "^${option}=m" "$KERNEL_CONFIG"; then
        echo "✓ $option is enabled"
    else
        echo "✗ $option is NOT enabled"
    fi
}

echo "Checking critical features:"
check_config CONFIG_VIRTIO
check_config CONFIG_VIRTIO_BLK
check_config CONFIG_VIRTIO_NET
check_config CONFIG_NET_9P_VIRTIO
check_config CONFIG_9P_FS
```

## Common Configuration Issues

### "modprobe: FATAL: Module not found"

**Problem:** A required feature is not built into the kernel or as a module.

**Solution:** Add the feature to the kernel configuration:
```bash
scripts/config --enable CONFIG_MISSING_FEATURE
# or
scripts/config --module CONFIG_MISSING_FEATURE  # Build as module
```

### "Cannot mount 9p filesystem"

**Problem:** 9P support is not enabled.

**Solution:** Ensure these are enabled:
```
CONFIG_NET_9P=y
CONFIG_NET_9P_VIRTIO=y
CONFIG_9P_FS=y
```

### "No virtio block device detected"

**Problem:** VirtIO block support is missing.

**Solution:** Enable:
```
CONFIG_VIRTIO_BLK=y
CONFIG_SCSI_VIRTIO=y
```

### "Kernel doesn't boot"

**Problem:** Essential features are missing.

**Solution:** Ensure at minimum these are enabled:
```
CONFIG_TTY=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_EXT4_FS=y
CONFIG_DEVTMPFS=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
```

## Performance Tuning

### Smaller Kernel

For faster builds and smaller size:
```bash
scripts/config --disable CONFIG_MODULES  # No module support
scripts/config --disable CONFIG_IPV6     # If not needed
scripts/config --set-val CONFIG_LOG_BUF_SHIFT 15  # Smaller log buffer
```

### Faster Boot

```bash
scripts/config --enable CONFIG_PREEMPT    # Better responsiveness
scripts/config --enable CONFIG_NO_HZ_FULL # Reduce timer interrupts
```

## Further Reading

- [Linux Kernel Configuration Documentation](https://www.kernel.org/doc/html/latest/admin-guide/README.html)
- [KVM Guest Kernel Configuration](https://www.linux-kvm.org/page/Guest_Support_Status)
- [VirtIO Specification](https://docs.oasis-open.org/virtio/virtio/v1.1/virtio-v1.1.html)
- [9P Protocol](https://www.kernel.org/doc/Documentation/filesystems/9p.txt)
