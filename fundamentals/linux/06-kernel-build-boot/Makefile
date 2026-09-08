# P3-M02 — Linux Kernel Source Orientation, Kconfig, Build Flow & Image Artifacts
SHELL := /bin/bash

CROSS_COMPILE ?= arm-none-linux-gnueabihf-

ifneq ($(MAKECMDGOALS),clean)
  ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
    $(error Cross-compiler '$(CROSS_COMPILE)gcc' not found in PATH. Canonical baseline requires Arm GNU Toolchain 13.3.rel1 (arm-none-linux-gnueabihf-). For Ubuntu/Debian distro toolchain, pass explicitly: make CROSS_COMPILE=arm-linux-gnueabihf-)
  endif
endif

LINUX_SRC ?= /tmp/linux-6.18.50

.PHONY: all clean check fixtures challenge-build gate-build real-kernel-build-check real-qemu-check

all: fixtures challenge-build gate-build

fixtures:
	$(MAKE) -C fixtures/artifacts all CROSS_COMPILE=$(CROSS_COMPILE)
	$(MAKE) -C faults/F03-stale-system-map all

challenge-build: fixtures
	$(MAKE) -C challenge all CROSS_COMPILE=$(CROSS_COMPILE)

gate-build: fixtures
	$(MAKE) -C gate all CROSS_COMPILE=$(CROSS_COMPILE)

clean:
	$(MAKE) -C fixtures/artifacts clean
	$(MAKE) -C faults/F03-stale-system-map clean
	$(MAKE) -C challenge clean
	$(MAKE) -C gate clean

check: all
	CROSS_COMPILE=$(CROSS_COMPILE) bash scripts/verify_m02.sh

# Authoring-only assessment regression (isolation / mutations / grading oracle)
# lives in the parent fundamentals/linux Makefile. This module Makefile is
# learner-facing and deliberately contains no assessment tooling.

# Real Linux 6.18.50 build + artifact audit (no QEMU requirement).
real-kernel-build-check:
	CROSS_COMPILE=$(CROSS_COMPILE) bash scripts/build_real_kernel.sh $(LINUX_SRC)

# Strict actual-host QEMU runtime regression (requires QEMU and the expected
# boot milestone; any shortfall is FAIL, not a note).
real-qemu-check:
	bash scripts/run_real_qemu.sh $(LINUX_SRC)
