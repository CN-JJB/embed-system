CC ?= gcc
CFLAGS ?= -std=c17 -D_POSIX_C_SOURCE=200809L -O0 -g3 -Wall -Wextra -Wpedantic -Werror
all: pipe_hang
pipe_hang: pipe_hang.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f pipe_hang
.PHONY: all clean
