
CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: fork_pipe
fork_pipe: main.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f fork_pipe
.PHONY: all clean
