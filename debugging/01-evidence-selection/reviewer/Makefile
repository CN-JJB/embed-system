CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror
ASAN_FLAGS ?= -fsanitize=address -fno-omit-frame-pointer

all: challenge_fixed gate_fixed

challenge_fixed: challenge_fixed.c
	$(CC) $(CFLAGS) $< -o $@

gate_fixed: gate_fixed.c
	$(CC) $(CFLAGS) $< -o $@

asan: challenge_fixed_asan gate_fixed_asan

challenge_fixed_asan: challenge_fixed.c
	$(CC) $(CFLAGS) $(ASAN_FLAGS) $< -o $@

gate_fixed_asan: gate_fixed.c
	$(CC) $(CFLAGS) $(ASAN_FLAGS) $< -o $@

clean:
	rm -f challenge_fixed gate_fixed challenge_fixed_asan gate_fixed_asan

.PHONY: all asan clean
