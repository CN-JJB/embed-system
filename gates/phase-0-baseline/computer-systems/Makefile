CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic

.PHONY: all clean
all: call_trace locality_bench

call_trace: starter/call_trace.c
	$(CC) $(CFLAGS) -fno-omit-frame-pointer $< -o $@
locality_bench: starter/locality_bench.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f call_trace locality_bench
