CC ?= gcc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Wconversion -g3 -O0
all: proc_maps
proc_maps: main.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f proc_maps
.PHONY: all clean
