CC ?= gcc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Wconversion -g3 -O0
all: read_path
read_path: read_path.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f read_path
.PHONY: all clean
