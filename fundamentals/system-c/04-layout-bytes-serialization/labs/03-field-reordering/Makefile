CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: field_reorder
field_reorder: field_reorder.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f field_reorder
.PHONY: all clean
