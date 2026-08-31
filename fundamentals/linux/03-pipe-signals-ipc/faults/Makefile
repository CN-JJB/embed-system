
CC ?= gcc
CFLAGS ?= -std=c17 -D_POSIX_C_SOURCE=200809L -O0 -g -Wall -Wextra -Wpedantic -Werror
all: fd_faults holder wait_before_drain unsafe_signal
fd_faults: fd_faults.c
	$(CC) $(CFLAGS) $< -o $@
holder: holder.c
	$(CC) $(CFLAGS) $< -o $@
wait_before_drain: wait_before_drain.c
	$(CC) $(CFLAGS) $< -o $@
unsafe_signal: unsafe_signal.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f fd_faults holder wait_before_drain unsafe_signal
.PHONY: all clean
