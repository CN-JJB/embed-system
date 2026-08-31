CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror
all: challenge_fixed gate_fixed
challenge_fixed: challenge_fixed.c
	$(CC) $(CFLAGS) $< -o $@
gate_fixed: gate_fixed.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f challenge_fixed gate_fixed
.PHONY: all clean
