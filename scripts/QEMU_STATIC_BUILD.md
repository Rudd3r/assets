# Building Static QEMU for Linux

This guide explains how to build a statically-linked version of QEMU for bundling with the sandbox project.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Build Approaches](#build-approaches)
- [Dependencies](#dependencies)
- [Build Process](#build-process)
- [Testing the Build](#testing-the-build)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)

## Overview

The sandbox project aims to bundle QEMU binaries rather than depending on system-installed QEMU. This improves portability and ensures consistent behavior across different systems.

### Goals

- **Portability**: Binaries should work on most Linux distributions
- **Self-contained**: Minimal external dependencies
- **Compatibility**: Support for essential QEMU features (KVM, virtio, networking)
- **Size**: Reasonable binary sizes for distribution

### Challenges

Building truly static QEMU binaries is challenging because:

1. **glibc limitations**: Full static linking with glibc is problematic (NSS, DNS resolution)
2. **Dependencies**: QEMU has many dependencies (glib, pixman, slirp, etc.)
3. **Features vs. size**: More features = larger binaries and more dependencies
4. **License considerations**: Some dependencies may affect licensing

## Quick Start

### Basic Build (glibc, mostly-static)

```bash
# Install dependencies and build QEMU
./scripts/build-qemu-static.sh

# This will create binaries in ./build/qemu/bin/
```

### Fully Static Build (musl-libc)

```bash
# Build with musl for maximum portability
./scripts/build-qemu-static.sh --musl

# This creates truly static binaries with no dynamic dependencies
```

### Build Specific Version

```bash
# Build a specific QEMU version
./scripts/build-qemu-static.sh --qemu-version 9.0.0

# Build for multiple architectures
./scripts/build-qemu-static.sh --targets x86_64-softmmu,aarch64-softmmu
```

## Build Approaches

### Approach 1: glibc with Static Libraries (Default)

**Pros:**
- Easier to build
- Better tested
- Works with standard system libraries
- Good compatibility with most systems

**Cons:**
- Not fully static (glibc remains dynamic)
- May have compatibility issues across different distros
- Larger dependency chain

**Use when:**
- Distributing within known Linux distributions
- You need maximum compatibility with existing code
- Full static linking is not required

### Approach 2: musl-libc (Fully Static)

**Pros:**
- Truly static binaries
- Maximum portability across Linux distributions
- Smaller binary sizes
- No runtime dependencies

**Cons:**
- More complex build process
- Some features may not work
- Less tested configuration
- May require patching for some dependencies

**Use when:**
- Maximum portability is required
- Distributing across many different Linux distributions
- Building for embedded systems
- You need fully self-contained binaries

## Dependencies

### Build Dependencies

The build script automatically installs these on Debian/Ubuntu:

#### Essential Tools
- `build-essential` - GCC, make, and other build tools
- `pkg-config` - Dependency configuration
- `ninja-build` - Fast build system
- `python3` and `python3-pip` - Build scripts and meson
- `git`, `wget`, `curl` - Source downloading

#### QEMU-Specific Dependencies
- `libglib2.0-dev` - GLib library (core dependency)
- `libpixman-1-dev` - Pixel manipulation library
- `libslirp-dev` - User-mode networking
- `libcap-ng-dev` - Capability management
- `libattr1-dev` - Extended attributes
- `flex`, `bison` - Parser generators

#### For musl Builds
- `musl-tools` - musl compiler and tools
- `musl-dev` - musl development files

### Runtime Dependencies

#### glibc Build
- glibc (version must match or be compatible)
- Some system libraries may be required

#### musl Build
- None (fully static)

## Build Process

### Step 1: Install Dependencies

```bash
# Automatic (recommended)
./scripts/build-qemu-static.sh

# Manual installation (Debian/Ubuntu)
sudo apt-get update
sudo apt-get install -y build-essential pkg-config ninja-build \
  python3 python3-pip git wget curl \
  libglib2.0-dev libpixman-1-dev libslirp-dev \
  libcap-ng-dev libattr1-dev flex bison

# Install meson
pip3 install --user meson
```

### Step 2: Download QEMU Source

```bash
# Automatic (part of build script)
./scripts/build-qemu-static.sh

# Manual download
wget https://download.qemu.org/qemu-9.1.0.tar.xz
tar xf qemu-9.1.0.tar.xz
cd qemu-9.1.0
```

### Step 3: Configure Build

The build script configures QEMU with:

```bash
./configure \
  --prefix=/path/to/output \
  --target-list=x86_64-softmmu \
  --enable-kvm \
  --static \
  --disable-werror \
  --disable-docs \
  --disable-gtk \
  --disable-sdl \
  --disable-vnc \
  --enable-slirp
```

Key options explained:
- `--static`: Enable static linking
- `--target-list`: Which architectures to build (x86_64-softmmu is most common)
- `--enable-kvm`: Enable KVM acceleration
- `--disable-*`: Disable unnecessary features to reduce dependencies
- `--enable-slirp`: User-mode networking (essential for sandbox)

### Step 4: Build

```bash
# Using the script
./scripts/build-qemu-static.sh --jobs 8

# Manual build
cd qemu-9.1.0/build
make -j8
make install
```

### Step 5: Verify

```bash
# Check version
./build/qemu/bin/qemu-system-x86_64 --version

# Check dependencies
ldd ./build/qemu/bin/qemu-system-x86_64

# Test basic functionality
./build/qemu/bin/qemu-system-x86_64 -M help
```

## Testing the Build

### Basic Functionality Test

```bash
# Test that QEMU starts and shows version
./build/qemu/bin/qemu-system-x86_64 --version

# Test machine types
./build/qemu/bin/qemu-system-x86_64 -M help

# Test with a minimal kernel (if you have one)
./build/qemu/bin/qemu-system-x86_64 \
  -kernel vmlinuz \
  -initrd initrd.img \
  -append "console=ttyS0" \
  -nographic
```

### Integration Test with Sandbox

```bash
# Set environment variable to use custom QEMU
export QEMU_SYSTEM_X86_64=$(pwd)/build/qemu/bin/qemu-system-x86_64

# Build sandbox init
cd sandbox
make build

# Run example
go run examples/qemu_basic.go
```

### Portability Test

To test portability across different systems:

```bash
# Copy binary to different Linux system
scp build/qemu/bin/qemu-system-x86_64 user@other-system:/tmp/

# On other system, test it
/tmp/qemu-system-x86_64 --version
ldd /tmp/qemu-system-x86_64
```

## Troubleshooting

### Build Fails with "configure: error"

**Problem**: Configuration step fails

**Solutions**:
1. Ensure all dependencies are installed: `./scripts/build-qemu-static.sh` (without --skip-install)
2. Check the config.log file in the build directory for specific errors
3. Try building without static linking first to isolate the issue:
   ```bash
   ./configure --prefix=/tmp/qemu-test
   ```

### Build Fails During Compilation

**Problem**: Make command fails

**Solutions**:
1. Reduce parallel jobs: `--jobs 2`
2. Check for disk space: `df -h`
3. Ensure enough RAM (QEMU build can use several GB)
4. Check for specific errors in build output

### Binary Has Dynamic Dependencies (glibc build)

**Problem**: `ldd` shows dynamic libraries

**Expected**: With glibc, some dynamic linking is normal:
```
linux-vdso.so.1
libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6
/lib64/ld-linux-x86-64.so.2
```

**Solutions**:
- This is expected with glibc static builds
- For fully static builds, use `--musl` option
- Most dependencies should still be statically linked

### Binary Won't Run on Different System

**Problem**: "cannot execute binary file" or missing library errors

**Solutions**:
1. Check architecture: `file binary` (ensure it matches target system)
2. Check glibc version: `ldd --version` on both systems
3. Use `--musl` option for better portability
4. Verify all dynamic dependencies are available on target system

### Binary Size is Very Large

**Problem**: Binary is 100+ MB

**Expected**: Static QEMU binaries are large (30-100 MB per target)

**Solutions**:
1. Strip debug symbols: `strip build/qemu/bin/qemu-system-x86_64`
2. Compress with UPX: `upx --best build/qemu/bin/qemu-system-x86_64`
3. Build only needed targets: `--targets x86_64-softmmu`
4. Disable unnecessary features in configure step

### musl Build Fails

**Problem**: Build fails when using `--musl`

**Solutions**:
1. Ensure musl-tools is installed: `sudo apt-get install musl-tools musl-dev`
2. Some dependencies may not support musl - check build log
3. May need to build dependencies from source with musl
4. Consider using Alpine Linux Docker container for musl builds:
   ```bash
   docker run -it --rm -v $(pwd):/work alpine:latest sh
   # Inside container: apk add build-base musl-dev ...
   ```

## Advanced Topics

### Cross-Compilation

Building QEMU for different architectures:

```bash
# Build ARM64 QEMU on x86_64
./scripts/build-qemu-static.sh --targets aarch64-softmmu
```

For true cross-compilation (building ARM binaries on x86_64):
- Requires cross-compilation toolchain
- More complex setup
- Consider using Docker containers

### Custom Feature Set

To customize which QEMU features are built, edit the configure options in `build-qemu-static.sh`:

```bash
# Add features
--enable-vnc        # VNC support
--enable-gtk        # GTK UI
--enable-sdl        # SDL UI

# Remove features to reduce size
--disable-qcow2     # Disable QCOW2 image format
--disable-usb       # Disable USB support
```

### Building Multiple Versions

To maintain multiple QEMU versions:

```bash
# Build different versions to different directories
./scripts/build-qemu-static.sh \
  --qemu-version 9.0.0 \
  --output ./build/qemu-9.0

./scripts/build-qemu-static.sh \
  --qemu-version 9.1.0 \
  --output ./build/qemu-9.1
```

### Optimizing Binary Size

Techniques to reduce binary size:

1. **Strip symbols** (removes debug info):
   ```bash
   strip -s build/qemu/bin/qemu-system-x86_64
   # Can reduce size by 50-70%
   ```

2. **UPX compression** (executable packer):
   ```bash
   sudo apt-get install upx
   upx --best build/qemu/bin/qemu-system-x86_64
   # Can reduce size by additional 50-70%
   ```

3. **Selective features** (disable unneeded features):
   - See "Custom Feature Set" above

4. **Link-time optimization** (LTO):
   ```bash
   # Add to configure options
   --enable-lto
   ```

### Building in Docker

For reproducible builds and better isolation:

```bash
# Create Dockerfile
cat > Dockerfile.qemu-builder << 'EOF'
FROM debian:bookworm
RUN apt-get update && apt-get install -y \
  build-essential pkg-config ninja-build python3 python3-pip \
  git wget curl libglib2.0-dev libpixman-1-dev libslirp-dev \
  libcap-ng-dev libattr1-dev flex bison musl-tools musl-dev
RUN pip3 install meson
WORKDIR /build
EOF

# Build image
docker build -f Dockerfile.qemu-builder -t qemu-builder .

# Run build in container
docker run --rm -v $(pwd):/build qemu-builder \
  /build/scripts/build-qemu-static.sh --musl
```

### Using Alpine Linux for musl Builds

Alpine Linux uses musl by default, making it ideal for musl builds:

```bash
# Run Alpine container
docker run -it --rm -v $(pwd):/work alpine:latest sh

# Inside container:
apk add build-base git python3 py3-pip ninja pkgconfig \
  glib-dev pixman-dev libslirp-dev libcap-ng-dev attr-dev \
  flex bison meson

cd /work/sandbox
./scripts/build-qemu-static.sh
```

## Best Practices

1. **Version Pinning**: Use specific QEMU versions for reproducible builds
2. **Testing**: Always test binaries on target systems before deployment
3. **Documentation**: Document which version and options were used
4. **Size Optimization**: Strip and compress binaries for distribution
5. **Security**: Keep QEMU version up to date for security patches
6. **Verification**: Check binary dependencies with `ldd` before deployment

## Integration with Sandbox Project

### Using Custom QEMU Binary

To use a custom-built QEMU binary with the sandbox:

1. **Set environment variable**:
   ```bash
   export QEMU_SYSTEM_X86_64=/path/to/custom/qemu-system-x86_64
   ```

2. **Modify code** (if needed):
   ```go
   // In pkg/qemu/qemu.go or similar
   qemuPath := os.Getenv("QEMU_SYSTEM_X86_64")
   if qemuPath == "" {
       qemuPath = "qemu-system-x86_64" // fallback to system
   }
   ```

3. **Bundle with project**:
   ```bash
   # Copy binary to project
   mkdir -p sandbox/bin/qemu
   cp build/qemu/bin/qemu-system-x86_64 sandbox/bin/qemu/
   
   # Update .gitignore
   echo "bin/qemu/qemu-system-*" >> .gitignore
   ```

### Makefile Integration

Add targets to the project Makefile:

```makefile
# Build QEMU
.PHONY: build-qemu
build-qemu:
	./scripts/build-qemu-static.sh

# Build QEMU with musl
.PHONY: build-qemu-musl
build-qemu-musl:
	./scripts/build-qemu-static.sh --musl

# Clean QEMU build
.PHONY: clean-qemu
clean-qemu:
	rm -rf build/qemu build/qemu-source
```

## References

- [QEMU Documentation](https://www.qemu.org/docs/master/)
- [QEMU Build System](https://www.qemu.org/docs/master/devel/build-system.html)
- [musl libc](https://musl.libc.org/)
- [Static Linking Considerations](https://wiki.musl-libc.org/projects-using-musl.html)

## Contributing

When contributing improvements to the QEMU build process:

1. Test on multiple Linux distributions
2. Document any changes to build options
3. Update this guide with new findings
4. Consider both glibc and musl builds
5. Test binary size and performance impacts

## License Notes

QEMU is licensed under the GNU General Public License (GPL) v2. When distributing QEMU binaries:

1. Include QEMU's license information
2. Provide source code or build instructions
3. Document any modifications made
4. Be aware of dependencies' licenses

Check QEMU's LICENSE file and dependency licenses before distribution.
