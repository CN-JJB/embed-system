SHELL := /bin/bash
M07_ROOT := $(abspath ..)
BUILD_DIR := $(CURDIR)/build
# Opaque reviewer-authored starter fixture (well formed, deliberately
# non-canonical).  Learner workflows must never own this fixture.
FIXTURE := $(CURDIR)/fixtures/starter_descriptor.json
CANDIDATE := $(BUILD_DIR)/candidate.json

.PHONY: all provision check clean

all: provision

provision:
	@mkdir -p $(BUILD_DIR)
	@if [ ! -f "$(CANDIDATE)" ]; then \
		cp $(FIXTURE) $(CANDIDATE); \
		echo "[CHALLENGE] Provisioned opaque starter fixture as $(CANDIDATE)"; \
		echo "[CHALLENGE] Diagnose the encoding defect, repair it, then run: make check"; \
	else \
		echo "[CHALLENGE] Candidate already exists at $(CANDIDATE) (not overwritten)."; \
	fi

# Learner-safe self-check: format and internal consistency only.
check:
	@if [ ! -f "$(CANDIDATE)" ]; then \
		echo "[CHALLENGE] Notice: $(CANDIDATE) not yet provisioned. Run: make provision"; \
	else \
		bash $(M07_ROOT)/scripts/verify_m07_candidate.sh $(CANDIDATE); \
	fi

clean:
	@rm -rf $(BUILD_DIR) 2>/dev/null || true
