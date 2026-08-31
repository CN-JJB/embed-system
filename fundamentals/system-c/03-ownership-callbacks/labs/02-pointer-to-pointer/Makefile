CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: frame_contract
frame_contract: main.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f frame_contract
.PHONY: all clean
