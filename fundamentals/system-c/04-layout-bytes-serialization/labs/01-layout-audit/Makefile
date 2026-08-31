CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: layout_audit
layout_audit: layout_audit.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f layout_audit
.PHONY: all clean
