
CC ?= gcc
CFLAGS ?= -std=c17 -D_POSIX_C_SOURCE=200809L -O0 -g -Wall -Wextra -Wpedantic -Werror
all: signal_stop
signal_stop: signal_stop.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f signal_stop
.PHONY: all clean
