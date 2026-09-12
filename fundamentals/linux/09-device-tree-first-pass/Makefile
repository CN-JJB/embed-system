# P3-M05 — Device Tree First Pass
SHELL := /bin/bash

M05_ROOT := $(abspath .)
PYTHON  ?= python3

.PHONY: all check roundtrip dump-dtb semantic structural sysfs \
        gate-provision challenge-provision capture clean

all: gate-provision challenge-provision

# --- learner-safe verification -------------------------------------------------

check: gate-provision challenge-provision
	@bash $(M05_ROOT)/scripts/verify_m05.sh

# Real dtc dtb -> dts -> dtb with a semantic (not byte) equality proof.
roundtrip:
	@bash $(M05_ROOT)/scripts/dtc_roundtrip.sh \
	    $(M05_ROOT)/fixtures/qemu-virt.dtb $(M05_ROOT)/build/roundtrip

# Regenerate the real QEMU device tree blob with recorded provenance.
dump-dtb:
	@bash $(M05_ROOT)/scripts/dump_virt_dtb.sh \
	    $(M05_ROOT)/build/virt.dtb $(M05_ROOT)/build/virt.provenance.json

# The canonical semantic contract, evaluated against the committed real fixture.
semantic:
	@$(PYTHON) $(M05_ROOT)/scripts/validate_dt_semantics.py $(M05_ROOT)/fixtures/qemu-virt.dtb

# Structural / format invariants only.
structural:
	@$(PYTHON) $(M05_ROOT)/scripts/dt_structural_check.py $(M05_ROOT)/fixtures/qemu-virt.dtb

# The predicted /sys/firmware/devicetree/base projection of the console node.
sysfs:
	@$(PYTHON) $(M05_ROOT)/scripts/derive_sysfs_tree.py \
	    $(M05_ROOT)/fixtures/qemu-virt.dtb --path "/pl011@9000000"

# --- assessment workspaces -----------------------------------------------------

gate-provision:
	@$(MAKE) -C gate provision

challenge-provision:
	@$(MAKE) -C challenge provision

# Runtime capture requires the Phase 3 kernel and initramfs.
capture:
	@if [ -z "$(KERNEL)" ] || [ -z "$(INITRD)" ]; then \
		echo "usage: make capture KERNEL=<zImage> INITRD=<rootfs.cpio.gz> [DTB=<blob>]"; \
		exit 1; \
	fi
	@TIMEOUT_SEC=$${TIMEOUT_SEC:-90} bash $(M05_ROOT)/scripts/run_qemu_dtb_boot.sh \
	    $${DTB:-$(M05_ROOT)/fixtures/qemu-virt.dtb} $(KERNEL) $(INITRD) \
	    $(M05_ROOT)/build/boot.log $(M05_ROOT)/build/boot.argv
	@$(PYTHON) $(M05_ROOT)/scripts/verify_runtime_binding.py \
	    $${DTB:-$(M05_ROOT)/fixtures/qemu-virt.dtb} \
	    $(M05_ROOT)/build/boot.argv $(M05_ROOT)/build/boot.log

clean:
	@$(MAKE) -C gate clean
	@$(MAKE) -C challenge clean
	@rm -rf $(M05_ROOT)/build 2>/dev/null || true
