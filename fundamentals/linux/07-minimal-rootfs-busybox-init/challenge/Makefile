CROSS_COMPILE ?= arm-none-linux-gnueabihf-
M03_ROOT := $(abspath ..)

BUILD_DIR := $(CURDIR)/build
ROOTFS_DIR := $(BUILD_DIR)/rootfs_challenge
ARCHIVE := $(BUILD_DIR)/rootfs_challenge.cpio.gz

.PHONY: all clean

all: $(ARCHIVE)

$(ARCHIVE): $(M03_ROOT)/fixtures/build/busybox
	@rm -rf $(ROOTFS_DIR)
	@mkdir -p $(ROOTFS_DIR)/bin $(ROOTFS_DIR)/sbin $(ROOTFS_DIR)/etc/init.d $(ROOTFS_DIR)/dev $(ROOTFS_DIR)/proc $(ROOTFS_DIR)/sys $(ROOTFS_DIR)/tmp $(ROOTFS_DIR)/run $(ROOTFS_DIR)/mnt $(ROOTFS_DIR)/root
	@cp $(M03_ROOT)/fixtures/build/busybox $(ROOTFS_DIR)/bin/busybox
	@chmod 755 $(ROOTFS_DIR)/bin/busybox
	@ln -sf busybox $(ROOTFS_DIR)/bin/sh
	@ln -sf busybox $(ROOTFS_DIR)/bin/ls
	@ln -sf busybox $(ROOTFS_DIR)/bin/ps
	@ln -sf busybox $(ROOTFS_DIR)/bin/mount
	@ln -sf busybox $(ROOTFS_DIR)/bin/echo
	@ln -sf busybox $(ROOTFS_DIR)/bin/cat
	@ln -sf ../bin/busybox $(ROOTFS_DIR)/sbin/init
	@ln -sf bin/busybox $(ROOTFS_DIR)/init
	@echo "#!/bin/sh" > $(ROOTFS_DIR)/etc/init.d/rcS
	@echo "mount -t proc none /proc" >> $(ROOTFS_DIR)/etc/init.d/rcS
	@echo "mount -t sysfs none /sys" >> $(ROOTFS_DIR)/etc/init.d/rcS
	@echo "mount -t devtmpfs none /dev 2>/dev/null || true" >> $(ROOTFS_DIR)/etc/init.d/rcS
	@chmod 755 $(ROOTFS_DIR)/etc/init.d/rcS
	@echo "::sysinit:/etc/init.d/rcS" > $(ROOTFS_DIR)/etc/inittab
	@echo "ttyAMA0::askfirst:-/bin/sh" >> $(ROOTFS_DIR)/etc/inittab
	@echo "::ctrlaltdel:/sbin/reboot" >> $(ROOTFS_DIR)/etc/inittab
	@echo "::shutdown:/bin/umount -a -r" >> $(ROOTFS_DIR)/etc/inittab
	@bash $(M03_ROOT)/scripts/package_initramfs.sh $(ROOTFS_DIR) $(ARCHIVE)

clean:
	@rm -rf $(BUILD_DIR)
