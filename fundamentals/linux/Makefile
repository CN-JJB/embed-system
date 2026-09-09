CROSS_COMPILE ?= arm-none-linux-gnueabihf-

.PHONY: all clean check mutations reviewer-check real-kernel-build-check real-qemu-check

all:
	$(MAKE) -C 05-cross-toolchain-target-artifacts all CROSS_COMPILE=$(CROSS_COMPILE)
	$(MAKE) -C 06-kernel-build-boot all CROSS_COMPILE=$(CROSS_COMPILE)

clean:
	$(MAKE) -C 05-cross-toolchain-target-artifacts clean
	$(MAKE) -C 06-kernel-build-boot clean

# Learner-safe checks only; no reviewer tooling, no answer mappings.
check:
	@echo "=== Running P3-M01 Learner-Safe Checks ==="
	$(MAKE) -C 05-cross-toolchain-target-artifacts check CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "=== Running P3-M02 Learner-Safe Checks ==="
	$(MAKE) -C 06-kernel-build-boot check CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "=== ALL PHASE 3 LINUX BOOT-CHAIN (M01, M02) LEARNER-SAFE CHECKS PASSED ==="

# Reviewer-only authoring regression; never invoked by learner workflows.
mutations:
	@echo "=== Running P3-M01 Component Validator Mutations ==="
	CROSS_COMPILE=$(CROSS_COMPILE) bash 05-cross-toolchain-target-artifacts/reviewer/test_m01_mutations.sh
	@echo "=== Running P3-M02 Component Validator Mutations ==="
	CROSS_COMPILE=$(CROSS_COMPILE) bash 06-kernel-build-boot/reviewer/test_m02_mutations.sh
	@echo "=== ALL PHASE 3 LINUX COMPONENT MUTATION CHECKS PASSED ==="

reviewer-check:
	@echo "=== Running P3-M01 Reviewer Check ==="
	CROSS_COMPILE=$(CROSS_COMPILE) bash 05-cross-toolchain-target-artifacts/reviewer/run_m01_reviewer_check.sh
	@echo "=== Running P3-M02 Reviewer Check ==="
	CROSS_COMPILE=$(CROSS_COMPILE) bash 06-kernel-build-boot/reviewer/run_m02_reviewer_check.sh
	@echo "=== ALL PHASE 3 LINUX REVIEWER CHECKS PASSED ==="

real-kernel-build-check:
	$(MAKE) -C 06-kernel-build-boot real-kernel-build-check CROSS_COMPILE=$(CROSS_COMPILE)

real-qemu-check:
	$(MAKE) -C 06-kernel-build-boot real-qemu-check