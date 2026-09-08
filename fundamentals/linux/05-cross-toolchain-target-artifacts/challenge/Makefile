CROSS_COMPILE ?= arm-none-linux-gnueabihf-

ifneq ($(MAKECMDGOALS),clean)
  ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
    $(error Cross-compiler '$(CROSS_COMPILE)gcc' not found in PATH. Pass: make CROSS_COMPILE=arm-linux-gnueabihf-)
  endif
endif

HOST_CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2

FIXTURES_DIR := fixtures

.PHONY: all clean fixtures

all: audit_tool fixtures

audit_tool: audit_tool.c
	$(HOST_CC) $(CFLAGS) $< -o $@

fixtures:
	bash ../reviewer/scripts/generate_m01_challenge_fixtures.sh $(FIXTURES_DIR) $(CROSS_COMPILE)

clean:
	rm -f audit_tool
	rm -rf $(FIXTURES_DIR)
