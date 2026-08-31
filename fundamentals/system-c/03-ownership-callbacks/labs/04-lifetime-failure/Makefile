CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic
SAN ?= -fsanitize=address,undefined -fno-omit-frame-pointer
all: lifetime_failure
lifetime_failure: main.c
	$(CC) $(CFLAGS) $< -o $@
san: main.c
	$(CC) $(CFLAGS) $(SAN) $< -o lifetime_failure_san
clean:
	rm -f lifetime_failure lifetime_failure_san
.PHONY: all san clean
