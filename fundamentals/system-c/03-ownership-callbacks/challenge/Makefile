CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: dispatcher

dispatcher: dispatcher.c dispatcher.h test_dispatcher.c
	$(CC) $(CFLAGS) dispatcher.c test_dispatcher.c -o $@
reviewer: ../reviewer/dispatcher_solution.c dispatcher.h test_dispatcher.c
	$(CC) $(CFLAGS) ../reviewer/dispatcher_solution.c test_dispatcher.c -o dispatcher_solution
clean:
	rm -f dispatcher dispatcher_solution
.PHONY: all reviewer clean
