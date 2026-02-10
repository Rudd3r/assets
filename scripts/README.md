# Scripts

This directory contains utility scripts for building and managing components of the sandbox environment.

## Quick Start

**New to this project?** Start by setting up your development environment:

```bash
./scripts/setup-dev-dependencies.sh
```

This will install Go and QEMU, the two essential tools needed to build and test the project.

**New to kernel building?** Check out the [QUICKSTART.md](QUICKSTART.md) guide for a step-by-step walkthrough.

## Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Step-by-step guide to building your first QEMU kernel
- **[README.md](README.md)** (this file) - Detailed script documentation and usage
- **[KERNEL_CONFIG.md](KERNEL_CONFIG.md)** - In-depth kernel configuration reference

## setup-dev-dependencies.sh

A comprehensive script for installing and configuring development dependencies required to build and test the sandbox project.

### What It Installs

The script installs:
- **Go** (version 1.24.0 or later) - Required for building the project
- **QEMU** (qemu-system-x86_64 and related tools) - Required for running examples and tests

### Usage

#### Basic Usage

```bash
# Install both Go and QEMU with default settings
./scripts/setup-dev-dependencies.sh

# Install specific Go version
./scripts/setup-dev-dependencies.sh --go-version 1.24.4

# Skip Go installation (only install QEMU)
./scripts/setup-dev-dependencies.sh --skip-go

# Skip QEMU installation (only install Go)
./scripts/setup-dev-dependencies.sh --skip-qemu
```

#### Advanced Options

```bash
./scripts/setup-dev-dependencies.sh [OPTIONS]

Options:
  --go-version VERSION       Go version to install (default: 1.24.4)
  --skip-go                  Skip Go installation
  --skip-qemu                Skip QEMU installation
  --go-install-method METHOD Go installation method: 'official' or 'apt' (default: official)
  -h, --help                 Show this help message
```

### Go Installation Methods

The script supports two methods for installing Go:

#### Official (Recommended)

```bash
./scripts/setup-dev-dependencies.sh --go-install-method official
```

This method:
- Downloads the official Go binary from go.dev
- Installs to `/usr/local` (if run as root) or `~/.local` (if run as regular user)
- Guarantees the exact version you specify
- Works on all supported platforms
- Automatically updates your shell profile (`.bashrc`, `.bash_profile`, or `.zshrc`)

#### APT (Debian/Ubuntu only)

```bash
./scripts/setup-dev-dependencies.sh --go-install-method apt
```

This method:
- Uses the system package manager (APT)
- May provide an older version than requested
- Only available on Debian/Ubuntu systems
- Integrates with system package management

### Supported Systems

The script supports:
- **Linux distributions**: Ubuntu, Debian, Fedora, RHEL, CentOS, Arch, Manjaro
- **macOS**: Via Homebrew (QEMU only; Go uses official installer)
- **Architectures**: x86_64 (amd64), ARM64 (aarch64)

### Examples

**First-time setup:**
```bash
# Install everything with defaults
./scripts/setup-dev-dependencies.sh
```

**Update Go to a newer version:**
```bash
# Install specific Go version
./scripts/setup-dev-dependencies.sh --go-version 1.24.4
```

**Install only QEMU (Go already installed):**
```bash
./scripts/setup-dev-dependencies.sh --skip-go
```

**Install only Go (QEMU already installed):**
```bash
./scripts/setup-dev-dependencies.sh --skip-qemu
```

**Use APT for Go on Ubuntu/Debian:**
```bash
./scripts/setup-dev-dependencies.sh --go-install-method apt
```

### Environment Variables

You can also use environment variables instead of command-line options:

```bash
export GO_VERSION=1.24.4
export GO_INSTALL_METHOD=official
./scripts/setup-dev-dependencies.sh
```

### Verification

The script automatically verifies installations and provides detailed output:

```
[INFO] Checking Go installation...
[SUCCESS] Go 1.24.4 installed successfully!
[INFO] Go binary: /usr/local/go/bin/go

[INFO] Checking QEMU installation...
[SUCCESS] QEMU installed successfully: QEMU emulator version 8.0.0
[INFO] QEMU binary: /usr/bin/qemu-system-x86_64
```

### Troubleshooting

#### Permission Issues

If you encounter permission errors:
- For system-wide installation (to `/usr/local`), run with `sudo`
- For user-local installation, run without `sudo` (installs to `~/.local`)

#### Go Not in PATH

If `go` is not found after installation:
1. Restart your shell: `source ~/.bashrc` (or `.zshrc`, `.bash_profile`)
2. Or manually add to PATH: `export PATH="/usr/local/go/bin:$PATH"`

