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
	@for f in $(FIXTURES_DIR)/candidate_effective.config $(FIXTURES_DIR)/candidate_vmlinux $(FIXTURES_DIR)/candidate_System.map; do \
		test -f $$f || { echo "ERROR: Assessment fixture $$f is not provisioned in the repository."; exit 1; }; \
	done

clean:
	@echo "Challenge assessment fixtures are version-controlled; nothing to clean."
