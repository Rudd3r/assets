#!/usr/bin/env bash

# build-qemu-static.sh - Build a static version of QEMU for Linux
#
# This script builds QEMU with static linking for bundling with the sandbox project.
# It aims to create portable binaries that don't require system-installed QEMU.
#
# Usage:
#   ./scripts/build-qemu-static.sh [OPTIONS]
#
# Options:
#   -v, --qemu-version VERSION    QEMU version to build (default: 9.1.0)
#   -j, --jobs N                  Number of parallel jobs (default: nproc)
#   -o, --output DIR              Output directory (default: ./build/qemu)
#   -s, --source DIR              Source directory (default: ./build/qemu-source)
#   -t, --targets TARGETS         Comma-separated list of targets (default: x86_64-softmmu)
#   -p, --profile PROFILE         Build profile: minimal, default, or full (default: default)
#   --skip-install                Skip installing dependencies
#   --clean                       Clean build directory before building
#   --musl                        Use musl-libc for truly static builds (experimental)
#   -h, --help                    Show this help message
#
# Build Profiles:
#   minimal  - Bare minimum features for CLI sandbox (usermode networking only)
#            - Smallest binaries, fewest dependencies
#            - Recommended for bundling with the project
#
#   default  - Balanced build with commonly used features
#            - Good for most use cases
#
#   full     - All features enabled (not recommended for static builds)
#            - Largest binaries, most dependencies
#
# Examples:
#   # Build minimal QEMU for sandbox (recommended)
#   ./scripts/build-qemu-static.sh --profile minimal
#
#   # Build specific version with musl and minimal profile
#   ./scripts/build-qemu-static.sh --qemu-version 9.1.0 --musl --profile minimal
#
#   # Build for multiple architectures
#   ./scripts/build-qemu-static.sh --targets x86_64-softmmu,aarch64-softmmu

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
QEMU_VERSION="${QEMU_VERSION:-9.1.0}"
JOBS="${JOBS:-$(nproc)}"
OUTPUT_DIR="${OUTPUT_DIR:-./build/qemu}"
SOURCE_DIR="${SOURCE_DIR:-./build/qemu-source}"
TARGETS="${TARGETS:-x86_64-softmmu}"
BUILD_PROFILE="${BUILD_PROFILE:-default}"
SKIP_INSTALL=false
CLEAN_BUILD=false
USE_MUSL=false

# Helper functions
info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

show_help() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \?//'
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--qemu-version)
                QEMU_VERSION="$2"
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
            -t|--targets)
                TARGETS="$2"
                shift 2
                ;;
            -p|--profile)
                BUILD_PROFILE="$2"
                shift 2
                ;;
            --skip-install)
                SKIP_INSTALL=true
                shift
                ;;
            --clean)
                CLEAN_BUILD=true
                shift
                ;;
            --musl)
                USE_MUSL=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                error "Unknown option: $1"
                show_help
                ;;
        esac
    done
}

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# Install dependencies
install_dependencies() {
    if [ "$SKIP_INSTALL" = true ]; then
        info "Skipping dependency installation (--skip-install)"
        return
    fi

    info "Installing build dependencies..."
    
    local distro
    distro=$(detect_distro)
    
    case "$distro" in
        ubuntu|debian)
            info "Detected Debian/Ubuntu system"
            sudo apt-get update
            
            # Base build tools
            local packages=(
                build-essential
                pkg-config
                ninja-build
                python3
                python3-pip
                git
                wget
                curl
            )
            
            # QEMU build dependencies
            packages+=(
                libglib2.0-dev
                libpixman-1-dev
                libslirp-dev
                libcap-ng-dev
                libattr1-dev
                flex
                bison
            )
            
            # For musl builds
            if [ "$USE_MUSL" = true ]; then
                packages+=(
                    musl-tools
                    musl-dev
                )
            fi
            
            sudo apt-get install -y "${packages[@]}"
            success "Dependencies installed"
            ;;
        fedora|rhel|centos)
            info "Detected Red Hat-based system"
            local packages=(
                gcc
                gcc-c++
                make
                pkg-config
                ninja-build
                python3
                python3-pip
                git
                wget
                curl
                glib2-devel
                pixman-devel
                libslirp-devel
                libcap-ng-devel
                libattr-devel
                flex
                bison
            )
            
            if [ "$USE_MUSL" = true ]; then
                warning "musl-libc support on RHEL-based systems may require manual installation"
            fi
            
            sudo dnf install -y "${packages[@]}" || sudo yum install -y "${packages[@]}"
            success "Dependencies installed"
            ;;
        arch|manjaro)
            info "Detected Arch-based system"
            sudo pacman -Sy --noconfirm \
                base-devel \
                pkg-config \
                ninja \
                python \
                python-pip \
                git \
                wget \
                curl \
                glib2 \
                pixman \
                libslirp \
                libcap-ng \
                attr \
                flex \
                bison
            
            if [ "$USE_MUSL" = true ]; then
                sudo pacman -Sy --noconfirm musl
            fi
            
            success "Dependencies installed"
            ;;
        *)
            warning "Unknown distribution: $distro"
            warning "Please manually install: build tools, glib, pixman, libslirp, libcap-ng, ninja, python3"
            read -rp "Continue anyway? [y/N] " response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                error "Aborting"
                exit 1
            fi
            ;;
    esac
    
    # Install meson if not available
    if ! command -v meson &> /dev/null; then
        info "Installing meson build system..."
        pip3 install --user meson
        export PATH="$HOME/.local/bin:$PATH"
    fi
}