#### QEMU Missing on macOS

If QEMU installation fails on macOS:
1. Ensure Homebrew is installed: `https://brew.sh/`
2. Run `brew install qemu` manually

#### Older Go Version from APT

If APT installs an older Go version:
- Use `--go-install-method official` to get the latest version
- Or manually install from https://go.dev/dl/

## build-qemu-kernel.sh

A comprehensive script for building a Linux kernel optimized for QEMU with all necessary features for the sandbox environment.

### Features

The built kernel includes support for:
- **VirtIO** devices (block, network, console, balloon, etc.)
- **9P filesystem** for host-guest file sharing
- **Network** configuration (IPv4, IPv6)
- **Standard filesystems** (ext4, tmpfs, procfs, sysfs)
- **Initrd** with multiple compression formats
- **Serial console** for debugging
- **PCI and ACPI** support

### Usage

#### Basic Usage

```bash
# Build kernel with default settings (version 6.12.4)
./scripts/build-qemu-kernel.sh

# Build a specific kernel version
./scripts/build-qemu-kernel.sh --kernel-version 6.11.0

# Use more CPU cores for faster compilation
./scripts/build-qemu-kernel.sh --jobs 8

# Clean build (removes existing source directory)
./scripts/build-qemu-kernel.sh --clean
```

#### Advanced Options

```bash
./scripts/build-qemu-kernel.sh [OPTIONS]

Options:
  -k, --kernel-version VERSION   Kernel version to build (default: 6.12.4)
  -j, --jobs N                   Number of parallel jobs (default: nproc)
  -o, --output DIR               Output directory (default: ./build/kernel)
  -s, --source DIR               Source directory (default: ./build/kernel-source)
  --skip-install                 Skip installing dependencies
  --clean                        Clean build directory before building
  -h, --help                     Show this help message
```

#### Custom Output Location

```bash
# Build and install to a custom directory
./scripts/build-qemu-kernel.sh --output /path/to/custom/output
```

### Dependencies

The script will automatically install all required dependencies on Debian/Ubuntu systems:
- build-essential
- bc, bison, flex
- libelf-dev, libssl-dev, libncurses-dev
- kmod, cpio
- wget, xz-utils
- git, fakeroot
- dwarves, rsync
- python3

To skip dependency installation (if already installed):
```bash
./scripts/build-qemu-kernel.sh --skip-install
```

### Output

After successful completion, the following files will be available in `build/kernel/`:

- `vmlinuz` - The kernel image (symlink to versioned image)
- `vmlinuz-{VERSION}` - The actual kernel image
- `config-{VERSION}` - Kernel configuration file
- `System.map-{VERSION}` - Kernel symbol map
- `lib/modules/{VERSION}/` - Kernel modules

### Using the Built Kernel

#### With the Sandbox Examples

```bash
# Build the init binary first
make build

# Run the example with custom kernel
make example -- --kernel=./build/kernel/vmlinuz
```

Or directly with Go:

```bash
go run examples/qemu_basic.go --kernel=./build/kernel/vmlinuz
```

#### With QEMU Directly

```bash
qemu-system-x86_64 \
  -kernel ./build/kernel/vmlinuz \
  -initrd <your-initrd> \
  -append "console=ttyS0" \
  -nographic
```

### Build Time

Typical build times (depending on system):
- 4 cores: ~15-25 minutes
- 8 cores: ~8-15 minutes
- 16 cores: ~5-10 minutes

### Troubleshooting

#### Build fails with "No space left on device"

The kernel build requires significant disk space (~10-15 GB for source and build artifacts). Free up space or use a different output directory with more space:

```bash
./scripts/build-qemu-kernel.sh --output /path/to/larger/disk
```

#### Missing dependencies on non-Debian systems

If you're not on a Debian-based system, you'll need to manually install the equivalent packages for your distribution. Use `--skip-install` to skip the automatic installation.

#### Build is taking too long

Reduce the number of jobs if your system is running out of memory:

```bash
./scripts/build-qemu-kernel.sh --jobs 2
```

### Kernel Configuration

The script configures the kernel with a minimal set of features optimized for QEMU. The configuration includes:

**VirtIO Drivers:**
- virtio-pci, virtio-mmio
- virtio-blk (block devices)
- virtio-net (networking)
- virtio-console (console/serial)
- virtio-balloon (memory management)

**9P Filesystem:**
- 9pfs with VirtIO transport
- POSIX ACL and security features

**Networking:**
- TCP/IP stack (IPv4 and IPv6)
- Unix domain sockets
- Packet sockets

