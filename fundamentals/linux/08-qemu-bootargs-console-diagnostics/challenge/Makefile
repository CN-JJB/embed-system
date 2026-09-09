M04_ROOT := $(abspath ..)
OUTPUT_DIR := $(CURDIR)/build

.PHONY: all challenge-build check clean

all: challenge-build

challenge-build:
	@mkdir -p $(OUTPUT_DIR)
	@echo "[CHALLENGE] Challenge environment ready in $(OUTPUT_DIR)"

check: challenge-build
	@echo "[CHALLENGE] Verifying challenge artifacts..."
	@if [ -f "$(OUTPUT_DIR)/challenge_boot.log" ]; then \
		bash $(M04_ROOT)/scripts/audit_boot_milestones.sh "$(OUTPUT_DIR)/challenge_boot.log"; \
	else \
		echo "[CHALLENGE] Notice: $(OUTPUT_DIR)/challenge_boot.log not yet generated."; \
		echo "[CHALLENGE] Use earlycon and corrected console arguments to capture a successful boot log."; \
	fi

clean:
	@rm -rf $(OUTPUT_DIR)