# Download QEMU source
download_qemu() {
    local qemu_url="https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz"
    local qemu_tar="${SOURCE_DIR}/qemu-${QEMU_VERSION}.tar.xz"
    local qemu_dir="${SOURCE_DIR}/qemu-${QEMU_VERSION}"
    
    mkdir -p "$SOURCE_DIR"
    
    # Convert to absolute path
    qemu_dir=$(cd "$SOURCE_DIR" && pwd)/qemu-${QEMU_VERSION}
    
    if [ -d "$qemu_dir" ] && [ "$CLEAN_BUILD" = false ]; then
        info "QEMU source already exists at $qemu_dir" >&2
        echo "$qemu_dir"
        return
    fi
    
    if [ "$CLEAN_BUILD" = true ] && [ -d "$qemu_dir" ]; then
        info "Cleaning existing source directory..." >&2
        rm -rf "$qemu_dir"
    fi
    
    if [ ! -f "$qemu_tar" ]; then
        info "Downloading QEMU ${QEMU_VERSION}..." >&2
        wget -O "$qemu_tar" "$qemu_url" >&2 || {
            error "Failed to download QEMU" >&2
            exit 1
        }
    fi
    
    info "Extracting QEMU source..." >&2
    tar -xf "$qemu_tar" -C "$SOURCE_DIR" >&2
    
    success "QEMU source ready at $qemu_dir" >&2
    echo "$qemu_dir"
}

# Configure QEMU build
configure_qemu() {
    local qemu_dir="$1"
    local build_dir="${qemu_dir}/build"
    
    info "Configuring QEMU build with profile: $BUILD_PROFILE"
    info "QEMU directory: $qemu_dir"
    
    cd "$qemu_dir" || {
        error "Failed to cd to $qemu_dir"
        exit 1
    }
    
    # Clean build directory if it exists
    if [ -d "$build_dir" ]; then
        rm -rf "$build_dir"
    fi
    mkdir -p "$build_dir"
    
    # Base configuration options (common to all profiles)
    # Convert OUTPUT_DIR to absolute path
    local output_abs
    output_abs=$(mkdir -p "$OUTPUT_DIR" && cd "$OUTPUT_DIR" && pwd)
    
    local configure_opts=(
        --prefix="$output_abs"
        --target-list="$TARGETS"
        --enable-kvm
        --disable-werror
    )
    
    # Profile-specific configurations
    case "$BUILD_PROFILE" in
        minimal)
            info "Using MINIMAL profile - CLI only, usermode networking, minimal dependencies"
            configure_opts+=(
                # User networking only (slirp)
                --enable-slirp
                
                # Disable ALL GUI/display options
                --disable-gtk
                --disable-sdl
                --disable-vnc
                --disable-opengl
                --disable-spice
                --disable-cocoa
                --disable-curses
                
                # Disable complex storage backends
                --disable-rbd
                --disable-glusterfs
                --disable-libiscsi
                --disable-libnfs
                --disable-vvfat
                --disable-vdi
                --disable-vhdx
                --disable-vmdk
                --disable-vpc
                --disable-cloop
                --disable-dmg
                --disable-qcow1
                --disable-parallels
                
                # Disable USB and smartcard
                --disable-usb-redir
                --disable-libusb
                --disable-smartcard
                
                # Disable advanced features
                --disable-tpm
                --disable-numa
                --disable-xen
                --disable-rdma
                
                # Disable audio
                --disable-alsa
                --disable-pa
                --disable-oss
                --disable-jack
                --disable-sndio
                
                # Disable compression/crypto libs (if not needed)
                
                # Disable advanced features
                
                # Disable docs and tools
                --disable-docs
                --disable-tools
                --disable-guest-agent
                
                # Disable debug/profiling
            )
            ;;
            
        default)
            info "Using DEFAULT profile - balanced features"
            configure_opts+=(
                # Enable user networking
                --enable-slirp
                
                # Disable GUI
                --disable-gtk
                --disable-sdl
                --disable-vnc
                --disable-opengl
                --disable-spice
                --disable-cocoa
                --disable-curses
                
                # Disable advanced storage backends
                --disable-rbd
                --disable-glusterfs
                --disable-libiscsi
                --disable-libnfs
                
                # Disable USB and smartcard
                --disable-usb-redir
                --disable-libusb
                --disable-smartcard
                
                # Disable advanced features
                --disable-tpm
                --disable-numa
                --disable-xen
                --disable-rdma
                
                # Disable audio
                --disable-alsa
                --disable-pa
                --disable-oss
                --disable-jack
                
                # Disable docs
                --disable-docs
                --disable-guest-agent
            )
            ;;
            
        full)
            warning "Using FULL profile - this will have many dependencies!"
            configure_opts+=(
                --enable-slirp
                --disable-docs  # Still disable docs to reduce build time
            )
            ;;
            
        *)
            error "Unknown build profile: $BUILD_PROFILE"
            error "Valid profiles: minimal, default, full"
            exit 1
            ;;
    esac
    
    # Static linking options
    if [ "$USE_MUSL" = true ]; then
        info "Configuring for musl-libc static build..."
        configure_opts+=(
            --static
            --cc=musl-gcc
        )
    else
        info "Configuring for mostly-static build with glibc..."
        # Note: Full static linking with glibc is problematic
        # We'll link most libraries statically but may need dynamic glibc
        configure_opts+=(
            --static
        )
    fi
    
    info "Configuration options: ${configure_opts[*]}"
    
    cd "$build_dir" || {
        error "Failed to cd to build directory: $build_dir"
        exit 1
    }
    
    info "Running configure from $(pwd)"
    info "Looking for configure at: $(ls -la ../configure 2>&1)"
    ../configure "${configure_opts[@]}" || {
        error "Configuration failed"
        error "This may be due to missing dependencies or incompatible options"
        error "Try running without --skip-install to install dependencies"
        error "Check build/qemu-source/qemu-*/build/config.log for details"
        exit 1
    }
    
    success "Configuration complete"
}