**Filesystems:**
- ext2/ext3/ext4 with POSIX ACL
- tmpfs, procfs, sysfs
- devtmpfs with auto-mount

**Other Features:**
- Hypervisor guest support
- KVM guest optimizations
- PCI and ACPI support
- Serial console (8250)
- Initrd with multiple compression formats

To customize the configuration, edit the `configure_kernel()` function in the script.

### Environment Variables

You can also use environment variables instead of command-line options:

```bash
export KERNEL_VERSION=6.11.0
export JOBS=8
export OUTPUT_DIR=/custom/path
./scripts/build-qemu-kernel.sh
```

### Examples

**Quick build for testing:**
```bash
# Fast build with minimum features
./scripts/build-qemu-kernel.sh --kernel-version 6.12.4 --jobs $(nproc)
```

**Build multiple versions:**
```bash
# Build different kernel versions in separate directories
./scripts/build-qemu-kernel.sh --kernel-version 6.11.0 --output ./build/kernel-6.11
./scripts/build-qemu-kernel.sh --kernel-version 6.12.4 --output ./build/kernel-6.12
```

**Rebuild after configuration changes:**
```bash
# Clean and rebuild
./scripts/build-qemu-kernel.sh --clean
```

## verify-kernel-config.sh

A verification script that checks if a kernel configuration includes all features required for the QEMU sandbox environment.

### Usage

```bash
# Verify a built kernel
./scripts/verify-kernel-config.sh build/kernel/config-6.12.4

# Verify the running system kernel
./scripts/verify-kernel-config.sh /boot/config-$(uname -r)

# Verify kernel configuration during build
./scripts/verify-kernel-config.sh build/kernel-source/linux-6.12.4/.config
```

### What It Checks

The script verifies the presence of:
- **Required features** - Must be present for the sandbox to work
  - VirtIO core and drivers (block, network)
  - 9P filesystem support
  - Essential filesystems (ext4, tmpfs, proc, sys)
  - Networking stack
  - Initrd support
  
- **Recommended features** - Should be present for optimal operation
  - VirtIO console and balloon
  - Serial console support
  - Additional compression formats
  - ACPI support

### Exit Codes

- `0` - All checks passed
- `1` - One or more required features missing
- `2` - Invalid usage or file not found

### Example Output

```
Verifying kernel configuration: build/kernel/config-6.12.4

=== Core Virtualization ===
✓ CONFIG_HYPERVISOR_GUEST
✓ CONFIG_PARAVIRT
✓ CONFIG_KVM_GUEST

=== VirtIO Core ===
✓ CONFIG_VIRTIO
✓ CONFIG_VIRTIO_PCI
✓ CONFIG_VIRTIO_MMIO
...

================================================================
✓ All checks passed!
  This kernel is fully compatible with the QEMU sandbox.
```

## build-e2fsprogs.sh

A comprehensive script for building e2fsprogs utilities (mke2fs and e2fsck) for multiple architectures. This is useful for creating filesystem utilities that can be embedded in initrd images for different platforms.

### Features

- Builds statically-linked binaries for easy deployment
- Cross-compilation support for ARM, ARM64, and AMD64
- Parallel builds for faster compilation
- Reproducible builds with SOURCE_DATE_EPOCH

### Usage

#### Basic Usage

```bash
# Build for all architectures (default)
./scripts/build-e2fsprogs.sh

# Build for a specific architecture
./scripts/build-e2fsprogs.sh --arch amd64
./scripts/build-e2fsprogs.sh --arch arm64
./scripts/build-e2fsprogs.sh --arch arm

# Build a specific version
./scripts/build-e2fsprogs.sh --version 1.47.1
```

#### Platform-Specific Scripts

For convenience, platform-specific wrapper scripts are provided:

```bash
# Build only for ARM (32-bit)
./scripts/build-e2fsprogs-arm.sh

# Build only for ARM64
./scripts/build-e2fsprogs-arm64.sh

# Build only for AMD64
./scripts/build-e2fsprogs-amd64.sh
```

#### Advanced Options

```bash
./scripts/build-e2fsprogs.sh [OPTIONS]

Options:
  -v, --version VERSION          E2fsprogs version to build (default: 1.47.1)
  -j, --jobs N                   Number of parallel jobs (default: nproc)
  -o, --output DIR               Output directory (default: ./build/e2fsprogs)
  -s, --source DIR               Source directory (default: ./build/e2fsprogs-source)
  -a, --arch ARCH                Architecture to build (arm, arm64, amd64, or all) (default: all)
  --skip-install                 Skip installing dependencies
  --clean                        Clean build directory before building
  -h, --help                     Show this help message
```

### Dependencies

