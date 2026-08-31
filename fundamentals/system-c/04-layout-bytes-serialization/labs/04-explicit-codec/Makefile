CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: codec
codec: codec.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f codec
.PHONY: all clean
