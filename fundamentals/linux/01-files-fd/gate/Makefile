CC ?= gcc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Wconversion -g3 -O0
all: log_copy
log_copy: log_copy.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f log_copy input.bin out.bin
.PHONY: all clean
