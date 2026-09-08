CROSS_COMPILE ?= arm-none-linux-gnueabihf-
ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
  ifneq ($(shell which arm-linux-gnueabihf-gcc 2>/dev/null),)
    CROSS_COMPILE := arm-linux-gnueabihf-
  endif
endif

CC := $(CROSS_COMPILE)gcc
HOST_CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2

FIXTURES_DIR := fixtures

.PHONY: all clean fixtures

all: audit_tool fixtures

audit_tool: audit_tool.c
	$(HOST_CC) $(CFLAGS) $< -o $@

fixtures:
	mkdir -p $(FIXTURES_DIR)
	# Unknown 1: host binary
	echo 'int main(){return 10;}' | $(HOST_CC) -x c - -O2 -o $(FIXTURES_DIR)/unknown_1
	# Unknown 2: dynamic ARM binary
	echo 'int main(){return 20;}' | $(CC) -x c - -O2 -o $(FIXTURES_DIR)/unknown_2
	# Unknown 3: static ARM binary
	echo 'int main(){return 30;}' | $(CC) -x c - -static -O2 -o $(FIXTURES_DIR)/unknown_3

clean:
	rm -f audit_tool
	rm -rf $(FIXTURES_DIR)
