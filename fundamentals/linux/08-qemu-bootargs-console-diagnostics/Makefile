# P3-M04 — QEMU Bootargs, Console Handoff, and Boot Diagnostics
SHELL := /bin/bash

M04_ROOT := $(abspath .)
LINUX_SRC ?= /tmp/linux-6.18.50

.PHONY: all gate-provision challenge-provision gate-build challenge-build check real-bootargs-qemu-check clean

all: gate-provision challenge-provision

gate-provision:
	@$(MAKE) -C gate provision

challenge-provision:
	@$(MAKE) -C challenge provision

# Backwards-compatible aliases (provision opaque assessment workspaces).
gate-build: gate-provision

challenge-build: challenge-provision

check: gate-provision
	@bash $(M04_ROOT)/scripts/verify_m04.sh

real-bootargs-qemu-check:
	@echo "=== Running Real QEMU Bootargs Diagnostic Test (REAL BusyBox) ==="
	@TIMEOUT_SEC=40 bash $(M04_ROOT)/scripts/run_qemu_diagnostic.sh "earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init" /tmp/real_bootargs_test.log
	@bash $(M04_ROOT)/scripts/verify_runtime_boot.sh /tmp/real_bootargs_test.log "earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"
	@echo "[PASS] Real QEMU bootargs diagnostic test verified (runtime-bound)."

clean:
	@$(MAKE) -C gate clean
	@$(MAKE) -C challenge clean
	@rm -f /tmp/real_bootargs_test.log
