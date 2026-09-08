# P3-M02 — Linux Kernel Source Orientation, Kconfig, Build Flow & Image Artifacts
SHELL := /bin/bash

# Cross-compiler detection
CROSS_COMPILE ?= arm-none-linux-gnueabihf-
ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
  ifneq ($(shell which arm-linux-gnueabihf-gcc 2>/dev/null),)
    CROSS_COMPILE := arm-linux-gnueabihf-
  endif
endif

.PHONY: all clean check mutations fixtures challenge-build gate-build

all: fixtures challenge-build gate-build

fixtures:
	$(MAKE) -C fixtures/artifacts all CROSS_COMPILE=$(CROSS_COMPILE)
	$(MAKE) -C faults/F03-stale-system-map all

challenge-build: fixtures
	$(MAKE) -C challenge all

gate-build: fixtures
	$(MAKE) -C gate all

clean:
	$(MAKE) -C fixtures/artifacts clean
	$(MAKE) -C faults/F03-stale-system-map clean
	$(MAKE) -C challenge clean
	$(MAKE) -C gate clean

check: all
	bash scripts/verify_m02.sh

mutations:
	bash reviewer/test_m02_mutations.sh
