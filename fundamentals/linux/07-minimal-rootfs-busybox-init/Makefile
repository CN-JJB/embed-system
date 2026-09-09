# P3-M03 — Manual Minimal Rootfs, BusyBox, Pseudo-Filesystems & PID 1 Init Lifecycle
SHELL := /bin/bash

CROSS_COMPILE ?= arm-none-linux-gnueabihf-

ifneq ($(MAKECMDGOALS),clean)
  ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
    $(error Cross-compiler '$(CROSS_COMPILE)gcc' not found in PATH. Canonical baseline requires Arm GNU Toolchain 13.3.rel1 (arm-none-linux-gnueabihf-). For Ubuntu/Debian distro toolchain, pass explicitly: make CROSS_COMPILE=arm-linux-gnueabihf-)
  endif
endif

BUSYBOX_SRC ?= /tmp/busybox-1.36.1
LINUX_SRC ?= /tmp/linux-6.18.50

.PHONY: all clean check fixtures challenge-build gate-build real-busybox-build-check real-qemu-check

all: fixtures challenge-build gate-build

fixtures:
	$(MAKE) -C fixtures all CROSS_COMPILE=$(CROSS_COMPILE)

challenge-build: fixtures
	$(MAKE) -C challenge all CROSS_COMPILE=$(CROSS_COMPILE)

gate-build: fixtures
	$(MAKE) -C gate all CROSS_COMPILE=$(CROSS_COMPILE)

clean:
	$(MAKE) -C fixtures clean
	$(MAKE) -C challenge clean
	$(MAKE) -C gate clean

check: all
	CROSS_COMPILE=$(CROSS_COMPILE) bash scripts/verify_m03.sh

# Real BusyBox 1.36.1 build + static ELF & staging audit
real-busybox-build-check:
	CROSS_COMPILE=$(CROSS_COMPILE) bash scripts/build_real_busybox.sh $(BUSYBOX_SRC) /tmp/rootfs-busybox-staging

# Strict actual-host QEMU runtime boot to interactive shell
real-qemu-check:
	bash scripts/run_real_qemu_m03.sh $(LINUX_SRC)
