# P3-M02 Module Gate Makefile
ARTIFACTS_DIR := ../fixtures/artifacts
CONFIGS_DIR := ../fixtures/configs

.PHONY: all clean

all: fixtures

fixtures:
	mkdir -p fixtures
	cp $(CONFIGS_DIR)/effective_kernel.config fixtures/gate_effective.config
	cp $(ARTIFACTS_DIR)/vmlinux fixtures/gate_vmlinux
	cp $(ARTIFACTS_DIR)/arch/arm/boot/zImage fixtures/gate_zImage
	cp $(ARTIFACTS_DIR)/System.map fixtures/gate_System.map

clean:
	rm -rf fixtures
