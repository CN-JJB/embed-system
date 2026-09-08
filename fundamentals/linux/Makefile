.PHONY: all clean check

all:
	$(MAKE) -C 05-cross-toolchain-target-artifacts all
	$(MAKE) -C 06-kernel-build-boot all

clean:
	$(MAKE) -C 05-cross-toolchain-target-artifacts clean
	$(MAKE) -C 06-kernel-build-boot clean

check:
	@echo "=== Running P3-M01 Checks ==="
	$(MAKE) -C 05-cross-toolchain-target-artifacts check
	@echo "=== Running P3-M02 Checks ==="
	$(MAKE) -C 06-kernel-build-boot check
	@echo "=== ALL PHASE 3 LINUX BOOT-CHAIN (M01, M02) CHECKS PASSED ==="
