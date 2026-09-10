M04_ROOT := $(abspath ..)
BUILD_DIR := $(CURDIR)/build
# Opaque reviewer-authored starter MANIFEST (data-only, deliberately
# non-canonical). Learner workflows must never own this fixture.
FIXTURE := $(CURDIR)/fixtures/starter_manifest.conf
# Learner submission: the data-only launch manifest. This is the single
# source of truth for the candidate's machine/CPU/RAM/SMP/display/bootargs;
# the trusted runner derives the executed QEMU argv from it.
CANDIDATE := $(BUILD_DIR)/candidate_boot_manifest.conf
CANDIDATE_LOG := $(BUILD_DIR)/candidate_boot.log
CANDIDATE_ARGV := $(BUILD_DIR)/candidate_boot.argv

.PHONY: all provision capture check clean

all: provision

# Stage the opaque starter manifest. It is NOT canonical: diagnose it against
# the module contract and author the canonical candidate yourself.
provision:
	@mkdir -p $(BUILD_DIR)
	@if [ ! -f "$(CANDIDATE)" ]; then \
		cp $(FIXTURE) $(CANDIDATE); \
		echo "[GATE] Provisioned starter manifest as $(CANDIDATE)"; \
		echo "[GATE] Author the canonical manifest, then run: make capture && make check"; \
	else \
		echo "[GATE] Candidate already exists at $(CANDIDATE) (not overwritten)."; \
	fi

# Capture fresh runtime evidence for YOUR manifest. The trusted runner parses
# the manifest, normalizes it into a real qemu-system-arm argv, records that
# argv as provenance, and executes EXACTLY that configuration.
capture:
	@if [ ! -f "$(CANDIDATE)" ]; then echo "[GATE] No candidate. Run: make provision"; exit 1; fi
	@TIMEOUT_SEC=60 bash $(M04_ROOT)/scripts/run_candidate_manifest.sh \
		$(CANDIDATE) $(CANDIDATE_LOG) $(CANDIDATE_ARGV)
	@echo "[GATE] Captured fresh runtime log at $(CANDIDATE_LOG)"
	@echo "[GATE] Recorded executed argv provenance at $(CANDIDATE_ARGV)"

# Learner-safe self-check: canonical contract on YOUR manifest plus (when
# captured) executed-argv and guest-evidence binding. This does NOT grade
# hidden answers and does NOT reveal the starter's defect mapping.
check:
	@if [ ! -f "$(CANDIDATE)" ]; then \
		echo "[GATE] Notice: $(CANDIDATE) not yet provisioned. Run: make provision"; \
	else \
		bash $(M04_ROOT)/scripts/verify_m04_candidate.sh $(CANDIDATE) $(CANDIDATE_ARGV) $(CANDIDATE_LOG); \
	fi

clean:
	@rm -rf $(BUILD_DIR)
