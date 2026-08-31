CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -D_POSIX_C_SOURCE=200809L

all: pipe_gate producer consumer

pipe_gate: pipe_gate.c
	$(CC) $(CFLAGS) $< -o $@

producer: producer.c
	$(CC) $(CFLAGS) $< -o $@

consumer: consumer.c
	$(CC) $(CFLAGS) $< -o $@

reviewer: ../reviewer/pipe_gate_fixed.c producer consumer
	$(CC) $(CFLAGS) ../reviewer/pipe_gate_fixed.c -o pipe_gate_fixed

clean:
	rm -f pipe_gate pipe_gate_fixed producer consumer gate.trace
