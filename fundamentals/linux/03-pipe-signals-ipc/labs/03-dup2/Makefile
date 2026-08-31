
CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: dup2_demo
dup2_demo: main.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f dup2_demo
.PHONY: all clean
