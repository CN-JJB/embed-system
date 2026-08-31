CC ?= gcc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Wconversion -g3 -O0
all: fd_hold
fd_hold: fd_hold.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f fd_hold a.txt b.txt
.PHONY: all clean
