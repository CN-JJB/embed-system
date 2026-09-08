CROSS_COMPILE ?= arm-none-linux-gnueabihf-

.PHONY: all clean check mutations

all:
	$(MAKE) -C 05-cross-toolchain-target-artifacts all CROSS_COMPILE=$(CROSS_COMPILE)
	$(MAKE) -C 06-kernel-build-boot all CROSS_COMPILE=$(CROSS_COMPILE)

clean:
	$(MAKE) -C 05-cross-toolchain-target-artifacts clean
	$(MAKE) -C 06-kernel-build-boot clean

check:
	@echo "=== Running P3-M01 Checks ==="
	$(MAKE) -C 05-cross-toolchain-target-artifacts check CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "=== Running P3-M02 Checks ==="
	$(MAKE) -C 06-kernel-build-boot check CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "=== ALL PHASE 3 LINUX BOOT-CHAIN (M01, M02) CHECKS PASSED ==="

mutations:
	@echo "=== Running P3-M01 Mutations ==="
	$(MAKE) -C 05-cross-toolchain-target-artifacts mutations CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "=== Running P3-M02 Mutations ==="
	$(MAKE) -C 06-kernel-build-boot mutations CROSS_COMPILE=$(CROSS_COMPILE)
	@echo "=== ALL PHASE 3 LINUX MUTATION CHECKS PASSED ==="
