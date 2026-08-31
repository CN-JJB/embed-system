CC ?= gcc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Wconversion -g3 -O0

all: array_pointer

array_pointer: main.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f array_pointer
.PHONY: all clean
