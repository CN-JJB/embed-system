M04_ROOT := $(abspath ..)
BUILD_DIR := $(CURDIR)/build
CONFIG_SCRIPT := $(BUILD_DIR)/gate_boot_config.sh

.PHONY: all gate-build check clean

all: gate-build

gate-build:
	@mkdir -p $(BUILD_DIR)
	@echo '#!/bin/bash' > $(CONFIG_SCRIPT)
	@echo '# Canonical QEMU ARM Cortex-A7 Launch Configuration' >> $(CONFIG_SCRIPT)
	@echo 'MACHINE="-machine virt,highmem=off,gic-version=2"' >> $(CONFIG_SCRIPT)
	@echo 'CPU="-cpu cortex-a7"' >> $(CONFIG_SCRIPT)
	@echo 'MEM="-m 512M"' >> $(CONFIG_SCRIPT)
	@echo 'SMP="-smp 1"' >> $(CONFIG_SCRIPT)
	@echo 'DISPLAY_OPT="-nographic"' >> $(CONFIG_SCRIPT)
	@echo 'BOOTARGS="earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"' >> $(CONFIG_SCRIPT)
	@echo 'qemu-system-arm $$MACHINE $$CPU $$MEM $$SMP $$DISPLAY_OPT -kernel "$$KERNEL" -initrd "$$INITRD" -append "$$BOOTARGS"' >> $(CONFIG_SCRIPT)
	@chmod 755 $(CONFIG_SCRIPT)
	@echo "[GATE] Generated canonical gate boot configuration at $(CONFIG_SCRIPT)"

check: gate-build
	@echo "[GATE] Auditing canonical boot configuration..."
	@bash $(M04_ROOT)/scripts/verify_boot_contract.sh $(CONFIG_SCRIPT)

clean:
	@rm -rf $(BUILD_DIR)
