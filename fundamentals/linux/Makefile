CROSS_COMPILE ?= arm-none-linux-gnueabihf-

.PHONY: all clean check mutations reviewer-check real-kernel-build-check real-qemu-check real-busybox-build-check real-m03-qemu-check real-m04-qemu-check real-m05-dt-check real-m06-buildroot-check real-m07-arch-check

all:
	$(MAKE) -C 05-cross-toolchain-target-artifacts all CROSS_COMPILE=$(CROSS_COMPILE)
	$(MAKE) -C 06-kernel-build-boot all CROSS_COMPILE=$(CROSS_COMPILE)
	$(MAKE) -C 07-minimal-rootfs-busybox-init all CROSS_COMPILE=$(CROSS_COMPILE)
	$(MAKE) -C 08-qemu-bootargs-console-diagnostics all
	$(MAKE) -C 09-device-tree-first-pass all
	$(MAKE) -C 10-shallow-buildroot all
	$(MAKE) -C 11-architecture-spine all CROSS_COMPILE=$(CROSS_COMPILE)

clean:
	$(MAKE) -C 05-cross-toolchain-target-artifacts clean
	$(MAKE) -C 06-kernel-build-boot clean
	$(MAKE) -C 07-minimal-rootfs-busybox-init clean
	$(MAKE) -C 08-qemu-bootargs-console-diagnostics clean
	$(MAKE) -C 09-device-tree-first-pass clean
	$(MAKE) -C 10-shallow-buildroot clean
	$(MAKE) -C 11-architecture-spine clean

# Learner-safe checks only; no reviewer tooling, no answer mappings.
# No heavy build (kernel / Buildroot / QEMU) is triggered here: those remain
# opt-in through the real-* targets below.
check:
	@echo "=== Running P3-M01 Learner-Safe Checks ==="
	$(MAKE) -C 05-cross-toolchain-target-artifacts check CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "=== Running P3-M02 Learner-Safe Checks ==="
	$(MAKE) -C 06-kernel-build-boot check CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "=== Running P3-M03 Learner-Safe Checks ==="
	$(MAKE) -C 07-minimal-rootfs-busybox-init check CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "=== Running P3-M04 Learner-Safe Checks ==="
	$(MAKE) -C 08-qemu-bootargs-console-diagnostics check
	@echo "=== Running P3-M05 Learner-Safe Checks ==="
	$(MAKE) -C 09-device-tree-first-pass check
	@echo "=== Running P3-M06 Learner-Safe Checks ==="
	$(MAKE) -C 10-shallow-buildroot check
	@echo "=== Running P3-M07 Learner-Safe Checks ==="
	$(MAKE) -C 11-architecture-spine check CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "=== ALL PHASE 3 LINUX BOOT-CHAIN (M01..M07) LEARNER-SAFE CHECKS PASSED ==="

# Reviewer-only authoring regression; never invoked by learner workflows.
mutations:
	@echo "=== Running P3-M01 Component Validator Mutations ==="
	CROSS_COMPILE=$(CROSS_COMPILE) bash 05-cross-toolchain-target-artifacts/reviewer/test_m01_mutations.sh
	@echo "=== Running P3-M02 Component Validator Mutations ==="
	CROSS_COMPILE=$(CROSS_COMPILE) bash 06-kernel-build-boot/reviewer/test_m02_mutations.sh
	@echo "=== Running P3-M03 Component Validator Mutations ==="
	CROSS_COMPILE=$(CROSS_COMPILE) bash 07-minimal-rootfs-busybox-init/reviewer/test_m03_mutations.sh
	@echo "=== Running P3-M04 Component Validator Mutations ==="
	bash 08-qemu-bootargs-console-diagnostics/reviewer/test_m04_mutations.sh
	@echo "=== Running P3-M05 Component Validator Mutations ==="
	bash 09-device-tree-first-pass/reviewer/test_m05_mutations.sh
	@echo "=== Running P3-M06 Component Validator Mutations ==="
	bash 10-shallow-buildroot/reviewer/test_m06_mutations.sh
	@echo "=== Running P3-M07 Component Validator Mutations ==="
	CROSS_COMPILE=$(CROSS_COMPILE) bash 11-architecture-spine/reviewer/test_m07_mutations.sh
	@echo "=== ALL PHASE 3 LINUX COMPONENT MUTATION CHECKS PASSED ==="

