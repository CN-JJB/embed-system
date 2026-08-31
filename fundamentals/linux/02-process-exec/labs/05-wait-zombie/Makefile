CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all clean
all: zombie_lab
zombie_lab: zombie_lab.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f zombie_lab
