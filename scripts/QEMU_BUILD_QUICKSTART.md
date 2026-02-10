# QEMU Static Build - Quick Start

This is a quick reference guide for building static QEMU. For comprehensive documentation, see [QEMU_STATIC_BUILD.md](QEMU_STATIC_BUILD.md).

## Prerequisites

You need a Linux system with:
- At least 8 GB RAM
- At least 10 GB free disk space
- Build tools (automatically installed by script)

## Basic Build Commands

### Default Build (Recommended for Most Users)

```bash
cd /path/to/sandbox
./scripts/build-qemu-static.sh
```

This will:
- Install all necessary dependencies
- Download QEMU 9.1.0
- Build with mostly-static linking (glibc)
- Create binaries in `./build/qemu/bin/`

**Time**: ~15-30 minutes on a modern system

### Fully Static Build (Maximum Portability)

```bash
./scripts/build-qemu-static.sh --musl
```

This creates truly portable binaries with no dynamic dependencies.

**Use when**: Distributing to many different Linux systems

### Quick Development Build

```bash
./scripts/build-qemu-static.sh --jobs $(nproc)
```

Uses all CPU cores for fastest build.

## After Building

### Test the Build

```bash
# Check version
./build/qemu/bin/qemu-system-x86_64 --version

# Check dependencies
ldd ./build/qemu/bin/qemu-system-x86_64

# Test machine types
./build/qemu/bin/qemu-system-x86_64 -M help
```

### Use with Sandbox Project

```bash
# Set environment variable
export QEMU_SYSTEM_X86_64=$(pwd)/build/qemu/bin/qemu-system-x86_64

# Build and run example
cd sandbox
make build
go run examples/qemu_basic.go
```

## Common Options

```bash
# Specific version
./scripts/build-qemu-static.sh --qemu-version 9.0.0

# Clean rebuild
./scripts/build-qemu-static.sh --clean

# Multiple architectures
./scripts/build-qemu-static.sh --targets x86_64-softmmu,aarch64-softmmu

# Different output directory
./scripts/build-qemu-static.sh --output /custom/path

# Fewer parallel jobs (if running out of memory)
./scripts/build-qemu-static.sh --jobs 2

# Skip dependency installation
./scripts/build-qemu-static.sh --skip-install
```

## Optimization Tips

### Reduce Binary Size

```bash
# After build, strip debug symbols
strip build/qemu/bin/qemu-system-x86_64

# Optional: Compress with UPX (requires upx)
sudo apt-get install upx
upx --best build/qemu/bin/qemu-system-x86_64
```

This can reduce size from ~100MB to ~10-20MB.

## Troubleshooting Quick Fixes

### Build Failed

```bash
# Try with fewer parallel jobs
./scripts/build-qemu-static.sh --jobs 2 --clean

# Ensure dependencies are installed
./scripts/build-qemu-static.sh  # without --skip-install
```

### Out of Disk Space

```bash
# Build to different location
./scripts/build-qemu-static.sh --output /path/with/more/space

# Clean up after build
rm -rf build/qemu-source
```

### Binary Won't Run on Another System

```bash
# Rebuild with musl for better portability
./scripts/build-qemu-static.sh --musl --clean
```

## Integration Checklist

- [ ] Build QEMU successfully
- [ ] Test binary: `./build/qemu/bin/qemu-system-x86_64 --version`
- [ ] Check dependencies: `ldd ./build/qemu/bin/qemu-system-x86_64`
- [ ] Test with sandbox: `export QEMU_SYSTEM_X86_64=...`
- [ ] Optimize size: `strip` and optionally `upx`
- [ ] Test on target systems
- [ ] Document version used

## Next Steps

1. **Bundle with Project**: Copy binaries to project distribution
2. **Update .gitignore**: Exclude build artifacts
3. **Document Version**: Record which QEMU version is bundled
4. **Test Integration**: Ensure sandbox works with bundled QEMU
5. **Create Release**: Package binaries for distribution

## File Locations

After successful build:

```
build/qemu/
├── bin/
│   ├── qemu-system-x86_64          # Main binary
│   ├── qemu-img                     # Disk image utility
│   └── ... (other utilities)
├── share/qemu/
│   ├── bios.bin                     # BIOS files
│   └── ... (other firmware)
└── README.md                        # Build documentation
```

## Build Matrix

| Build Type | Command | Portability | Size | Build Time |
|------------|---------|-------------|------|------------|
| Default (glibc) | `./scripts/build-qemu-static.sh` | Good | ~100MB | ~20min |
| Musl static | `./scripts/build-qemu-static.sh --musl` | Excellent | ~90MB | ~25min |
| Stripped | `+ strip` | Same | ~30MB | +1min |
| UPX compressed | `+ upx` | Same | ~10-20MB | +2min |

## Common Use Cases

### Development

```bash
# Quick build for testing
./scripts/build-qemu-static.sh
export QEMU_SYSTEM_X86_64=$(pwd)/build/qemu/bin/qemu-system-x86_64
```

### Distribution

```bash
# Portable, optimized build
./scripts/build-qemu-static.sh --musl --clean
strip build/qemu/bin/qemu-system-x86_64
upx --best build/qemu/bin/qemu-system-x86_64
```

### Testing Multiple Versions

```bash
# Build v9.0 and v9.1
./scripts/build-qemu-static.sh --qemu-version 9.0.0 --output ./build/qemu-9.0
./scripts/build-qemu-static.sh --qemu-version 9.1.0 --output ./build/qemu-9.1
```

### CI/CD Pipeline

```bash
# Non-interactive, clean build
./scripts/build-qemu-static.sh --clean --jobs 4
```

## Getting Help

- **Script Help**: `./scripts/build-qemu-static.sh --help`
- **Detailed Guide**: See [QEMU_STATIC_BUILD.md](QEMU_STATIC_BUILD.md)
- **QEMU Documentation**: https://www.qemu.org/docs/master/
- **Issues**: Check build log and `build/qemu-source/qemu-*/build/config.log`

## Quick Reference Card

| Task | Command |
|------|---------|
| Build | `./scripts/build-qemu-static.sh` |
| Clean build | `./scripts/build-qemu-static.sh --clean` |
| Musl build | `./scripts/build-qemu-static.sh --musl` |
| Test | `./build/qemu/bin/qemu-system-x86_64 --version` |
| Check deps | `ldd ./build/qemu/bin/qemu-system-x86_64` |
| Strip | `strip build/qemu/bin/qemu-system-*` |
| Use | `export QEMU_SYSTEM_X86_64=$(pwd)/build/qemu/bin/qemu-system-x86_64` |
| Help | `./scripts/build-qemu-static.sh --help` |