# Build QEMU
build_qemu() {
    local qemu_dir="$1"
    local build_dir="${qemu_dir}/build"
    
    info "Building QEMU with $JOBS parallel jobs..."
    info "This may take 15-30 minutes depending on your system..."
    
    cd "$build_dir"
    
    make -j"$JOBS" || {
        error "Build failed"
        error "Try reducing parallel jobs with --jobs 2"
        exit 1
    }
    
    success "Build complete"
}

# Install QEMU
install_qemu() {
    local qemu_dir="$1"
    local build_dir="${qemu_dir}/build"
    
    info "Installing QEMU to $OUTPUT_DIR..."
    
    cd "$build_dir"
    make install || {
        error "Installation failed"
        exit 1
    }
    
    success "Installation complete"
}

# Verify build
verify_build() {
    info "Verifying QEMU build..."
    
    local qemu_bin="${OUTPUT_DIR}/bin/qemu-system-x86_64"
    
    if [ ! -f "$qemu_bin" ]; then
        warning "qemu-system-x86_64 not found at $qemu_bin"
        warning "This is expected if you built for different targets"
    else
        info "QEMU binary: $qemu_bin"
        
        # Check version
        "$qemu_bin" --version || true
        
        # Check if binary is static or dynamic
        info "Checking binary linkage..."
        if command -v ldd &> /dev/null; then
            echo "---"
            if ldd "$qemu_bin" 2>&1 | grep -q "not a dynamic executable"; then
                success "Binary is fully statically linked!"
            else
                info "Binary has the following dynamic dependencies:"
                ldd "$qemu_bin" | grep -v "not found" || true
                warning "Binary is not fully static. This is normal with glibc."
                warning "For fully static builds, use --musl option."
            fi
            echo "---"
        fi
        
        # Check file size
        local size
        size=$(du -h "$qemu_bin" | cut -f1)
        info "Binary size: $size"
    fi
    
    info "Built binaries are in: ${OUTPUT_DIR}/bin/"
    ls -lh "${OUTPUT_DIR}/bin/" | grep qemu-system || true
}

