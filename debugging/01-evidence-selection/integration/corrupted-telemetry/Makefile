CC ?= gcc
CFLAGS ?= -std=c17 -D_POSIX_C_SOURCE=200809L -O0 -g3 -Wall -Wextra -Wpedantic -Werror
all: investigate
investigate: investigate.c
	$(CC) $(CFLAGS) $< -o $@
asan: investigate.c
	$(CC) $(CFLAGS) -fsanitize=address -fno-omit-frame-pointer $< -o investigate_asan
clean:
	rm -f investigate investigate_asan
.PHONY: all asan clean