The script will automatically install all required dependencies on Debian/Ubuntu systems:
- build-essential
- crossbuild-essential-armel (for ARM)
- crossbuild-essential-arm64 (for ARM64)
- curl, wget
- pkg-config
- Development libraries (libblkid-dev, uuid-dev, libssl-dev)

To skip dependency installation:
```bash
./scripts/build-e2fsprogs.sh --skip-install
```

### Output

After successful completion, binaries will be available in `build/e2fsprogs/`:

```
build/e2fsprogs/
├── arm/
│   ├── mke2fs
│   └── e2fsck
├── arm64/
│   ├── mke2fs
│   └── e2fsck
└── amd64/
    ├── mke2fs
    └── e2fsck
```

All binaries are statically linked and can be copied directly to initrd images or embedded systems.

### Build Time

Typical build times per architecture (depending on system):
- 4 cores: ~2-4 minutes per architecture
- 8 cores: ~1-2 minutes per architecture
- All architectures: ~3-8 minutes total

### Using the Built Binaries

#### In Initrd Images

```bash
# Copy to initrd structure
cp build/e2fsprogs/amd64/mke2fs /path/to/initrd/sbin/
cp build/e2fsprogs/amd64/e2fsck /path/to/initrd/sbin/
```

#### Direct Usage

```bash
# Create a filesystem
./build/e2fsprogs/amd64/mke2fs /dev/loop0

# Check a filesystem
./build/e2fsprogs/amd64/e2fsck -f /dev/loop0
```

### Verification

The script automatically verifies that binaries are statically linked:

```bash
# Verify a binary is static
file build/e2fsprogs/amd64/mke2fs
# Output should include: "statically linked"

# Check binary dependencies (should be none)
ldd build/e2fsprogs/amd64/mke2fs
# Output: "not a dynamic executable"
```

### Environment Variables

You can use environment variables instead of command-line options:

```bash
export E2FSPROGS_VERSION=1.47.1
export JOBS=8
export OUTPUT_DIR=/custom/path
export ARCH=arm64
./scripts/build-e2fsprogs.sh
```

### Examples

**Build for embedded ARM device:**
```bash
./scripts/build-e2fsprogs-arm.sh --jobs $(nproc)
```

**Build all architectures with custom output:**
```bash
./scripts/build-e2fsprogs.sh --output /opt/e2fsprogs-bins
```

**Quick rebuild:**
```bash
./scripts/build-e2fsprogs.sh --clean --arch amd64
```

**Build specific version for Raspberry Pi (ARM64):**
```bash
./scripts/build-e2fsprogs-arm64.sh --version 1.47.1
```

## build-qemu-static.sh

A comprehensive script for building a statically-linked version of QEMU for Linux. This allows bundling QEMU with the project instead of relying on system-installed versions.

### Features

- Static or mostly-static QEMU builds
- Optional musl-libc support for fully portable binaries
- Configurable target architectures
- Automatic dependency installation
- Parallel builds for faster compilation

### Usage

#### Basic Usage

```bash
# Build QEMU with default settings (version 9.1.0)
./scripts/build-qemu-static.sh

# Build a specific QEMU version
./scripts/build-qemu-static.sh --qemu-version 9.0.0

# Build with more CPU cores for faster compilation
./scripts/build-qemu-static.sh --jobs 8
```

#### Advanced Options

```bash
./scripts/build-qemu-static.sh [OPTIONS]

Options:
  -v, --qemu-version VERSION    QEMU version to build (default: 9.1.0)
  -j, --jobs N                  Number of parallel jobs (default: nproc)
  -o, --output DIR              Output directory (default: ./build/qemu)
  -s, --source DIR              Source directory (default: ./build/qemu-source)
  -t, --targets TARGETS         Comma-separated list of targets (default: x86_64-softmmu)
  --skip-install                Skip installing dependencies
  --clean                       Clean build directory before building
  --musl                        Use musl-libc for truly static builds
  -h, --help                    Show this help message
```

### Build Approaches

#### Default (glibc, mostly-static)

```bash
# Build with glibc
./scripts/build-qemu-static.sh
```

This creates a mostly-static build that:
- Links most libraries statically
- May have some dynamic dependencies (glibc, pthread)
- Works on most modern Linux distributions
- Easier to build and more compatible

#### Fully Static (musl-libc)

```bash
# Build with musl for maximum portability
./scripts/build-qemu-static.sh --musl
```

This creates a fully static build that:
- Has no dynamic dependencies
- Works on any Linux distribution
- More portable across different systems
- Requires musl-tools to be installed

### Dependencies

