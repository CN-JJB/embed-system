.PHONY: all test clean export

all:
	@echo "Phase 1 Final Gate Top-Level Build"
	@echo "Targets:"
	@echo "  make test        - Run all part tests and reviewer validation suites"
	@echo "  make clean       - Clean build artifacts across all parts"
	@echo "  make export      - Run scripts/export-learner.sh to build learner package"

test:
	@echo "=== Testing Part A Reference ==="
	@cd reviewer/part-a && ./validate.sh
	@echo "=== Testing Part B Variants ==="
	@cd reviewer/part-b/b1 && ./test.sh
	@cd reviewer/part-b/b2 && ./test.sh
	@cd reviewer/part-b/b3 && ./test.sh
	@echo "=== Testing Part C Evidence ==="
	@cd reviewer/part-c && ./verify.sh
	@echo "=== Testing Part D Regression ==="
	@cd reviewer/part-d && ./regression.sh
	@echo ">>> ALL FINAL GATE COMPONENT TESTS PASSED <<<"

clean:
	@rm -rf build /tmp/final-gate-learner-*
	@$(MAKE) -C reviewer/part-a/reference clean 2>/dev/null || true
	@$(MAKE) -C part-b/variants/b1 clean 2>/dev/null || true
	@$(MAKE) -C part-b/variants/b2 clean 2>/dev/null || true
	@$(MAKE) -C part-b/variants/b3 clean 2>/dev/null || true
	@$(MAKE) -C part-c clean 2>/dev/null || true
	@$(MAKE) -C part-d clean 2>/dev/null || true
	@$(MAKE) -C reviewer/part-d/reference clean 2>/dev/null || true

export:
	@./scripts/export-learner.sh /tmp/final-gate-learner-b1 b1
