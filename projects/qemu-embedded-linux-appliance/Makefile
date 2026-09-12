# P3-M08 Reproducible QEMU Embedded Linux Appliance -- project Makefile.
# Standalone harness. Heavyweight build/boot never run by default.
SHELL := /bin/bash

PROJ_ROOT := $(abspath .)
PYTHON ?= python3

MANIFEST := $(PROJ_ROOT)/fixtures/sample_manifest.json
RUN := $(PROJ_ROOT)/fixtures/sample_run.json
OVERLAY := $(PROJ_ROOT)/overlay

.PHONY: all manifest check launch audit clean build boot

all: manifest check

# Validate the committed SYNTHETIC sample manifest (lightweight, no build).
manifest:
	@$(PYTHON) $(PROJ_ROOT)/scripts/manifest.py --validate $(MANIFEST)

# Learner-safe static checks: schema, hashes present, argv well-formed,
# sample image audit, fault workspaces. Never grades hidden variants.
check:
	@bash $(PROJ_ROOT)/scripts/verify_project.sh

# Deterministic non-interactive launch/capture (requires real artifacts).
# Fails closed when kernel/initrd/QEMU are absent. Never claims boot success.
launch:
	@bash $(PROJ_ROOT)/scripts/run_appliance.sh --manifest $(MANIFEST) --log $(PROJ_ROOT)/build/appliance.log --run $(PROJ_ROOT)/build/appliance.run.json

# Audit the final image (requires IMAGE=...; fails closed when absent).
audit:
	@if [ -z "$(IMAGE)" ]; then echo "usage: make audit IMAGE=<rootfs.cpio.gz> [STAGED=<output/target>]"; exit 1; fi
	@$(PYTHON) $(PROJ_ROOT)/scripts/audit_final_image.py --image "$(IMAGE)" --overlay $(OVERLAY) $(if $(STAGED),--staged "$(STAGED)",)

clean:
	@rm -rf $(PROJ_ROOT)/build 2>/dev/null || true
	@find $(PROJ_ROOT) -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@find $(PROJ_ROOT) -name "*.pyc" -delete 2>/dev/null || true

# --- heavy, opt-in paths (never part of default / Phase 1-2 checks) ----------

# Opt-in Buildroot image reuse build. Requires BUILDROOT_SRC + OUTPUT.
# Documents SITE_METHOD=local + dirclean vs rebuild rule (F12 precedent):
# a plain `make` never rebuilds a package whose .stamp_target_installed exists;
# for SITE_METHOD=local, `make <pkg>-rebuild` alone re-compiles the stale copy
# inside output/build/ (no re-extraction); use `make <pkg>-dirclean all` to
# force re-extraction from the external SITE and regenerate the image.
build:
	@if [ -z "$(BUILDROOT_SRC)" ]; then echo "usage: make build BUILDROOT_SRC=/path/to/buildroot-2026.05.2 [OUTPUT=build/br-output]"; exit 1; fi
	@bash $(PROJ_ROOT)/scripts/run_appliance.sh --help | head -n 5 || true
	@echo "[NOTE] canonical appliance build reuses the P3-M06 Buildroot pipeline;"
	@echo "       see BUILD_RUN_DEBUG.md section 2 for the exact build commands."
	@echo "[NOTE] for SITE_METHOD=local packages use <pkg>-dirclean, not bare -rebuild (F12)."

# Opt-in boot of an already-built output tree. Requires OUTPUT=<br-output dir>.
boot:
	@if [ -z "$(OUTPUT)" ]; then echo "usage: make boot OUTPUT=<buildroot output dir> [LOG=build/appliance.log]"; exit 1; fi
	@bash $(PROJ_ROOT)/scripts/run_appliance.sh --manifest $(MANIFEST) --log $${LOG:-$(PROJ_ROOT)/build/appliance.log} --run $(PROJ_ROOT)/build/appliance.run.json --output $(OUTPUT)
