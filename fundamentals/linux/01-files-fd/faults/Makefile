CC ?= gcc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Wconversion -g3 -O0
all: fd-faults
fd-faults: faults.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f fd-faults input.bin out.bin
.PHONY: all clean
