CROSS_COMPILE ?= arm-none-linux-gnueabihf-
M03_ROOT := $(abspath ..)

# Opaque pre-provisioned defective tree (reviewer-authored, rotated).
FIXTURE := $(CURDIR)/fixtures/defective_rootfs
# Learner working copy. Repair defects here; never edit fixtures/ in place.
CANDIDATE := $(CURDIR)/build/candidate_rootfs
CANDIDATE_ARCHIVE := $(CURDIR)/build/candidate.cpio.gz

.PHONY: all provision package check clean

all: provision

# Copy the opaque defective tree into the learner workspace (never
# overwrites an in-progress repair). The mkdir scaffolds the standard FHS
# skeleton because git cannot store empty mount-point directories; it is
# generic Lab 3.1 scaffolding, never a scored fix.
provision:
	@mkdir -p $(CURDIR)/build
	@if [ ! -d "$(CANDIDATE)" ]; then \
		cp -a $(FIXTURE) $(CANDIDATE); \
		chmod -R u+rwX $(CANDIDATE); \
		mkdir -p $(CANDIDATE)/bin $(CANDIDATE)/sbin $(CANDIDATE)/etc/init.d $(CANDIDATE)/dev $(CANDIDATE)/proc $(CANDIDATE)/sys $(CANDIDATE)/tmp $(CANDIDATE)/run $(CANDIDATE)/mnt $(CANDIDATE)/root; \
		echo "[CHALLENGE] Provisioned opaque candidate tree at $(CANDIDATE)"; \
		echo "[CHALLENGE] Diagnose, repair, then run: make package && make check"; \
	else \
		echo "[CHALLENGE] Candidate already exists at $(CANDIDATE) (not overwritten)."; \
	fi

# Package the learner's repaired candidate (proves the packaging step).
package:
	@bash $(M03_ROOT)/scripts/package_initramfs.sh $(CANDIDATE) $(CANDIDATE_ARCHIVE)

# Learner-safe self-check: generic structure contract only. This does NOT
# grade hidden scored answers and does NOT reveal the defect mapping.
check:
	@if [ ! -d "$(CANDIDATE)" ]; then \
		echo "[CHALLENGE] Notice: $(CANDIDATE) not yet provisioned. Run: make provision"; \
	else \
		bash $(M03_ROOT)/scripts/verify_rootfs_structure.sh $(CANDIDATE); \
	fi

clean:
	@rm -rf $(CURDIR)/build
