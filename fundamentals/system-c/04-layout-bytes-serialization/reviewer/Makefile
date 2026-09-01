CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: challenge_solution gate_fixed
challenge_solution: telemetry_codec_solution.c ../challenge/test_codec.c ../challenge/telemetry_codec.h
	$(CC) $(CFLAGS) telemetry_codec_solution.c ../challenge/test_codec.c -o $@
gate_fixed: boundary_audit_fixed.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f challenge_solution gate_fixed
.PHONY: all clean
