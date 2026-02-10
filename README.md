# QEMU Assets Build System

A multiplatform build system for creating QEMU-ready Linux kernel images, initrd files, and filesystem utilities for both AMD64 and ARM64 architectures.

## Quick Start

```bash
# Install dependencies
make setup-dev

# Build all architectures
make build

# Create release tarball
make release
```

The build will produce artifacts in the following structure:
```
build/
├── amd64/
│   ├── e2fsck       # Ext4 filesystem check utility
│   ├── mke2fs       # Ext4 filesystem creation utility
│   ├── initrd.gz    # Debian Trixie initrd
│   └── vmlinuz      # Linux kernel
├── arm64/
│   ├── e2fsck
│   ├── mke2fs
│   ├── initrd.gz
│   └── vmlinuz
└── release.tar.gz   # Distributable tarball
```

## Features

- **Multiplatform Support**: Build for AMD64 and ARM64 architectures
- **Cross-Compilation**: ARM64 binaries can be built on AMD64 hosts
- **Static Linking**: All e2fsprogs binaries are statically linked for portability
- **QEMU-Optimized Kernels**: Kernels configured with VirtIO, 9P, and essential features
- **Automated Downloads**: Initrd files automatically downloaded from Debian mirrors
- **Shared Sources**: Efficient use of disk space with shared source directories

## Available Make Targets

### Main Targets

| Target | Description |
|--------|-------------|
| `make build` | Build all architectures (AMD64 and ARM64) |
| `make release` | Create release tarball with all artifacts |
| `make clean` | Remove all build artifacts |
| `make setup-dev` | Install required development dependencies |

### Architecture-Specific Targets

#### AMD64
| Target | Description |
|--------|-------------|
| `make build-amd64` | Build complete AMD64 bundle |
| `make kernel-amd64` | Build Linux kernel for AMD64 |
| `make e2fsprogs-amd64` | Build e2fsprogs for AMD64 |
| `make initrd-amd64` | Download Debian Trixie initrd for AMD64 |

#### ARM64
| Target | Description |
|--------|-------------|
| `make build-arm64` | Build complete ARM64 bundle |
| `make kernel-arm64` | Cross-compile Linux kernel for ARM64 |
| `make e2fsprogs-arm64` | Cross-compile e2fsprogs for ARM64 |
| `make initrd-arm64` | Download Debian Trixie initrd for ARM64 |

## Build Configuration

Customize builds using environment variables or make parameters:

```bash
# Use specific kernel version
make build KERNEL_VERSION=6.11.0

# Use specific e2fsprogs version
make build E2FSPROGS_VERSION=1.47.0

# Control parallel build jobs
make build JOBS=8

# Combine options
make build KERNEL_VERSION=6.12.0 JOBS=16
```

## System Requirements

### For AMD64 Builds
- Debian/Ubuntu Linux (or similar)
- Build tools: gcc, make, bison, flex
- At least 10GB free disk space
- 2+ CPU cores recommended

### For ARM64 Builds (Cross-Compilation)
All AMD64 requirements plus:
- ARM64 cross-compilation toolchain (`gcc-aarch64-linux-gnu`)
- ARM64 binutils (`binutils-aarch64-linux-gnu`)

Dependencies are automatically installed by `make setup-dev`.

## Testing

### Verify Binaries

```bash
# Check binary types
file build/amd64/vmlinuz build/amd64/e2fsck
file build/arm64/vmlinuz build/arm64/e2fsck

# Verify static linking
ldd build/amd64/e2fsck  # Should show "not a dynamic executable"
```

### Test with QEMU

#### AMD64
```bash
qemu-system-x86_64 \
  -kernel build/amd64/vmlinuz \
  -initrd build/amd64/initrd.gz \
  -m 1G \
  -nographic \
  -append "console=ttyS0"
```

#### ARM64
```bash
qemu-system-aarch64 \
  -machine virt \
  -cpu cortex-a57 \
  -kernel build/arm64/vmlinuz \
  -initrd build/arm64/initrd.gz \
  -m 1G \
  -nographic \
  -append "console=ttyAMA0"
```

Press `Ctrl+A` then `X` to exit QEMU.

## Release Workflow

Complete workflow for creating a distributable release:

```bash
# Clean previous builds
make clean

# Build all architectures
make build

# Create release tarball
make release
```

The `release.tar.gz` file contains all binaries organized by architecture and can be distributed or deployed to production systems.

## Scripts

The build system consists of several scripts in the `scripts/` directory:

| Script | Purpose |
|--------|---------|
| `build-qemu-kernel.sh` | Downloads, configures, and compiles Linux kernel |
| `build-e2fsprogs.sh` | Builds e2fsprogs utilities with static linking |
| `download-qemu-initrd.sh` | Downloads Debian Trixie initrd images |
| `setup-dev-dependencies.sh` | Installs required build dependencies |
| `verify-kernel-config.sh` | Validates kernel configuration |

All scripts support `--help` for detailed usage information.

## Credits

- **Linux Kernel**: https://kernel.org
- **E2fsprogs**: http://e2fsprogs.sourceforge.net
- **Debian**: https://www.debian.org (for initrd images)

## Version Information

- **Default Kernel Version**: 6.12.4
- **Default E2fsprogs Version**: 1.47.1
- **Debian Version**: Trixie (testing)
- **Supported Architectures**: AMD64 (x86_64), ARM64 (aarch64)
