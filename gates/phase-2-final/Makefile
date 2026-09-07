# ==============================================================================
# Makefile: Phase 2 Final Gate Assessment Package
# Target: STM32F103C8T6 (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM)
# ==============================================================================

SHELL := /bin/bash

PARTS := part-a part-b part-c part-d

.PHONY: all clean check test-negative check-reviewer $(PARTS)

all: $(PARTS)

part-a:
	@echo "=== Building Part A Fixture ==="
	$(MAKE) -C part-a all

part-b:
	@echo "=== Building Part B Fixture ==="
	$(MAKE) -C part-b all

part-c:
	@echo "=== Building Part C Fixture ==="
	$(MAKE) -C part-c all

part-d:
	@echo "=== Building Part D Fixture ==="
	$(MAKE) -C part-d all

clean:
	@echo "=== Cleaning Phase 2 Final Gate Build Artifacts ==="
	@for part in $(PARTS); do \
		if [ -d "$$part" ]; then \
			$(MAKE) -C "$$part" clean || exit 1; \
		fi; \
	done
	@if [ -d "reviewer" ] && [ -f "reviewer/Makefile" ]; then \
		$(MAKE) -C reviewer clean || true; \
	fi

check: all
	@echo "=== Running Phase 2 Gate Static Package Verification ==="
	@bash scripts/verify_gate.sh

test-negative:
	@echo "=== Running Phase 2 Gate Validator Negative Controls ==="
	@bash scripts/test_negative_controls.sh

check-reviewer:
	@echo "=== Running Phase 2 Reviewer Reference & Oracle Checks ==="
	@bash reviewer/verify_reviewer.sh