# Create usage documentation
create_documentation() {
    local doc_file="${OUTPUT_DIR}/README.md"
    
    info "Creating documentation..."
    
    cat > "$doc_file" << EOF
# Static QEMU Build

This directory contains a statically-linked build of QEMU.

## Build Information

- **QEMU Version**: ${QEMU_VERSION}
- **Build Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
- **Build Profile**: ${BUILD_PROFILE}
- **Targets**: ${TARGETS}
- **Build Type**: $([ "$USE_MUSL" = true ] && echo "Static (musl)" || echo "Mostly-static (glibc)")

## Binaries

The following QEMU binaries are available in \`bin/\`:

\`\`\`
$(ls -1 "${OUTPUT_DIR}/bin/" | grep qemu-system || echo "No binaries found")
\`\`\`

## Usage

### Basic Usage

\`\`\`bash
# Run QEMU directly
./bin/qemu-system-x86_64 -kernel vmlinuz -initrd initrd.img -append "console=ttyS0"

# With the sandbox project
export QEMU_SYSTEM_X86_64=\$(pwd)/bin/qemu-system-x86_64
go run examples/qemu_basic.go
\`\`\`

### Verification

Check QEMU version:
\`\`\`bash
./bin/qemu-system-x86_64 --version
\`\`\`

Check binary dependencies:
\`\`\`bash
ldd ./bin/qemu-system-x86_64
\`\`\`

## Notes

### Static Linking

$(if [ "$USE_MUSL" = true ]; then
    echo "This build uses musl-libc for fully static linking. The binaries should"
    echo "work on any Linux system without additional dependencies."
else
    echo "This build uses glibc with mostly-static linking. Some system libraries"
    echo "(like glibc, pthread) may still be dynamically linked. The binaries should"
    echo "work on most Linux systems with a compatible glibc version."
    echo ""
    echo "For truly portable binaries across all Linux distributions, rebuild with"
    echo "the --musl option."
fi)

### Size Optimization

The binaries are quite large (typically 30-100 MB per target). To reduce size:

1. **Strip symbols**: \`strip bin/qemu-system-*\`
2. **Compress**: \`upx --best bin/qemu-system-*\` (requires upx)
3. **Build fewer targets**: Use \`--targets\` to build only what you need

### Troubleshooting

**Binary won't run:**
- Check if the binary is executable: \`chmod +x bin/qemu-system-x86_64\`
- Check dynamic dependencies: \`ldd bin/qemu-system-x86_64\`
- Try rebuilding with \`--musl\` for better portability

**Build failed:**
- Ensure all dependencies are installed
- Try without static linking to diagnose issues
- Check the build log for specific errors

## Rebuilding

To rebuild QEMU with different options:

\`\`\`bash
# Clean rebuild
./scripts/build-qemu-static.sh --clean

# Different version
./scripts/build-qemu-static.sh --qemu-version 9.0.0

# With musl for full static linking
./scripts/build-qemu-static.sh --musl

# Multiple architectures
./scripts/build-qemu-static.sh --targets x86_64-softmmu,aarch64-softmmu
\`\`\`

EOF

    success "Documentation created at $doc_file"
}

# Main execution
main() {
    parse_args "$@"
    
    info "=========================================="
    info "QEMU Static Build Script"
    info "=========================================="
    info "QEMU Version: $QEMU_VERSION"
    info "Build Profile: $BUILD_PROFILE"
    info "Output Directory: $OUTPUT_DIR"
    info "Source Directory: $SOURCE_DIR"
    info "Targets: $TARGETS"
    info "Jobs: $JOBS"
    info "Build Type: $([ "$USE_MUSL" = true ] && echo "Static (musl)" || echo "Mostly-static (glibc)")"
    info "=========================================="
    
    # Check if output directory exists and has content
    if [ -d "$OUTPUT_DIR" ] && [ -n "$(ls -A "$OUTPUT_DIR" 2>/dev/null)" ] && [ "$CLEAN_BUILD" = false ]; then
        warning "Output directory already exists: $OUTPUT_DIR"
        warning "Use --clean to rebuild from scratch"
        read -rp "Continue and overwrite? [y/N] " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Aborting"
            exit 0
        fi
    fi
    
    # Install dependencies
    install_dependencies
    
    # Download source
    local qemu_dir
    qemu_dir=$(download_qemu)
    
    # Configure build
    configure_qemu "$qemu_dir"
    
    # Build
    build_qemu "$qemu_dir"
    
    # Install
    install_qemu "$qemu_dir"
    
    # Verify
    verify_build
    
    # Create documentation
    create_documentation
    
    success "=========================================="
    success "QEMU build complete!"
    success "=========================================="
    success "Binaries installed to: $OUTPUT_DIR/bin/"
    info "See $OUTPUT_DIR/README.md for usage information"
    info ""
    info "Next steps:"
    info "  1. Test the binary: ${OUTPUT_DIR}/bin/qemu-system-x86_64 --version"
    info "  2. Check dependencies: ldd ${OUTPUT_DIR}/bin/qemu-system-x86_64"
    info "  3. Use with sandbox: export QEMU_SYSTEM_X86_64=${OUTPUT_DIR}/bin/qemu-system-x86_64"
}

# Run main function
main "$@"
