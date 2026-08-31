CC ?= gcc
CFLAGS ?= -std=c17 -D_POSIX_C_SOURCE=200809L -O0 -g3 -Wall -Wextra -Wpedantic -Werror
all: evidence_gate
evidence_gate: evidence_gate.c
	$(CC) $(CFLAGS) $< -o $@
asan: evidence_gate.c
	$(CC) $(CFLAGS) -fsanitize=address -fno-omit-frame-pointer $< -o evidence_gate_asan
clean:
	rm -f evidence_gate evidence_gate_asan
.PHONY: all asan clean
