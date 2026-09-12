# P3-M08 appliance-diag target build (cross-compile via CROSS_COMPILE).
# NOTE: `CC ?=` would be a no-op because GNU make predefines CC=cc, silently
# ignoring CROSS_COMPILE and building a HOST binary. A plain `=` (recursive)
# is required so CROSS_COMPILE actually selects the target compiler.
CC = $(CROSS_COMPILE)gcc
CFLAGS ?= -O2 -Wall -Wextra

appliance-diag: appliance-diag.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f appliance-diag

.PHONY: clean
