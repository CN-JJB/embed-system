CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all clean
all: process_faults fd_probe
process_faults: process_faults.c
	$(CC) $(CFLAGS) $< -o $@
fd_probe: fd_probe.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f process_faults fd_probe fault.log
