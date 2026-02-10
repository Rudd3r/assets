.PHONY: build clean release
.PHONY: kernel e2fsprogs
.PHONY: build-amd64 build-arm64
.PHONY: kernel-amd64 kernel-arm64
.PHONY: e2fsprogs-amd64 e2fsprogs-arm64
.PHONY: initrd-amd64 initrd-arm64
.PHONY: setup-dev

GO := go
GOFLAGS := 
LDFLAGS := -s -w
KERNEL_VERSION ?= 6.12.4
E2FSPROGS_VERSION ?= 1.47.1
JOBS ?= $(shell nproc)
BUILD_FLAGS := -trimpath -ldflags "$(LDFLAGS)"

BUILD_DIR := build
ARCHES := amd64 arm64

# Temporary build directories (use absolute paths)
KERNEL_SOURCE_DIR := $(abspath $(BUILD_DIR)/kernel-source)
E2FSPROGS_SOURCE_DIR := $(abspath $(BUILD_DIR)/e2fsprogs-source)

clean:
	@rm -rf $(BUILD_DIR)

# Create release tarball
release:
	@echo "Creating release tarball..."
	@cd $(BUILD_DIR) && tar -czf release.tar.gz amd64/ arm64/
	@echo "Release tarball created: $(BUILD_DIR)/release.tar.gz"
	@ls -lh $(BUILD_DIR)/release.tar.gz

# Build all architectures
build: build-amd64 build-arm64

# Build for amd64
build-amd64: initrd-amd64 kernel-amd64 e2fsprogs-amd64

# Build for arm64
build-arm64: initrd-arm64 kernel-arm64 e2fsprogs-arm64

# Download initrd for amd64
initrd-amd64:
	@mkdir -p $(BUILD_DIR)/amd64
	./scripts/download-qemu-initrd.sh \
		--arch amd64 \
		--output $(BUILD_DIR)/amd64/

# Download initrd for arm64
initrd-arm64:
	@mkdir -p $(BUILD_DIR)/arm64
	./scripts/download-qemu-initrd.sh \
		--arch arm64 \
		--output $(BUILD_DIR)/arm64/

# Build kernel for amd64
kernel-amd64:
	@mkdir -p $(abspath $(BUILD_DIR)/amd64-kernel-tmp)
	./scripts/build-qemu-kernel.sh \
		--kernel-version $(KERNEL_VERSION) \
		--jobs $(JOBS) \
		--arch amd64 \
		--source $(KERNEL_SOURCE_DIR) \
		--output $(abspath $(BUILD_DIR)/amd64-kernel-tmp)
	@cp $(abspath $(BUILD_DIR)/amd64-kernel-tmp)/vmlinuz $(BUILD_DIR)/amd64/vmlinuz
	@rm -rf $(abspath $(BUILD_DIR)/amd64-kernel-tmp)

# Build kernel for arm64
kernel-arm64:
	@mkdir -p $(abspath $(BUILD_DIR)/arm64-kernel-tmp)
	./scripts/build-qemu-kernel.sh \
		--kernel-version $(KERNEL_VERSION) \
		--jobs $(JOBS) \
		--arch arm64 \
		--source $(KERNEL_SOURCE_DIR) \
		--output $(abspath $(BUILD_DIR)/arm64-kernel-tmp)
	@cp $(abspath $(BUILD_DIR)/arm64-kernel-tmp)/vmlinuz $(BUILD_DIR)/arm64/vmlinuz
	@rm -rf $(abspath $(BUILD_DIR)/arm64-kernel-tmp)

# Build e2fsprogs for amd64
e2fsprogs-amd64:
	@mkdir -p $(abspath $(BUILD_DIR)/e2fsprogs-tmp)
	./scripts/build-e2fsprogs.sh \
		--version $(E2FSPROGS_VERSION) \
		--jobs $(JOBS) \
		--arch amd64 \
		--source $(E2FSPROGS_SOURCE_DIR) \
		--output $(abspath $(BUILD_DIR)/e2fsprogs-tmp)
	@mkdir -p $(BUILD_DIR)/amd64
	@cp $(abspath $(BUILD_DIR)/e2fsprogs-tmp)/amd64/e2fsck $(BUILD_DIR)/amd64/e2fsck
	@cp $(abspath $(BUILD_DIR)/e2fsprogs-tmp)/amd64/mke2fs $(BUILD_DIR)/amd64/mke2fs
	@rm -rf $(abspath $(BUILD_DIR)/e2fsprogs-tmp)

# Build e2fsprogs for arm64
e2fsprogs-arm64:
	@mkdir -p $(abspath $(BUILD_DIR)/e2fsprogs-tmp)
	./scripts/build-e2fsprogs.sh \
		--version $(E2FSPROGS_VERSION) \
		--jobs $(JOBS) \
		--arch arm64 \
		--source $(E2FSPROGS_SOURCE_DIR) \
		--output $(abspath $(BUILD_DIR)/e2fsprogs-tmp)
	@mkdir -p $(BUILD_DIR)/arm64
	@cp $(abspath $(BUILD_DIR)/e2fsprogs-tmp)/arm64/e2fsck $(BUILD_DIR)/arm64/e2fsck
	@cp $(abspath $(BUILD_DIR)/e2fsprogs-tmp)/arm64/mke2fs $(BUILD_DIR)/arm64/mke2fs
	@rm -rf $(abspath $(BUILD_DIR)/e2fsprogs-tmp)

# Legacy targets for backward compatibility
kernel: kernel-amd64

e2fsprogs: e2fsprogs-amd64

setup-dev:
	./scripts/setup-dev-dependencies.sh