reviewer-check:
	@echo "=== Running P3-M01 Reviewer Check ==="
	CROSS_COMPILE=$(CROSS_COMPILE) bash 05-cross-toolchain-target-artifacts/reviewer/run_m01_reviewer_check.sh
	@echo "=== Running P3-M02 Reviewer Check ==="
	CROSS_COMPILE=$(CROSS_COMPILE) bash 06-kernel-build-boot/reviewer/run_m02_reviewer_check.sh
	@echo "=== Running P3-M03 Reviewer Check ==="
	CROSS_COMPILE=$(CROSS_COMPILE) bash 07-minimal-rootfs-busybox-init/reviewer/run_m03_reviewer_check.sh
	@echo "=== Running P3-M04 Reviewer Check ==="
	bash 08-qemu-bootargs-console-diagnostics/reviewer/run_m04_reviewer_check.sh
	@echo "=== Running P3-M05 Reviewer Check ==="
	bash 09-device-tree-first-pass/reviewer/run_m05_reviewer_check.sh
	@echo "=== Running P3-M06 Reviewer Check ==="
	bash 10-shallow-buildroot/reviewer/run_m06_reviewer_check.sh
	@echo "=== Running P3-M07 Reviewer Check ==="
	LINUX_SRC=$(LINUX_SRC) CROSS_COMPILE=$(CROSS_COMPILE) bash 11-architecture-spine/reviewer/run_m07_reviewer_check.sh
	@echo "=== ALL PHASE 3 LINUX REVIEWER CHECKS PASSED ==="

real-kernel-build-check:
	$(MAKE) -C 06-kernel-build-boot real-kernel-build-check CROSS_COMPILE=$(CROSS_COMPILE)

real-qemu-check:
	$(MAKE) -C 06-kernel-build-boot real-qemu-check

real-busybox-build-check:
	$(MAKE) -C 07-minimal-rootfs-busybox-init real-busybox-build-check CROSS_COMPILE=$(CROSS_COMPILE)

real-m03-qemu-check:
	$(MAKE) -C 07-minimal-rootfs-busybox-init real-qemu-check

real-m04-qemu-check:
	$(MAKE) -C 08-qemu-bootargs-console-diagnostics real-bootargs-qemu-check

# P3-M05: real QEMU DTB generation + real dtc round trip.  Requires
# qemu-system-arm and dtc on the host; opt-in, never part of `check`.
real-m05-dt-check:
	$(MAKE) -C 09-device-tree-first-pass dump-dtb
	$(MAKE) -C 09-device-tree-first-pass roundtrip

# P3-M06: real Buildroot appliance build + boot.  Heavy; opt-in.
# Usage: make real-m06-buildroot-check BUILDROOT_SRC=/path/to/buildroot-2026.05.2
real-m06-buildroot-check:
	$(MAKE) -C 10-shallow-buildroot build BUILDROOT_SRC=$(BUILDROOT_SRC)

# P3-M07: real QEMU arch-spine observation (svc execution, /proc/maps,
# controlled address-fault evidence).  Heavy; opt-in, never part of `check`.
# Usage: make real-m07-arch-check KERNEL=/path/to/zImage INITRD=/path/to/rootfs.cpio.gz
real-m07-arch-check:
	$(MAKE) -C 11-architecture-spine real-arch-check CROSS_COMPILE=$(CROSS_COMPILE) KERNEL=$(KERNEL) INITRD=$(INITRD)
