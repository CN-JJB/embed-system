CROSS_COMPILE ?= arm-none-linux-gnueabihf-

ifneq ($(MAKECMDGOALS),clean)
  ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
    $(error Cross-compiler '$(CROSS_COMPILE)gcc' not found in PATH. Pass: make CROSS_COMPILE=arm-linux-gnueabihf-)
  endif
endif

FIXTURES_DIR := fixtures

.PHONY: all clean provisioned

# Assessment fixtures are pre-provisioned opaque artifacts committed with the
# module. Learner workflows never generate fixtures themselves.
all: provisioned

provisioned:
	@for f in $(FIXTURES_DIR)/candidate_alpha $(FIXTURES_DIR)/candidate_beta $(FIXTURES_DIR)/candidate_gamma; do \
		test -f $$f || { echo "ERROR: Assessment fixture $$f is not provisioned in the repository."; exit 1; }; \
	done

clean:
	@echo "Gate assessment fixtures are version-controlled; nothing to clean."
