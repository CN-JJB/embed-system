# P3-M01 — Cross-Compilation Toolchains & Target Artifacts
SHELL := /bin/bash

# Toolchain detection: canonical first, distro fallback
CROSS_COMPILE ?= arm-none-linux-gnueabihf-
ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
  ifneq ($(shell which arm-linux-gnueabihf-gcc 2>/dev/null),)
    CROSS_COMPILE := arm-linux-gnueabihf-
  endif
endif

CC := $(CROSS_COMPILE)gcc
HOST_CC ?= gcc
READELF ?= $(CROSS_COMPILE)readelf
ifeq ($(shell which $(READELF) 2>/dev/null),)
  READELF := readelf
endif

CFLAGS ?= -Wall -Wextra -O2 -g

.PHONY: all clean check mutations

all: labs-build faults-build challenge-build gate-build

labs-build:
	$(MAKE) -C labs/01-host-vs-target all CROSS_COMPILE=$(CROSS_COMPILE)
	$(MAKE) -C labs/03-dynamic-elf all CROSS_COMPILE=$(CROSS_COMPILE)
	$(MAKE) -C labs/04-static-elf all CROSS_COMPILE=$(CROSS_COMPILE)

faults-build:
	$(MAKE) -C faults/F01-wrong-architecture all CROSS_COMPILE=$(CROSS_COMPILE)
	$(MAKE) -C faults/F02-missing-loader all CROSS_COMPILE=$(CROSS_COMPILE)

challenge-build:
	$(MAKE) -C challenge all CROSS_COMPILE=$(CROSS_COMPILE)

gate-build:
	$(MAKE) -C gate all CROSS_COMPILE=$(CROSS_COMPILE)

clean:
	$(MAKE) -C labs/01-host-vs-target clean
	$(MAKE) -C labs/03-dynamic-elf clean
	$(MAKE) -C labs/04-static-elf clean
	$(MAKE) -C faults/F01-wrong-architecture clean
	$(MAKE) -C faults/F02-missing-loader clean
	$(MAKE) -C challenge clean
	$(MAKE) -C gate clean

check: all
	bash scripts/verify_m01.sh

mutations:
	bash reviewer/test_m01_mutations.sh
