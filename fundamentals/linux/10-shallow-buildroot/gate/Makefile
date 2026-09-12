M06_ROOT := $(abspath ..)
BUILD_DIR := $(CURDIR)/build
# Opaque reviewer-authored starter fragment for the AI-Free Module Gate.
FIXTURE := $(CURDIR)/fixtures/starter.conf
CANDIDATE := $(BUILD_DIR)/candidate.conf
OVERLAY := $(M06_ROOT)/fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay

.PHONY: all provision check audit capture clean

all: provision

provision:
	@mkdir -p $(BUILD_DIR)
	@if [ ! -f "$(CANDIDATE)" ]; then \
		cp $(FIXTURE) $(CANDIDATE); \
		echo "[GATE] Provisioned opaque starter fragment as $(CANDIDATE)"; \
		echo "[GATE] Author the canonical fragment, then run: make check"; \
	else \
		echo "[GATE] Candidate already exists at $(CANDIDATE) (not overwritten)."; \
	fi

check:
	@if [ ! -f "$(CANDIDATE)" ]; then \
		echo "[GATE] Notice: $(CANDIDATE) not yet provisioned. Run: make provision"; \
	else \
		bash $(M06_ROOT)/scripts/verify_m06_candidate.sh $(CANDIDATE) \
		    $(if $(OUTPUT),$(OUTPUT),) $(if $(OUTPUT),$(OVERLAY),) \
		    $(BUILD_DIR)/candidate_boot.log $(BUILD_DIR)/candidate_boot.provenance; \
	fi

audit:
	@if [ -z "$(OUTPUT)" ]; then echo "usage: make audit OUTPUT=<buildroot output dir>"; exit 1; fi
	@python3 $(M06_ROOT)/scripts/audit_output_tree.py --output $(OUTPUT) --overlay $(OVERLAY)

capture:
	@if [ -z "$(OUTPUT)" ]; then echo "usage: make capture OUTPUT=<buildroot output dir>"; exit 1; fi
	@bash $(M06_ROOT)/scripts/run_buildroot_appliance.sh $(OUTPUT) \
	    $(BUILD_DIR)/candidate_boot.log $(BUILD_DIR)/candidate_boot.provenance

clean:
	@rm -rf $(BUILD_DIR) 2>/dev/null || true
