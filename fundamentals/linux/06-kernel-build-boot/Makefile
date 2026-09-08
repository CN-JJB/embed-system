# P3-M02 — Linux Kernel Source Orientation, Kconfig, Build Flow & Image Artifacts
SHELL := /bin/bash

CROSS_COMPILE ?= arm-none-linux-gnueabihf-

ifneq ($(MAKECMDGOALS),clean)
  ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
    $(error Cross-compiler '$(CROSS_COMPILE)gcc' not found in PATH. Canonical baseline requires Arm GNU Toolchain 13.3.rel1 (arm-none-linux-gnueabihf-). For Ubuntu/Debian distro toolchain, pass explicitly: make CROSS_COMPILE=arm-linux-gnueabihf-)
  endif
endif

LINUX_SRC ?= /tmp/linux-6.18.50

.PHONY: all clean check mutations fixtures challenge-build gate-build real-kernel-check

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

mutations:
	CROSS_COMPILE=$(CROSS_COMPILE) bash reviewer/test_m02_mutations.sh

real-kernel-check:
	CROSS_COMPILE=$(CROSS_COMPILE) bash scripts/build_real_kernel.sh $(LINUX_SRC)
