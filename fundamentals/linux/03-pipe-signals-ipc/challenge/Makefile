
CC ?= gcc
CFLAGS ?= -std=c17 -D_POSIX_C_SOURCE=200809L -O0 -g -Wall -Wextra -Wpedantic -Werror
all: capture_exec burst
capture_exec: capture_exec.c
	$(CC) $(CFLAGS) $< -o $@
burst: burst.c
	$(CC) $(CFLAGS) $< -o $@
reviewer: ../reviewer/capture_exec_solution.c burst.c
	$(CC) $(CFLAGS) ../reviewer/capture_exec_solution.c -o capture_exec_solution
	$(CC) $(CFLAGS) burst.c -o burst
clean:
	rm -f capture_exec capture_exec_solution burst captured.out
.PHONY: all reviewer clean
