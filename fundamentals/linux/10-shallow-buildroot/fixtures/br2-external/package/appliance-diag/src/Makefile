CC ?= cc
BUILD_ID ?= 1.0
CFLAGS ?= -O2 -Wall

appliance-diag: appliance-diag.c
	$(CC) $(CFLAGS) -DAPPLIANCE_DIAG_BUILD_ID=\"$(BUILD_ID)\" -o $@ $<

clean:
	rm -f appliance-diag

.PHONY: clean
