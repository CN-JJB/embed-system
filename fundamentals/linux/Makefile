CROSS_COMPILE ?= arm-none-linux-gnueabihf-

.PHONY: all clean check mutations reviewer-check real-kernel-build-check real-qemu-check real-busybox-build-check real-m03-qemu-check real-m04-qemu-check

all:
	$(MAKE) -C 05-cross-toolchain-target-artifacts all CROSS_COMPILE=$(CROSS_COMPILE)
	$(MAKE) -C 06-kernel-build-boot all CROSS_COMPILE=$(CROSS_COMPILE)
	$(MAKE) -C 07-minimal-rootfs-busybox-init all CROSS_COMPILE=$(CROSS_COMPILE)
	$(MAKE) -C 08-qemu-bootargs-console-diagnostics all

clean:
	$(MAKE) -C 05-cross-toolchain-target-artifacts clean
	$(MAKE) -C 06-kernel-build-boot clean
	$(MAKE) -C 07-minimal-rootfs-busybox-init clean
	$(MAKE) -C 08-qemu-bootargs-console-diagnostics clean

# Learner-safe checks only; no reviewer tooling, no answer mappings.
check:
	@echo "=== Running P3-M01 Learner-Safe Checks ==="
	$(MAKE) -C 05-cross-toolchain-target-artifacts check CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "=== Running P3-M02 Learner-Safe Checks ==="
	$(MAKE) -C 06-kernel-build-boot check CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "=== Running P3-M03 Learner-Safe Checks ==="
	$(MAKE) -C 07-minimal-rootfs-busybox-init check CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "=== Running P3-M04 Learner-Safe Checks ==="
	$(MAKE) -C 08-qemu-bootargs-console-diagnostics check
	@echo "=== ALL PHASE 3 LINUX BOOT-CHAIN (M01..M04) LEARNER-SAFE CHECKS PASSED ==="

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