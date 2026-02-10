# QEMU Build Profiles

This document explains the different build profiles available for compiling static QEMU binaries.

## Overview

The `build-qemu-static.sh` script supports three build profiles, each optimized for different use cases:

| Profile | Use Case | Binary Size | Dependencies | Build Time |
|---------|----------|-------------|--------------|------------|
| **minimal** | Bundling with sandbox (recommended) | ~25-40 MB | Minimal (glib, pixman, slirp) | Fastest |
| **default** | General purpose development | ~50-70 MB | Moderate | Medium |
| **full** | Feature-complete build | ~100+ MB | Many | Slowest |

## Profile Comparison

### Minimal Profile (Recommended for Sandbox)

**Command:**
```bash
./scripts/build-qemu-static.sh --profile minimal
```

**Purpose:** Optimized specifically for the sandbox project's requirements - CLI-only usage with usermode networking and hypervisor acceleration.

**Enabled Features:**
- ✅ KVM (hypervisor acceleration)
- ✅ Slirp (usermode networking)
- ✅ VirtIO devices (essential)
- ✅ 9P filesystem (host-guest file sharing)
- ✅ Basic disk images (raw, qcow2)
- ✅ Serial console

**Disabled Features:**
- ❌ All GUI/display (GTK, SDL, VNC, Spice, OpenGL)
- ❌ Audio (ALSA, PulseAudio, OSS, Jack)
- ❌ USB devices
- ❌ Complex storage backends (RBD, Glusterfs, iSCSI, NFS)
- ❌ Exotic disk formats (VDI, VHDX, VMDK, VPC, etc.)
- ❌ Security/smartcard
- ❌ TPM, NUMA
- ❌ Xen, other hypervisors
- ❌ Network advanced features (vhost, RDMA)
- ❌ Migration and replication
- ❌ Guest agent and tools
- ❌ BPF, capstone, fdt

**Dependencies (minimal):**
- glib2
- pixman
- libslirp
- Standard C library (glibc or musl)

**Advantages:**
- Smallest binary size
- Fewest dependencies (easier static linking)
- Fastest build time
- Perfect for CLI sandbox applications
- Easy to bundle and distribute

**Best For:**
- Bundling QEMU with the sandbox project
- Container images
- CI/CD environments
- Automated testing
- Situations where you only need basic VM functionality

### Default Profile

**Command:**
```bash
./scripts/build-qemu-static.sh --profile default
# or just
./scripts/build-qemu-static.sh
```

**Purpose:** Balanced build with commonly used features for general development.

**Enabled Features:**
- ✅ KVM (hypervisor acceleration)
- ✅ Slirp (usermode networking)
- ✅ VirtIO devices
- ✅ 9P filesystem
- ✅ Common disk formats
- ✅ Some compression formats
- ✅ Serial console

**Disabled Features:**
- ❌ GUI/display (GTK, SDL, VNC, Spice)
- ❌ Audio
- ❌ USB devices
- ❌ Complex storage backends (RBD, Glusterfs, iSCSI, NFS)
- ❌ TPM, NUMA
- ❌ Xen
- ❌ Migration and replication
- ❌ Guest agent

**Dependencies (moderate):**
- glib2
- pixman
- libslirp
- Some compression libraries
- Standard C library

**Advantages:**
- Good balance of features and size
- Suitable for most development scenarios
- Still relatively easy to link statically
- More features than minimal if needed

**Best For:**
- Development and testing
- Situations where you might need additional features
- General-purpose QEMU usage without GUI

### Full Profile

**Command:**
```bash
./scripts/build-qemu-static.sh --profile full
```

**Purpose:** Feature-complete build with most options auto-detected and enabled.

**Features:**
- ✅ Everything that configure detects and can enable
- ✅ Only explicitly disabled: documentation

**Dependencies:**
- All available dependencies on the system

**Advantages:**
- Maximum feature support
- No features missed

**Disadvantages:**
- Largest binary size (100+ MB)
- Most dependencies (harder to link statically)
- Longest build time
- Many dependencies may not be needed
- Not recommended for static builds

**Best For:**
- Exploring QEMU capabilities
- Development requiring specific features
- When you're unsure what features you need
- System where QEMU will be dynamically linked anyway

## Feature Matrix

| Feature | Minimal | Default | Full |
|---------|---------|---------|------|
| KVM Acceleration | ✅ | ✅ | ✅ |
| Usermode Networking (slirp) | ✅ | ✅ | ✅ |
| VirtIO Devices | ✅ | ✅ | ✅ |
| 9P Filesystem | ✅ | ✅ | ✅ |
| Serial Console | ✅ | ✅ | ✅ |
| Basic Disk Formats (raw, qcow2) | ✅ | ✅ | ✅ |
| GUI (GTK, SDL) | ❌ | ❌ | Auto |
| VNC | ❌ | ❌ | Auto |
| Audio | ❌ | ❌ | Auto |
| USB | ❌ | ❌ | Auto |
| Exotic Disk Formats | ❌ | ❌ | Auto |
| Network Backends (RBD, etc.) | ❌ | ❌ | Auto |
| TPM | ❌ | ❌ | Auto |
| NUMA | ❌ | ❌ | Auto |
| Guest Agent | ❌ | ❌ | Auto |
| Migration | ❌ | ❌ | Auto |

