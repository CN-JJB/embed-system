CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all clean
all: run_one show_env
run_one: run_one.c
	$(CC) $(CFLAGS) $< -o $@
show_env: show_env.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f run_one show_env
