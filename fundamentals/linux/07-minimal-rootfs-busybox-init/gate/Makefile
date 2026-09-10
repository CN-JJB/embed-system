CROSS_COMPILE ?= arm-none-linux-gnueabihf-
M03_ROOT := $(abspath ..)

# Learner-visible assignment input (small, tracked, opaque): the verified
# real BusyBox base comes from BUSYBOX_STAGING, and the assigned candidate
# state is applied from fixtures/candidate.layer by a generic applicator.
# The expanded BusyBox binary + applet forest are never tracked in Git.
LAYER := $(CURDIR)/fixtures/candidate.layer
# Learner working copy. Repair defects here; never edit fixtures/ in place.
CANDIDATE := $(CURDIR)/build/candidate_rootfs
CANDIDATE_ARCHIVE := $(CURDIR)/build/candidate.cpio.gz

.PHONY: all provision package check clean

all: provision

# Provision the assigned candidate from verified local staging plus the
# small opaque assignment input (never overwrites an in-progress repair). Requires
# BUSYBOX_STAGING (default /tmp/rootfs-busybox-staging) from:
#   CROSS_COMPILE=<prefix> bash ../scripts/build_real_busybox.sh
# The mkdir scaffolds the standard FHS skeleton because git cannot store
# empty mount-point directories; it is generic Lab 3.1 scaffolding, never
# a scored fix.
provision:
	@mkdir -p $(CURDIR)/build
	@if [ ! -d "$(CANDIDATE)" ]; then \
		BUSYBOX_STAGING="$${BUSYBOX_STAGING:-/tmp/rootfs-busybox-staging}" bash $(M03_ROOT)/scripts/provision_gate_candidate.sh $(CANDIDATE); \
		chmod -R u+rwX $(CANDIDATE); \
		mkdir -p $(CANDIDATE)/bin $(CANDIDATE)/sbin $(CANDIDATE)/etc/init.d $(CANDIDATE)/dev $(CANDIDATE)/proc $(CANDIDATE)/sys $(CANDIDATE)/tmp $(CANDIDATE)/run $(CANDIDATE)/mnt $(CANDIDATE)/root; \
		echo "[GATE] Provisioned defective candidate tree at $(CANDIDATE)"; \
		echo "[GATE] Diagnose, repair, then run: make package && make check"; \
		echo "[GATE] Runtime grading boots YOUR packaged candidate.cpio.gz: make package is required."; \
	else \
		echo "[GATE] Candidate already exists at $(CANDIDATE) (not overwritten)."; \
	fi

# Package the learner's repaired candidate (proves the packaging step).
package:
	@bash $(M03_ROOT)/scripts/package_initramfs.sh $(CANDIDATE) $(CANDIDATE_ARCHIVE)

# Learner-safe self-check: generic structure contract plus real-BusyBox
# artifact identity of YOUR tree. This does NOT grade hidden scored answers,
# does NOT reveal the defect mapping, and does NOT call reviewer assets.
check:
	@if [ ! -d "$(CANDIDATE)" ]; then \
		echo "[GATE] Notice: $(CANDIDATE) not yet provisioned. Run: make provision"; \
	else \
		bash $(M03_ROOT)/scripts/verify_rootfs_structure.sh $(CANDIDATE); \
		bash $(M03_ROOT)/scripts/validate_real_busybox.sh $(CANDIDATE); \
		if [ -f "$(CANDIDATE_ARCHIVE)" ]; then \
			bash $(M03_ROOT)/scripts/validate_real_busybox.sh $(CANDIDATE_ARCHIVE) $(CANDIDATE); \
			echo "[GATE] Packaged archive present at $(CANDIDATE_ARCHIVE) (final grading boots it)."; \
		else \
			echo "[GATE] Notice: $(CANDIDATE_ARCHIVE) not yet packaged. Run: make package"; \
		fi \
	fi

clean:
	@rm -rf $(CURDIR)/build
