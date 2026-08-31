CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all clean
all: fork_values
fork_values: fork_values.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f fork_values
