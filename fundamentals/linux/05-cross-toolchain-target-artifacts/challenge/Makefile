CROSS_COMPILE ?= arm-none-linux-gnueabihf-

ifneq ($(MAKECMDGOALS),clean)
  ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
    $(error Cross-compiler '$(CROSS_COMPILE)gcc' not found in PATH. Pass: make CROSS_COMPILE=arm-linux-gnueabihf-)
  endif
endif

HOST_CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2

FIXTURES_DIR := fixtures

.PHONY: all clean provisioned

all: audit_tool provisioned

audit_tool: audit_tool.c
	$(HOST_CC) $(CFLAGS) $< -o $@

# Assessment fixtures are pre-provisioned opaque artifacts committed with the
# module. Learner workflows never generate fixtures themselves.
provisioned:
	@for f in $(FIXTURES_DIR)/unknown_1 $(FIXTURES_DIR)/unknown_2 $(FIXTURES_DIR)/unknown_3; do \
		test -f $$f || { echo "ERROR: Assessment fixture $$f is not provisioned in the repository."; exit 1; }; \
	done

clean:
	rm -f audit_tool
