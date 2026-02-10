#!/bin/bash

# Build static QEMU using Docker/Alpine
# This approach uses Alpine Linux with musl-libc for true static builds

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
QEMU_VERSION="${QEMU_VERSION:-9.1.0}"
TARGETS="${TARGETS:-x86_64-softmmu}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/build/qemu-docker}"
DOCKERFILE="${DOCKERFILE:-$SCRIPT_DIR/Dockerfile.qemu-static}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build static QEMU binaries using Docker/Alpine

OPTIONS:
    --version VERSION     QEMU version to build (default: 9.1.0)
    --targets TARGETS     Target architectures (default: x86_64-softmmu)
                         Multiple targets: "x86_64-softmmu,aarch64-softmmu"
    --output DIR         Output directory (default: ./build/qemu-docker)
    --no-cache           Don't use Docker build cache
    --help               Show this help message

EXAMPLES:
    # Build x86_64 only
    $0
    
    # Build with specific version
    $0 --version 9.1.0 --targets x86_64-softmmu
    
    # Build without cache
    $0 --no-cache

EOF
    exit 0
}

# Parse arguments
USE_CACHE="--no-cache"
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            QEMU_VERSION="$2"
            shift 2
            ;;
        --targets)
            TARGETS="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --no-cache)
            USE_CACHE="--no-cache"
            shift
            ;;
        --help)
            usage
            ;;
        *)
            error "Unknown option: $1"
            usage
            ;;
    esac
done

# Print configuration
info "=========================================="
info "QEMU Docker Static Build"
info "=========================================="
info "QEMU Version: $QEMU_VERSION"
info "Targets: $TARGETS"
info "Output Directory: $OUTPUT_DIR"
info "=========================================="

# Check Docker
if ! command -v docker &> /dev/null; then
    error "Docker is not installed or not in PATH"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    error "Docker daemon is not running"
    error "Try: sudo dockerd > /tmp/docker.log 2>&1 &"
    exit 1
fi

# Check if Dockerfile exists
if [ ! -f "$DOCKERFILE" ]; then
    error "Dockerfile not found at: $DOCKERFILE"
    exit 1
fi

info "Building Docker image..."
DOCKER_TAG="qemu-static-builder:${QEMU_VERSION}"

if ! docker build \
    $USE_CACHE \
    --build-arg QEMU_VERSION="$QEMU_VERSION" \
    --build-arg TARGETS="$TARGETS" \
    -t "$DOCKER_TAG" \
    -f "$DOCKERFILE" \
    "$SCRIPT_DIR"; then
    error "Docker build failed"
    exit 1
fi

success "Docker image built successfully"

# Create output directory
mkdir -p "$OUTPUT_DIR"

info "Extracting binaries from Docker image..."
CONTAINER_ID=$(docker create "$DOCKER_TAG")

if ! docker cp "$CONTAINER_ID:/output/" "$OUTPUT_DIR/"; then
    error "Failed to extract binaries"
    docker rm "$CONTAINER_ID" &>/dev/null
    exit 1
fi

docker rm "$CONTAINER_ID" &>/dev/null

success "Binaries extracted to: $OUTPUT_DIR/output/"

# List the binaries
info "Built binaries:"
find "$OUTPUT_DIR/output" -type f -executable -exec file {} \; | while read -r line; do
    info "  $line"
done

# Verify static linking
info "Verifying static linking..."
for binary in "$OUTPUT_DIR/output/bin/qemu-system-"*; do
    if [ -f "$binary" ]; then
        info "Checking: $(basename $binary)"
        LDD_OUTPUT=$(ldd "$binary" 2>&1)
        if echo "$LDD_OUTPUT" | grep -q "statically linked"; then
            success "  ✓ Statically linked"
        elif echo "$LDD_OUTPUT" | grep -q "not a dynamic executable"; then
            success "  ✓ Statically linked"
        else
            error "  ✗ Has dynamic dependencies:"
            echo "$LDD_OUTPUT" | sed 's/^/    /' >&2
        fi
    fi
done

success "=========================================="
success "Build complete!"
success "Binaries available at: $OUTPUT_DIR/output/bin/"
success "=========================================="
