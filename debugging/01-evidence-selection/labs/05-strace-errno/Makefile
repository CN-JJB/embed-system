CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror
all: open_failure
open_failure: open_failure.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f open_failure
.PHONY: all clean