The script will automatically install all required dependencies on Debian/Ubuntu systems:
- build-essential, pkg-config, ninja-build
- python3, python3-pip (for meson)
- git, wget, curl
- libglib2.0-dev, libpixman-1-dev, libslirp-dev
- libcap-ng-dev, libattr1-dev
- flex, bison
- musl-tools, musl-dev (for musl builds)

To skip dependency installation:
```bash
./scripts/build-qemu-static.sh --skip-install
```

### Output

After successful completion, binaries will be available in `build/qemu/`:

```
build/qemu/
├── bin/
│   ├── qemu-system-x86_64
│   └── qemu-img (and other utilities)
├── share/
│   └── qemu/ (BIOS files, etc.)
└── README.md (build documentation)
```

### Using the Built QEMU

#### With Environment Variable

```bash
# Set path to custom QEMU
export QEMU_SYSTEM_X86_64=$(pwd)/build/qemu/bin/qemu-system-x86_64

# Run sandbox examples
cd sandbox
go run examples/qemu_basic.go
```

#### Direct Usage

```bash
# Run QEMU directly
./build/qemu/bin/qemu-system-x86_64 \
  -kernel vmlinuz \
  -initrd initrd.img \
  -append "console=ttyS0" \
  -nographic
```

### Build Time

Typical build times (depending on system):
- 4 cores: ~20-30 minutes
- 8 cores: ~10-15 minutes
- 16 cores: ~5-10 minutes

### Verification

The script automatically verifies the build:

```bash
# Check version
./build/qemu/bin/qemu-system-x86_64 --version

# Check dependencies (should be minimal)
ldd ./build/qemu/bin/qemu-system-x86_64

# Check available machine types
./build/qemu/bin/qemu-system-x86_64 -M help
```

### Troubleshooting

#### Build Fails with Configuration Errors

If configuration fails:
1. Ensure all dependencies are installed
2. Check the config.log file in build directory
3. Try without `--skip-install` to ensure dependencies are present

#### Build Fails During Compilation

If compilation fails:
1. Reduce parallel jobs: `--jobs 2`
2. Check available disk space (needs ~5-10 GB)
3. Ensure sufficient RAM (may need 4-8 GB)

#### Binary Has Dynamic Dependencies

With glibc builds, some dynamic dependencies are expected:
- This is normal and won't affect most use cases
- For fully static builds, use `--musl` option

#### musl Build Fails

If musl build fails:
1. Ensure musl-tools is installed: `sudo apt-get install musl-tools musl-dev`
2. Some features may not be compatible with musl
3. Check build log for specific errors

### Binary Size Optimization

To reduce binary size:

```bash
# Strip debug symbols (reduces size by ~50-70%)
strip build/qemu/bin/qemu-system-x86_64

# Compress with UPX (additional ~50-70% reduction)
sudo apt-get install upx
upx --best build/qemu/bin/qemu-system-x86_64
```

### Multiple Architectures

To build for multiple architectures:

```bash
# Build x86_64 and ARM64
./scripts/build-qemu-static.sh --targets x86_64-softmmu,aarch64-softmmu

# This creates:
# - qemu-system-x86_64
# - qemu-system-aarch64
```

### Environment Variables

You can use environment variables instead of command-line options:

```bash
export QEMU_VERSION=9.0.0
export JOBS=8
export OUTPUT_DIR=/custom/path
export TARGETS="x86_64-softmmu,aarch64-softmmu"
./scripts/build-qemu-static.sh
```

### Examples

**Quick build for development:**
```bash
./scripts/build-qemu-static.sh --jobs $(nproc)
```

**Portable build for distribution:**
```bash
./scripts/build-qemu-static.sh --musl --clean
strip build/qemu/bin/qemu-system-x86_64
```

**Build multiple versions:**
```bash
# Build different versions in separate directories
./scripts/build-qemu-static.sh --qemu-version 9.0.0 --output ./build/qemu-9.0
./scripts/build-qemu-static.sh --qemu-version 9.1.0 --output ./build/qemu-9.1
```

### Documentation

For comprehensive information about building static QEMU, see:
- **[QEMU_STATIC_BUILD.md](QEMU_STATIC_BUILD.md)** - Complete guide to static QEMU builds

This includes:
- Detailed explanation of static vs dynamic linking
- Build approach comparisons (glibc vs musl)
- Advanced configuration options
- Troubleshooting guide
- Integration with the sandbox project
- Cross-compilation instructions

## Future Scripts

Additional scripts that may be added in the future:
- `build-initrd.sh` - Build custom initrd images
- `test-kernel.sh` - Automated kernel testing with QEMU
- `package-sandbox.sh` - Package complete sandbox environment
