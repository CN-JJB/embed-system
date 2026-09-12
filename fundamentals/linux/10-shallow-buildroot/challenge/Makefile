M06_ROOT := $(abspath ..)
BUILD_DIR := $(CURDIR)/build
# Opaque reviewer-authored starter fragment (well formed, deliberately
# non-canonical).  Learner workflows must never own this fixture.
FIXTURE := $(CURDIR)/fixtures/starter.conf
CANDIDATE := $(BUILD_DIR)/candidate.conf
OVERLAY := $(M06_ROOT)/fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay

.PHONY: all provision check audit clean

all: provision

provision:
	@mkdir -p $(BUILD_DIR)
	@if [ ! -f "$(CANDIDATE)" ]; then \
		cp $(FIXTURE) $(CANDIDATE); \
		echo "[CHALLENGE] Provisioned opaque starter fragment as $(CANDIDATE)"; \
		echo "[CHALLENGE] Diagnose the target-description defect, repair it, then run: make check"; \
	else \
		echo "[CHALLENGE] Candidate already exists at $(CANDIDATE) (not overwritten)."; \
	fi

# Learner-safe self-check: format and internal consistency only.
check:
	@if [ ! -f "$(CANDIDATE)" ]; then \
		echo "[CHALLENGE] Notice: $(CANDIDATE) not yet provisioned. Run: make provision"; \
	else \
		bash $(M06_ROOT)/scripts/verify_m06_candidate.sh $(CANDIDATE); \
	fi

# Optional: audit an output tree you actually built from your fragment.
audit:
	@if [ -z "$(OUTPUT)" ]; then echo "usage: make audit OUTPUT=<buildroot output dir>"; exit 1; fi
	@python3 $(M06_ROOT)/scripts/audit_output_tree.py --output $(OUTPUT) --overlay $(OVERLAY)

clean:
	@rm -rf $(BUILD_DIR) 2>/dev/null || true
