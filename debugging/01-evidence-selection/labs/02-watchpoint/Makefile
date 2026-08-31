CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror
all: watch_bug
watch_bug: watch_bug.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f watch_bug
.PHONY: all clean