## Recommendations

### For the Sandbox Project

**Use: Minimal + musl**

```bash
./scripts/build-qemu-static.sh --profile minimal --musl
```

**Why:**
- Smallest binary size for distribution
- Truly portable (no dynamic dependencies)
- All features needed by sandbox:
  - KVM acceleration ✅
  - Usermode networking ✅
  - 9P file sharing ✅
  - VirtIO devices ✅
  - Serial console ✅
- No unnecessary features
- Easiest to maintain and update

### For Development

**Use: Default (glibc)**

```bash
./scripts/build-qemu-static.sh --profile default
```

**Why:**
- Faster build time than full
- Extra features available if needed
- Easier to build than musl version
- Good for iteration

### For Exploring QEMU

**Use: Full (glibc, maybe not static)**

```bash
./scripts/build-qemu-static.sh --profile full
# Or better yet, use system QEMU
sudo apt-get install qemu-system-x86
```

**Why:**
- All features available
- Can use system package manager
- No need to build yourself

## Dependency Reduction Examples

### Minimal Profile Eliminates:

| Dependency Type | Examples | Why Disabled |
|----------------|----------|--------------|
| GUI Libraries | GTK+, SDL, X11, Wayland | CLI only |
| Audio Libraries | ALSA, PulseAudio, Jack | No audio needed |
| Display Protocols | VNC, Spice | No remote display |
| Graphics | OpenGL, virglrenderer | No graphics |
| Storage Backends | librbd, libglusterfs, libnfs, libiscsi | Simple file-based storage |
| USB Libraries | libusb | No USB passthrough |
| Crypto | Nettle, Gcrypt, GnuTLS | Minimal crypto needs |
| Compression | LZO, Snappy, LZFSE | Basic compression enough |
| Advanced Features | RDMA, vhost-user, BPF | Not needed for sandbox |

This reduction means:
- ✅ Fewer apt packages to install
- ✅ Faster build configuration
- ✅ Faster compilation
- ✅ Smaller binary
- ✅ Easier static linking
- ✅ More portable

## Build Time Comparison

On a typical 8-core system:

```
Minimal Profile:  ~10-15 minutes
Default Profile:  ~15-20 minutes
Full Profile:     ~25-35 minutes
```

## Binary Size Comparison

After stripping debug symbols:

```
Minimal Profile (glibc):  ~30-40 MB
Minimal Profile (musl):   ~25-35 MB
Default Profile:          ~50-70 MB
Full Profile:             ~100-150 MB
```

With UPX compression:

```
Minimal Profile:  ~10-15 MB
Default Profile:  ~20-30 MB
Full Profile:     ~40-60 MB
```

## Testing Your Build

After building with any profile, verify the features:

```bash
# Check version
./build/qemu/bin/qemu-system-x86_64 --version

# Check available devices
./build/qemu/bin/qemu-system-x86_64 -device help | grep virtio

# Check machine types
./build/qemu/bin/qemu-system-x86_64 -M help

# Check network backends
./build/qemu/bin/qemu-system-x86_64 -netdev help

# Check what's dynamically linked
ldd ./build/qemu/bin/qemu-system-x86_64
```

## Switching Between Profiles

You can build multiple profiles side-by-side:

```bash
# Build minimal for distribution
./scripts/build-qemu-static.sh --profile minimal --output ./build/qemu-minimal

# Build default for development
./scripts/build-qemu-static.sh --profile default --output ./build/qemu-default

# Use the appropriate one
export QEMU_SYSTEM_X86_64=$(pwd)/build/qemu-minimal/bin/qemu-system-x86_64
```

## Custom Profiles

If none of the profiles fit your needs, you can:

1. **Modify the script** - Edit `build-qemu-static.sh` and add your own profile
2. **Use default and customize** - Start with default profile and add/remove options
3. **Manual configure** - Run QEMU's configure manually with your exact options

Example custom profile in the script:

```bash
custom)
    info "Using CUSTOM profile"
    configure_opts+=(
        --enable-kvm
        --enable-slirp
        --enable-vnc          # Add VNC
        --disable-gtk
        --disable-sdl
        # ... your options
    )
    ;;
```

## Environment Variables

You can also set the profile via environment variable:

```bash
export BUILD_PROFILE=minimal
export USE_MUSL=true
./scripts/build-qemu-static.sh
```

## Conclusion

For the sandbox project, the **minimal profile with musl** provides the best balance of:
- ✅ Portability (works on any Linux)
- ✅ Size (small enough to bundle)
- ✅ Features (everything needed, nothing extra)
- ✅ Build time (fastest option)
- ✅ Maintenance (fewer dependencies to track)

**Recommended command for production builds:**

```bash
./scripts/build-qemu-static.sh --profile minimal --musl --clean
strip build/qemu/bin/qemu-system-*
```

This creates the most portable, smallest binaries suitable for bundling with the project.
