CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -D_POSIX_C_SOURCE=200809L

all: m05_m06_integration

m05_m06_integration: integration.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f m05_m06_integration
