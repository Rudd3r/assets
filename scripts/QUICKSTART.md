# Quick Start Guide: Building a QEMU Kernel

This guide will walk you through building a custom kernel for the QEMU sandbox in just a few steps.

## Prerequisites

- Debian Trixie (or compatible Linux distribution)
- At least 15 GB of free disk space
- About 20-30 minutes for the build (depending on your CPU)

## Step 1: Build the Kernel

Run the build script with default settings:

```bash
./scripts/build-qemu-kernel.sh
```

The script will:
1. Install all required build dependencies (using sudo if needed)
2. Download Linux kernel 6.12.4 from kernel.org
3. Configure it with all QEMU features (virtio, 9p, networking)
4. Compile the kernel and modules
5. Install to `build/kernel/`

**Expected output:**
```
[INFO] QEMU Kernel Build Script
[INFO] =========================
[INFO] Kernel Version: 6.12.4
[INFO] Parallel Jobs: 8
[INFO] Output Directory: /path/to/sandbox/build/kernel
[INFO] Source Directory: /path/to/sandbox/build/kernel-source

[INFO] Installing build dependencies...
[INFO] Downloading kernel source 6.12.4...
[INFO] Downloading from https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.4.tar.xz...
[INFO] Extracting kernel source...
[INFO] Configuring kernel for QEMU...
[INFO] Building kernel (this may take a while)...
[INFO] Installing kernel to /path/to/sandbox/build/kernel...

[SUCCESS] ===========================
[SUCCESS] Kernel build complete!
[SUCCESS] ===========================

[INFO] Kernel image: /path/to/sandbox/build/kernel/vmlinuz
[INFO] Kernel version: 6.12.4
[INFO] Modules: /path/to/sandbox/build/kernel/lib/modules/6.12.4
```

## Step 2: Verify the Kernel

Check that the kernel has all required features:

```bash
./scripts/verify-kernel-config.sh build/kernel/config-6.12.4
```

You should see all green checkmarks (✓) for required features.

## Step 3: Use the Kernel with Sandbox

### Option A: Build and run the example

```bash
# Build the raftinit binary
make build

# Run with your custom kernel
make example -- --kernel=./build/kernel/vmlinuz
```

### Option B: Run directly with Go

```bash
go run examples/qemu_basic.go --kernel=./build/kernel/vmlinuz
```

### Option C: Use with QEMU directly

```bash
qemu-system-x86_64 \
  -kernel build/kernel/vmlinuz \
  -initrd your-initrd.gz \
  -append "console=ttyS0 init=/sandboxinit" \
  -drive file=disk.ext4,if=virtio,format=raw \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -m 512M \
  -smp 2 \
  -nographic
```

## What You've Built

Your kernel now includes:

✓ **VirtIO Drivers**
- Block devices (virtio-blk)
- Network (virtio-net)
- Console (virtio-console)
- Memory balloon (virtio-balloon)

✓ **9P Filesystem**
- Share host directories with guest VMs
- No need for disk images for shared files

✓ **Networking**
- Full TCP/IP stack (IPv4 and IPv6)
- Unix domain sockets
- Packet sockets

✓ **Filesystems**
- ext4 (for disk images)
- tmpfs, procfs, sysfs, devtmpfs

✓ **Other Features**
- Serial console support
- Initrd with multiple compression formats
- PCI and ACPI support

## Troubleshooting

### Build is slow

Use more CPU cores:
```bash
./scripts/build-qemu-kernel.sh --jobs 16
```

### Out of space

Use a different output directory:
```bash
./scripts/build-qemu-kernel.sh --output /path/to/larger/disk
```

### Need a different kernel version

```bash
./scripts/build-qemu-kernel.sh --kernel-version 6.11.0
```

### Permission errors during dependency installation

Make sure you have sudo access, or install dependencies manually:
```bash
sudo apt-get install build-essential bc bison flex libelf-dev \
  libssl-dev libncurses-dev kmod cpio wget xz-utils git \
  fakeroot dwarves rsync python3

# Then build without dependency installation
./scripts/build-qemu-kernel.sh --skip-install
```

## Next Steps

- Read [KERNEL_CONFIG.md](KERNEL_CONFIG.md) to understand the kernel configuration
- Read [README.md](README.md) for detailed usage and options
- Try different kernel versions
- Customize the configuration in `build-qemu-kernel.sh`

## Advanced Usage

### Build multiple kernel versions

```bash
# Build 6.11.0 in a separate directory
./scripts/build-qemu-kernel.sh \
  --kernel-version 6.11.0 \
  --output ./build/kernel-6.11

# Build 6.12.4 in another directory
./scripts/build-qemu-kernel.sh \
  --kernel-version 6.12.4 \
  --output ./build/kernel-6.12
```

### Rebuild after changes

```bash
# Clean and rebuild
./scripts/build-qemu-kernel.sh --clean
```

### Interactive kernel configuration

```bash
# Build the source
./scripts/build-qemu-kernel.sh --kernel-version 6.12.4

# Manually configure
cd build/kernel-source/linux-6.12.4
make menuconfig

# Build with your custom config
make -j$(nproc) bzImage modules
make INSTALL_MOD_PATH="../../kernel" modules_install
cp arch/x86_64/boot/bzImage ../../kernel/vmlinuz
```

## Build Time Reference

Typical build times on different systems:

| CPU Cores | Build Time |
|-----------|------------|
| 4 cores   | 20-30 min  |
| 8 cores   | 10-15 min  |
| 16 cores  | 5-8 min    |
| 32 cores  | 3-5 min    |

*Times are approximate and depend on CPU speed and disk I/O.*

## Getting Help

- Check the detailed documentation: [README.md](README.md)
- Understand kernel configuration: [KERNEL_CONFIG.md](KERNEL_CONFIG.md)
- Verify your kernel: `./scripts/verify-kernel-config.sh build/kernel/config-VERSION`
- Check the main project README: [../README.md](../README.md)
