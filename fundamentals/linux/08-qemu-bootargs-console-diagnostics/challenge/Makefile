M04_ROOT := $(abspath ..)
OUTPUT_DIR := $(CURDIR)/build
# Opaque reviewer-authored challenge manifest (data-only, deliberately
# broken: the symptom is a silent terminal).
FIXTURE := $(CURDIR)/fixtures/broken_manifest.conf
CANDIDATE := $(OUTPUT_DIR)/candidate_launch_manifest.conf
CANDIDATE_LOG := $(OUTPUT_DIR)/candidate_boot.log
CANDIDATE_ARGV := $(OUTPUT_DIR)/candidate_boot.argv

.PHONY: all provision capture check clean

all: provision

# Stage the opaque broken launch manifest for diagnosis.
provision:
	@mkdir -p $(OUTPUT_DIR)
	@if [ ! -f "$(CANDIDATE)" ]; then \
		cp $(FIXTURE) $(CANDIDATE); \
		echo "[CHALLENGE] Provisioned broken manifest as $(CANDIDATE)"; \
		echo "[CHALLENGE] Diagnose the silence, repair, then run: make capture && make check"; \
	else \
		echo "[CHALLENGE] Candidate already exists at $(CANDIDATE) (not overwritten)."; \
	fi

# Capture fresh QEMU evidence for YOUR manifest (executed argv is derived
# from the manifest and recorded as provenance).
capture:
	@if [ ! -f "$(CANDIDATE)" ]; then echo "[CHALLENGE] No candidate. Run: make provision"; exit 1; fi
	@TIMEOUT_SEC=60 bash $(M04_ROOT)/scripts/run_candidate_manifest.sh \
		$(CANDIDATE) $(CANDIDATE_LOG) $(CANDIDATE_ARGV)
	@echo "[CHALLENGE] Captured fresh runtime log at $(CANDIDATE_LOG)"

# Learner-safe self-check: contract audit on YOUR manifest only.
check:
	@if [ ! -f "$(CANDIDATE)" ]; then \
		echo "[CHALLENGE] Notice: $(CANDIDATE) not yet provisioned. Run: make provision"; \
	else \
		bash $(M04_ROOT)/scripts/verify_m04_candidate.sh $(CANDIDATE) $(CANDIDATE_ARGV) $(CANDIDATE_LOG); \
	fi

clean:
	@rm -rf $(OUTPUT_DIR)
