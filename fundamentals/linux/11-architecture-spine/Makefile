# P3-M07 — Architecture Spine: privilege, syscall trap, MMU & address translation.
#
# Default targets are LEARNER-SAFE and must never download a kernel, build a
# kernel/Buildroot image, run a long QEMU session, require root, or require an
# external cross toolchain.  The only heavyweight path is `real-arch-check`,
# which is opt-in and requires an explicitly supplied target kernel + initramfs.
SHELL := /bin/bash

M07_ROOT := $(abspath .)
PYTHON   ?= python3

# Canonical Phase 3 cross prefix.  A host alternate (e.g. the distro
# `arm-linux-gnueabihf-`) is tolerated by the calibration script but is
# reported as an *actual-host* toolchain, never as the canonical baseline.
CROSS_COMPILE ?= arm-none-linux-gnueabihf-

# Authoring-regression entry points (`mutations`, `reviewer-check`) are wired at
# the sequence level in `fundamentals/linux/Makefile`.  They deliberately do not
# appear here: module-local material must never name assessment-private assets,
# which is verified by the isolation audit run from `make reviewer-check`.
.PHONY: all clean check \
        gate-provision challenge-provision \
        compile-check disasm-check real-arch-check

all: gate-provision challenge-provision

# --- learner-safe verification -------------------------------------------------

# Format / packaging / safe-invariant checks only.  Never invokes grading logic
# and never reads assessment-private reference mappings.
check: gate-provision challenge-provision
	@bash $(M07_ROOT)/scripts/verify_m07.sh

# --- assessment workspaces -----------------------------------------------------

gate-provision:
	@$(MAKE) -C gate provision

challenge-provision:
	@$(MAKE) -C challenge provision

# --- optional static target-artifact calibration (cross toolchain required) ----
#
# Compiles the lab artifacts for ARM and proves the SVC opcode in the executed
# path.  This is *static* evidence: it does not prove guest execution.
# Opt-in only; `check` never depends on it.  Fails closed (non-zero) when the
# calibration script or the cross toolchain is absent instead of silently
# reporting success.
CALIB := $(M07_ROOT)/scripts/target_artifact_calibration.sh
compile-check disasm-check:
	@if [ ! -f "$(CALIB)" ]; then \
		echo "ERROR: $(CALIB) is not present in this revision;" >&2; \
		echo "       target compile/disassembly evidence is UNVERIFIED." >&2; \
		exit 1; \
	fi
	@bash $(CALIB) --cross-compile "$(CROSS_COMPILE)" --mode $@

# --- heavy, opt-in real-QEMU architecture observation -------------------------
#
# Requires an explicitly supplied target kernel image and initramfs; the
# canonical appliance contract is:
#   qemu-system-arm -machine virt,highmem=off,gic-version=2 -cpu cortex-a7 \
#                   -m 512M -smp 1 -nographic
# Usage:
#   make real-arch-check KERNEL=/path/to/Image INITRD=/path/to/rootfs.cpio.gz
# Reports `actual-host QEMU runtime` and `canonical QEMU 11.1.1 runtime`
# separately; the canonical dimension stays UNVERIFIED unless the host QEMU
# really is 11.1.1.
real-arch-check:
	@if [ -z "$(KERNEL)" ] || [ -z "$(INITRD)" ]; then \
		echo "usage: make real-arch-check KERNEL=<Image> INITRD=<rootfs.cpio.gz>" >&2; \
		echo "[NOTE] canonical contract: -machine virt,highmem=off,gic-version=2 -cpu cortex-a7 -m 512M -smp 1 -nographic" >&2; \
		echo "[NOTE] without a real kernel + initramfs the guest-boot dimension stays UNVERIFIED." >&2; \
		exit 1; \
	fi
	@if [ ! -f "$(M07_ROOT)/scripts/real_arch_check.sh" ]; then \
		echo "ERROR: scripts/real_arch_check.sh is not present in this revision;" >&2; \
		echo "       the opt-in heavy path is therefore UNVERIFIED." >&2; \
		exit 1; \
	fi
	@KERNEL="$(KERNEL)" INITRD="$(INITRD)" CROSS_COMPILE="$(CROSS_COMPILE)" \
	    bash $(M07_ROOT)/scripts/real_arch_check.sh

clean:
	@$(MAKE) -C gate clean
	@$(MAKE) -C challenge clean
	@rm -rf $(M07_ROOT)/build 2>/dev/null || true
	@find $(M07_ROOT) -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@find $(M07_ROOT) -name "*.pyc" -delete 2>/dev/null || true
