
CC ?= gcc
CFLAGS ?= -std=c17 -D_POSIX_C_SOURCE=200809L -O0 -g -Wall -Wextra -Wpedantic -Werror
all: eof_hang
eof_hang: eof_hang.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f eof_hang
.PHONY: all clean
