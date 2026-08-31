CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: raw_struct_trap
raw_struct_trap: raw_struct_trap.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f raw_struct_trap raw.bin wire.bin
.PHONY: all clean
