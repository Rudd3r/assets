.PHONY: build clean
.PHONY: kernel e2fsprogs
.PHONY: setup-dev

GO := go
GOFLAGS := 
LDFLAGS := -s -w
KERNEL_VERSION ?= 6.12.4
E2FSPROGS_VERSION ?= 1.47.1
JOBS ?= $(shell nproc)
BUILD_FLAGS := -trimpath -ldflags "$(LDFLAGS)"

BUILD_DIR := build
KERNEL_DIR := $(BUILD_DIR)/kernel
E2FSPROGS_DIR := $(BUILD_DIR)/e2fsprogs

clean:
	@rm -rf $(BUILD_DIR)

build: download-initrd kernel e2fsprogs

download-initrd:
	./scripts/download-qemu-initrd.sh

kernel:
	@mkdir -p $(KERNEL_DIR)
	./scripts/build-qemu-kernel.sh \
		--kernel-version $(KERNEL_VERSION) \
		--jobs $(JOBS) \
		--output $(KERNEL_DIR)

e2fsprogs:
	@mkdir -p $(E2FSPROGS_DIR)
	./scripts/build-e2fsprogs.sh \
		--version $(E2FSPROGS_VERSION) \
		--jobs $(JOBS) \
		--output $(E2FSPROGS_DIR) \
		--arch all

setup-dev:
	./scripts/setup-dev-dependencies.sh
