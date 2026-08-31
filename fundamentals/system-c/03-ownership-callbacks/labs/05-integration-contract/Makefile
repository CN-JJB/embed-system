CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: integration_contract
integration_contract: main.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f integration_contract
.PHONY: all clean
