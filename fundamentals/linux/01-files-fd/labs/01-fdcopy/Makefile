CC ?= gcc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Wconversion -g3 -O0
all: fdcopy
fdcopy: fdcopy.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f fdcopy input.bin output.bin
.PHONY: all clean
