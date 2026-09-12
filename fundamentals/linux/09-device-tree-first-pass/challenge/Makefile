M05_ROOT := $(abspath ..)
BUILD_DIR := $(CURDIR)/build
# Opaque reviewer-authored starter artifact: a well-formed QEMU `virt` device
# tree that is deliberately not semantically canonical.  Learner workflows must
# never own this fixture.
FIXTURE := $(CURDIR)/fixtures/starter_virt.dtb
# Learner submission: the repaired device tree blob.
CANDIDATE := $(BUILD_DIR)/candidate.dtb
CANDIDATE_LOG := $(BUILD_DIR)/candidate_boot.log
CANDIDATE_ARGV := $(BUILD_DIR)/candidate_boot.argv

.PHONY: all provision capture check clean

all: provision

# Stage the opaque starter artifact.  It is NOT canonical: decompile it,
# compare it against the real QEMU virt hardware model you captured in Lab 5.1,
# then author the repaired candidate yourself.
provision:
	@mkdir -p $(BUILD_DIR)
	@if [ ! -f "$(CANDIDATE)" ]; then \
		cp $(FIXTURE) $(CANDIDATE); \
		echo "[CHALLENGE] Provisioned opaque starter DTB as $(CANDIDATE)"; \
		echo "[CHALLENGE] Diagnose the description defect, repair it, then run: make check"; \
	else \
		echo "[CHALLENGE] Candidate already exists at $(CANDIDATE) (not overwritten)."; \
	fi

# Optional: boot YOUR repaired tree and capture real guest evidence.
# Requires the Phase 3 kernel zImage and the BusyBox initramfs.
capture:
	@if [ ! -f "$(CANDIDATE)" ]; then echo "[CHALLENGE] No candidate. Run: make provision"; exit 1; fi
	@if [ -z "$(KERNEL)" ] || [ -z "$(INITRD)" ]; then \
		echo "[CHALLENGE] Set KERNEL=<zImage> INITRD=<rootfs.cpio.gz> to capture runtime evidence."; \
		exit 1; \
	fi
	@TIMEOUT_SEC=$${TIMEOUT_SEC:-90} bash $(M05_ROOT)/scripts/run_qemu_dtb_boot.sh \
		$(CANDIDATE) $(KERNEL) $(INITRD) $(CANDIDATE_LOG) $(CANDIDATE_ARGV)
	@echo "[CHALLENGE] Captured fresh runtime log at $(CANDIDATE_LOG)"

# Learner-safe self-check: format/structure of YOUR candidate only.
check:
	@if [ ! -f "$(CANDIDATE)" ]; then \
		echo "[CHALLENGE] Notice: $(CANDIDATE) not yet provisioned. Run: make provision"; \
	else \
		bash $(M05_ROOT)/scripts/verify_m05_candidate.sh $(CANDIDATE) $(CANDIDATE_ARGV) $(CANDIDATE_LOG); \
	fi

clean:
	@rm -rf $(BUILD_DIR) 2>/dev/null || true
