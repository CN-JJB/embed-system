M04_ROOT := $(abspath ..)
OUTPUT_DIR := $(CURDIR)/build
FIXTURE := $(CURDIR)/fixtures/broken_launch.sh
CANDIDATE := $(OUTPUT_DIR)/candidate_launch.sh
CANDIDATE_LOG := $(OUTPUT_DIR)/candidate_boot.log

.PHONY: all provision capture check clean

all: provision

# Stage the opaque broken launch configuration for diagnosis.
provision:
	@mkdir -p $(OUTPUT_DIR)
	@if [ ! -f "$(CANDIDATE)" ]; then \
		cp $(FIXTURE) $(CANDIDATE); \
		echo "[CHALLENGE] Provisioned broken config as $(CANDIDATE)"; \
		echo "[CHALLENGE] Diagnose the silence, repair, then run: make capture && make check"; \
	else \
		echo "[CHALLENGE] Candidate already exists at $(CANDIDATE) (not overwritten)."; \
	fi

# Capture fresh QEMU evidence for YOUR candidate BOOTARGS.
capture:
	@if [ ! -f "$(CANDIDATE)" ]; then echo "[CHALLENGE] No candidate. Run: make provision"; exit 1; fi
	@BOOTARGS=$$(grep -E '^[[:space:]]*BOOTARGS=' $(CANDIDATE) | tail -n 1 | sed -E 's/^[^=]*=["'"'"']?//; s/["'"'"']$$//'); \
	if [ -z "$$BOOTARGS" ]; then echo "[CHALLENGE] Cannot parse BOOTARGS from $(CANDIDATE)"; exit 1; fi; \
	TIMEOUT_SEC=40 bash $(M04_ROOT)/scripts/run_qemu_diagnostic.sh "$$BOOTARGS" $(CANDIDATE_LOG); \
	echo "[CHALLENGE] Captured fresh runtime log at $(CANDIDATE_LOG)"

# Learner-safe self-check: contract audit on YOUR candidate only.
check:
	@if [ ! -f "$(CANDIDATE)" ]; then \
		echo "[CHALLENGE] Notice: $(CANDIDATE) not yet provisioned. Run: make provision"; \
	else \
		bash $(M04_ROOT)/scripts/verify_boot_contract.sh $(CANDIDATE); \
		if [ -f "$(CANDIDATE_LOG)" ]; then \
			echo "[CHALLENGE] Runtime log present at $(CANDIDATE_LOG)."; \
		else \
			echo "[CHALLENGE] Notice: $(CANDIDATE_LOG) not yet captured. Run: make capture"; \
		fi \
	fi

clean:
	@rm -rf $(OUTPUT_DIR)
