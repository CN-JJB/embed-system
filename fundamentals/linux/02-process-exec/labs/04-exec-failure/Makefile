CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all clean
all: exec_failure
exec_failure: exec_failure.c
	$(CC) $(CFLAGS) $< -o $@
	chmod 0644 not_executable.sh
clean:
	rm -f exec_failure
