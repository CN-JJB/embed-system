SHELL := /bin/bash
M07_ROOT := $(abspath ..)
BUILD_DIR := $(CURDIR)/build
# Opaque reviewer-authored starter fixture for the AI-Free Module Gate.
FIXTURE := $(CURDIR)/fixtures/starter_combined.json
CANDIDATE := $(BUILD_DIR)/candidate.json

.PHONY: all provision check clean

all: provision

provision:
	@mkdir -p $(BUILD_DIR)
	@if [ ! -f "$(CANDIDATE)" ]; then \
		cp $(FIXTURE) $(CANDIDATE); \
		echo "[GATE] Provisioned opaque starter fixture as $(CANDIDATE)"; \
		echo "[GATE] Author the canonical candidate, then run: make check"; \
	else \
		echo "[GATE] Candidate already exists at $(CANDIDATE) (not overwritten)."; \
	fi

check:
	@if [ ! -f "$(CANDIDATE)" ]; then \
		echo "[GATE] Notice: $(CANDIDATE) not yet provisioned. Run: make provision"; \
	else \
		bash $(M07_ROOT)/scripts/verify_m07_candidate.sh $(CANDIDATE); \
	fi

clean:
	@rm -rf $(BUILD_DIR) 2>/dev/null || true
