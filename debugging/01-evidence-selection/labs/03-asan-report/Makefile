CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror
all: uaf
uaf: uaf.c
	$(CC) $(CFLAGS) $< -o $@
asan: uaf.c
	$(CC) $(CFLAGS) -fsanitize=address -fno-omit-frame-pointer $< -o uaf_asan
clean:
	rm -f uaf uaf_asan
.PHONY: all asan clean
