CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: object_bytes
object_bytes: object_bytes.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f object_bytes
.PHONY: all clean
