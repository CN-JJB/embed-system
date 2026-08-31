CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: callback_ctx
callback_ctx: main.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f callback_ctx
.PHONY: all clean
