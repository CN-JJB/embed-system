CC ?= gcc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Wconversion -g3 -O0
all: fdcopy-limit
fdcopy-limit: main.c fdcopy_limit.c fdcopy_limit.h
	$(CC) $(CFLAGS) main.c fdcopy_limit.c -o $@
clean:
	rm -f fdcopy-limit input.bin out.bin
.PHONY: all clean
