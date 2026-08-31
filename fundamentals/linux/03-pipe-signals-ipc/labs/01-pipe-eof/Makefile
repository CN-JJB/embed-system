
CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: pipe_eof
pipe_eof: main.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f pipe_eof
.PHONY: all clean
