CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror
all: state_bug
state_bug: state_bug.c
	$(CC) $(CFLAGS) $< -o $@
debug: state_bug
clean:
	rm -f state_bug
.PHONY: all debug clean
