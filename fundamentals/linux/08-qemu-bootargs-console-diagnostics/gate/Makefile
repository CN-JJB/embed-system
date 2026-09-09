M04_ROOT := $(abspath ..)
BUILD_DIR := $(CURDIR)/build
FIXTURE := $(CURDIR)/fixtures/starter_launch.sh
CANDIDATE := $(BUILD_DIR)/candidate_boot_config.sh
CANDIDATE_LOG := $(BUILD_DIR)/candidate_boot.log

.PHONY: all provision capture check clean

all: provision

# Stage the opaque starter configuration. It is NOT canonical: diagnose it
# against the module contract and author the canonical candidate yourself.
provision:
	@mkdir -p $(BUILD_DIR)
	@if [ ! -f "$(CANDIDATE)" ]; then \
		cp $(FIXTURE) $(CANDIDATE); \
		echo "[GATE] Provisioned starter as $(CANDIDATE)"; \
		echo "[GATE] Author the canonical config, then run: make capture && make check"; \
	else \
		echo "[GATE] Candidate already exists at $(CANDIDATE) (not overwritten)."; \
	fi

# Capture fresh QEMU runtime evidence for YOUR candidate BOOTARGS.
capture:
	@if [ ! -f "$(CANDIDATE)" ]; then echo "[GATE] No candidate. Run: make provision"; exit 1; fi
	@BOOTARGS=$$(grep -E '^[[:space:]]*BOOTARGS=' $(CANDIDATE) | tail -n 1 | sed -E 's/^[^=]*=["'"'"']?//; s/["'"'"']$$//'); \
	if [ -z "$$BOOTARGS" ]; then echo "[GATE] Cannot parse BOOTARGS from $(CANDIDATE)"; exit 1; fi; \
	TIMEOUT_SEC=40 bash $(M04_ROOT)/scripts/run_qemu_diagnostic.sh "$$BOOTARGS" $(CANDIDATE_LOG); \
	echo "[GATE] Captured fresh runtime log at $(CANDIDATE_LOG)"

# Learner-safe self-check: contract audit on YOUR candidate only (plus a
# notice about runtime evidence). This does NOT grade hidden answers.
check:
	@if [ ! -f "$(CANDIDATE)" ]; then \
		echo "[GATE] Notice: $(CANDIDATE) not yet provisioned. Run: make provision"; \
	else \
		bash $(M04_ROOT)/scripts/verify_boot_contract.sh $(CANDIDATE); \
		if [ -f "$(CANDIDATE_LOG)" ]; then \
			echo "[GATE] Runtime log present at $(CANDIDATE_LOG) (final grading binds it to your BOOTARGS)."; \
		else \
			echo "[GATE] Notice: $(CANDIDATE_LOG) not yet captured. Run: make capture"; \
		fi \
	fi

clean:
	@rm -rf $(BUILD_DIR)
