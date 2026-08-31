CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: ownership_audit
ownership_audit: main.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f ownership_audit
.PHONY: all clean
