# Fault F01: Makefile defaults to host CC accidentally unless CROSS_COMPILE is enforced
CROSS_COMPILE ?= arm-none-linux-gnueabihf-
ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
  ifneq ($(shell which arm-linux-gnueabihf-gcc 2>/dev/null),)
    CROSS_COMPILE := arm-linux-gnueabihf-
  endif
endif

# The buggy default simulates a build script that hardcodes host CC
FAULT_CC := gcc
FIXED_CC := $(CROSS_COMPILE)gcc

CFLAGS ?= -Wall -Wextra -O2

.PHONY: all clean build-fault build-fixed test-fault

all: build-fault

# Buggy build: produces host binary
build-fault: app_src.c
	$(FAULT_CC) $(CFLAGS) $< -o app_faulty

# Corrected build: produces ARM target binary
build-fixed: app_src.c
	$(FIXED_CC) $(CFLAGS) $< -o app_fixed

clean:
	rm -f app_faulty app_fixed
