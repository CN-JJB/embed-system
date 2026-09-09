CROSS_COMPILE ?= arm-none-linux-gnueabihf-
CC := $(CROSS_COMPILE)gcc

M03_ROOT := $(abspath ..)
BUILD_DIR := $(CURDIR)/build
# SYNTHETIC PEDAGOGICAL FIXTURE — NOT BUSYBOX. Fast static/component
# teaching artifact only; never used as real BusyBox runtime evidence.
SYNTHETIC_BIN := $(BUILD_DIR)/synthetic_multicall
SYNTHETIC_ROOTFS := $(BUILD_DIR)/synthetic_rootfs
SYNTHETIC_ARCHIVE := $(BUILD_DIR)/synthetic_rootfs.cpio.gz
# Real BusyBox rootfs/initramfs (staged from real 1.36.1 build output).
REAL_ROOTFS := $(BUILD_DIR)/real_rootfs
REAL_ARCHIVE := $(BUILD_DIR)/real_rootfs.cpio.gz
BUSYBOX_SRC ?= /tmp/busybox-1.36.1
REAL_STAGING ?= /tmp/rootfs-busybox-staging

.PHONY: all clean synthetic real

all: synthetic

synthetic: $(SYNTHETIC_ARCHIVE)

$(SYNTHETIC_BIN): src/synthetic_multicall.c
	@mkdir -p $(BUILD_DIR)
	$(CC) -static -Wall -Werror -O2 src/synthetic_multicall.c -o $@

$(SYNTHETIC_ARCHIVE): $(SYNTHETIC_BIN)
	@rm -rf $(SYNTHETIC_ROOTFS)
	@mkdir -p $(SYNTHETIC_ROOTFS)/bin $(SYNTHETIC_ROOTFS)/sbin $(SYNTHETIC_ROOTFS)/etc/init.d $(SYNTHETIC_ROOTFS)/dev $(SYNTHETIC_ROOTFS)/proc $(SYNTHETIC_ROOTFS)/sys $(SYNTHETIC_ROOTFS)/tmp $(SYNTHETIC_ROOTFS)/run $(SYNTHETIC_ROOTFS)/mnt $(SYNTHETIC_ROOTFS)/root
	@cp $(SYNTHETIC_BIN) $(SYNTHETIC_ROOTFS)/bin/synthetic_multicall
	@chmod 755 $(SYNTHETIC_ROOTFS)/bin/synthetic_multicall
	@ln -sf synthetic_multicall $(SYNTHETIC_ROOTFS)/bin/sh
	@ln -sf synthetic_multicall $(SYNTHETIC_ROOTFS)/bin/ls
	@ln -sf synthetic_multicall $(SYNTHETIC_ROOTFS)/bin/ps
	@ln -sf synthetic_multicall $(SYNTHETIC_ROOTFS)/bin/mount
	@ln -sf synthetic_multicall $(SYNTHETIC_ROOTFS)/bin/echo
	@ln -sf synthetic_multicall $(SYNTHETIC_ROOTFS)/bin/cat
	@ln -sf ../bin/synthetic_multicall $(SYNTHETIC_ROOTFS)/sbin/init
	@ln -sf bin/synthetic_multicall $(SYNTHETIC_ROOTFS)/init
	@echo "#!/bin/sh" > $(SYNTHETIC_ROOTFS)/etc/init.d/rcS
	@echo "mount -t proc none /proc" >> $(SYNTHETIC_ROOTFS)/etc/init.d/rcS
	@echo "mount -t sysfs none /sys" >> $(SYNTHETIC_ROOTFS)/etc/init.d/rcS
	@echo "mount -t devtmpfs none /dev 2>/dev/null || true" >> $(SYNTHETIC_ROOTFS)/etc/init.d/rcS
	@chmod 755 $(SYNTHETIC_ROOTFS)/etc/init.d/rcS
	@echo "::sysinit:/etc/init.d/rcS" > $(SYNTHETIC_ROOTFS)/etc/inittab
	@echo "::askfirst:-/bin/sh" >> $(SYNTHETIC_ROOTFS)/etc/inittab
	@echo "::ctrlaltdel:/sbin/reboot" >> $(SYNTHETIC_ROOTFS)/etc/inittab
	@echo "::shutdown:/bin/umount -a -r" >> $(SYNTHETIC_ROOTFS)/etc/inittab
	@bash $(M03_ROOT)/scripts/package_initramfs.sh $(SYNTHETIC_ROOTFS) $(SYNTHETIC_ARCHIVE)

# Real BusyBox rootfs staging + packaging. Requires a completed real
# BusyBox 1.36.1 build (see scripts/build_real_busybox.sh).
real:
	@bash $(M03_ROOT)/scripts/stage_real_rootfs.sh $(REAL_STAGING) $(REAL_ROOTFS)
	@bash $(M03_ROOT)/scripts/package_initramfs.sh $(REAL_ROOTFS) $(REAL_ARCHIVE)

clean:
	@rm -rf $(BUILD_DIR)
