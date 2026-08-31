CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
SAN ?= -fsanitize=address,undefined -fno-omit-frame-pointer
all: ownership_gate
ownership_gate: ownership_gate.c
	$(CC) $(CFLAGS) $< -o $@
san: ownership_gate.c
	$(CC) $(CFLAGS) $(SAN) $< -o ownership_gate_san
reviewer: ../reviewer/ownership_gate_fixed.c
	$(CC) $(CFLAGS) ../reviewer/ownership_gate_fixed.c -o ownership_gate_fixed
clean:
	rm -f ownership_gate ownership_gate_san ownership_gate_fixed
.PHONY: all san reviewer clean
