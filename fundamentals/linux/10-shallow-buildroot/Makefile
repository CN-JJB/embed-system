# P3-M06 — Shallow Buildroot
SHELL := /bin/bash

M06_ROOT := $(abspath .)
PYTHON   ?= python3
DEFCONFIG := $(M06_ROOT)/fixtures/br2-external/configs/qemu_virt_a7_defconfig
SYMBOLS   := $(M06_ROOT)/fixtures/buildroot-symbols.json
OVERLAY   := $(M06_ROOT)/fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay
SAMPLE    := $(M06_ROOT)/fixtures/output-tree-sample

.PHONY: all check config-check symbols audit-sample stale-sample clean-sample \
        gate-provision challenge-provision build boot clean

all: gate-provision challenge-provision

# --- learner-safe verification -------------------------------------------------

check: gate-provision challenge-provision
	@bash $(M06_ROOT)/scripts/verify_m06.sh

config-check:
	@$(PYTHON) $(M06_ROOT)/scripts/verify_br_config.py $(DEFCONFIG)

symbols:
	@$(PYTHON) $(M06_ROOT)/scripts/verify_br_config.py $(DEFCONFIG) \
	    --symbol-table $(SYMBOLS) --quiet

audit-sample:
	@$(PYTHON) $(M06_ROOT)/scripts/audit_output_tree.py \
	    --output $(SAMPLE) --overlay $(OVERLAY)

stale-sample:
	@$(PYTHON) $(M06_ROOT)/scripts/make_sample_output_tree.py \
	    --out $(M06_ROOT)/build/stale-sample --mode stale
	@$(PYTHON) $(M06_ROOT)/scripts/audit_output_tree.py \
	    --output $(M06_ROOT)/build/stale-sample --overlay $(OVERLAY) || \
	    echo "[EXPECTED] the stale image was rejected, as designed"

clean-sample:
	@$(PYTHON) $(M06_ROOT)/scripts/make_sample_output_tree.py \
	    --out $(SAMPLE) --mode healthy

# --- assessment workspaces -----------------------------------------------------

gate-provision:
	@$(MAKE) -C gate provision

challenge-provision:
	@$(MAKE) -C challenge provision

# --- heavy, opt-in build / boot ------------------------------------------------

build:
	@if [ -z "$(BUILDROOT_SRC)" ]; then \
		echo "usage: make build BUILDROOT_SRC=/path/to/buildroot-2026.05.2 [OUTPUT=build/br-output]"; \
		exit 1; \
	fi
	@bash $(M06_ROOT)/scripts/build_appliance.sh $(BUILDROOT_SRC) $${OUTPUT:-$(M06_ROOT)/build/br-output}

boot:
	@if [ -z "$(OUTPUT)" ]; then echo "usage: make boot OUTPUT=<buildroot output dir>"; exit 1; fi
	@bash $(M06_ROOT)/scripts/run_buildroot_appliance.sh $(OUTPUT) \
	    $(M06_ROOT)/build/appliance.log $(M06_ROOT)/build/appliance.provenance
	@$(PYTHON) $(M06_ROOT)/scripts/verify_appliance_runtime.py \
	    $(OUTPUT)/images/rootfs.cpio.gz \
	    $(M06_ROOT)/build/appliance.provenance $(M06_ROOT)/build/appliance.log \
	    --overlay $(OVERLAY)

clean:
	@$(MAKE) -C gate clean
	@$(MAKE) -C challenge clean
	@rm -rf $(M06_ROOT)/build 2>/dev/null || true
