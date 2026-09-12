M05_ROOT := $(abspath ..)
BUILD_DIR := $(CURDIR)/build
# Opaque reviewer-authored starter artifact for the AI-Free Module Gate.
FIXTURE := $(CURDIR)/fixtures/starter_virt.dtb
# Learner submission: the repaired device tree blob.
CANDIDATE := $(BUILD_DIR)/candidate.dtb
CANDIDATE_LOG := $(BUILD_DIR)/candidate_boot.log
CANDIDATE_ARGV := $(BUILD_DIR)/candidate_boot.argv
# Optional identity manifest the learner authors to declare what was booted.
MANIFEST := $(BUILD_DIR)/candidate_manifest.json

.PHONY: all provision capture check clean

all: provision

provision:
	@mkdir -p $(BUILD_DIR)
	@if [ ! -f "$(CANDIDATE)" ]; then \
		cp $(FIXTURE) $(CANDIDATE); \
		echo "[GATE] Provisioned opaque starter DTB as $(CANDIDATE)"; \
		echo "[GATE] Author the canonical candidate, then run: make check"; \
	else \
		echo "[GATE] Candidate already exists at $(CANDIDATE) (not overwritten)."; \
	fi

# Boot YOUR candidate and capture real guest device-tree evidence.
capture:
	@if [ ! -f "$(CANDIDATE)" ]; then echo "[GATE] No candidate. Run: make provision"; exit 1; fi
	@if [ -z "$(KERNEL)" ] || [ -z "$(INITRD)" ]; then \
		echo "[GATE] Set KERNEL=<zImage> INITRD=<rootfs.cpio.gz> to capture runtime evidence."; \
		exit 1; \
	fi
	@TIMEOUT_SEC=$${TIMEOUT_SEC:-90} bash $(M05_ROOT)/scripts/run_qemu_dtb_boot.sh \
		$(CANDIDATE) $(KERNEL) $(INITRD) $(CANDIDATE_LOG) $(CANDIDATE_ARGV)
	@echo "[GATE] Captured fresh runtime log at $(CANDIDATE_LOG)"
	@echo "[GATE] Recorded executed argv provenance at $(CANDIDATE_ARGV)"

# Learner-safe self-check: format/structure (and, when captured, evidence
# binding) of YOUR candidate.  This does not grade the hidden semantic defect.
check:
	@if [ ! -f "$(CANDIDATE)" ]; then \
		echo "[GATE] Notice: $(CANDIDATE) not yet provisioned. Run: make provision"; \
	else \
		bash $(M05_ROOT)/scripts/verify_m05_candidate.sh $(CANDIDATE) $(CANDIDATE_ARGV) $(CANDIDATE_LOG); \
	fi

clean:
	@rm -rf $(BUILD_DIR) 2>/dev/null || true
