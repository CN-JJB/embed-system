CC ?= gcc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Wconversion -g3 -O0
all: storage_lifetime
storage_lifetime: main.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f storage_lifetime
.PHONY: all clean
