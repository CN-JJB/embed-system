CC ?= gcc
BASE = -std=c11 -Wall -Wextra -Wpedantic -Wconversion -g3 -O0 -fno-omit-frame-pointer
all: frame-gate frame-gate-sanitize
frame-gate: frame_gate.c
	$(CC) $(BASE) $< -o $@
frame-gate-sanitize: frame_gate.c
	$(CC) $(BASE) -fsanitize=address,undefined -fno-sanitize-recover=undefined $< -o $@
clean:
	rm -f frame-gate frame-gate-sanitize
.PHONY: all clean
