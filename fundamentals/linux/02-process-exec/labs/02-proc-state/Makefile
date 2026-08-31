CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all clean
all: proc_state
proc_state: proc_state.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f proc_state inherited.log
