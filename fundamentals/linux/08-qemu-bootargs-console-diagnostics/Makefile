# P3-M04 — QEMU Bootargs, Console Handoff, and Boot Diagnostics
SHELL := /bin/bash

M04_ROOT := $(abspath .)
LINUX_SRC ?= /tmp/linux-6.18.50

.PHONY: all gate-build challenge-build check real-bootargs-qemu-check clean

all: gate-build challenge-build

gate-build:
	@$(MAKE) -C gate gate-build

challenge-build:
	@$(MAKE) -C challenge challenge-build

check: gate-build
	@bash $(M04_ROOT)/scripts/verify_m04.sh

real-bootargs-qemu-check:
	@echo "=== Running Real QEMU Bootargs Diagnostic Test ==="
	@bash $(M04_ROOT)/scripts/run_qemu_diagnostic.sh "earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init" /tmp/real_bootargs_test.log
	@bash $(M04_ROOT)/scripts/audit_boot_milestones.sh /tmp/real_bootargs_test.log
	@echo "[PASS] Real QEMU bootargs diagnostic test verified."

clean:
	@$(MAKE) -C gate clean
	@$(MAKE) -C challenge clean
	@rm -f /tmp/real_bootargs_test.log
