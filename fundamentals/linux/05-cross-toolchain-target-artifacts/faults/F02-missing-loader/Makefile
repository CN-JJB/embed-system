CROSS_COMPILE ?= arm-none-linux-gnueabihf-
ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
  ifneq ($(shell which arm-linux-gnueabihf-gcc 2>/dev/null),)
    CROSS_COMPILE := arm-linux-gnueabihf-
  endif
endif

CC := $(CROSS_COMPILE)gcc
CFLAGS ?= -Wall -Wextra -O2

ROOTFS_DIR := rootfs_fixture

.PHONY: all clean setup-fixture

all: setup-fixture

setup-fixture: app_src.c
	mkdir -p $(ROOTFS_DIR)/bin $(ROOTFS_DIR)/lib
	# Compile dynamic ARM binary
	$(CC) $(CFLAGS) app_src.c -o $(ROOTFS_DIR)/bin/app_dynamic
	# Create a decoy/unrelated loader in lib (musl loader) to demonstrate ABI mismatch
	echo "DECOY_MUSL_LOADER" > $(ROOTFS_DIR)/lib/ld-musl-armhf.so.1

clean:
	rm -rf $(ROOTFS_DIR)
