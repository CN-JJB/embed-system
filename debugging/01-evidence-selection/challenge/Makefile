CC ?= gcc
CFLAGS ?= -std=c17 -D_POSIX_C_SOURCE=200809L -O0 -g3 -Wall -Wextra -Wpedantic -Werror
all: broken_reader
broken_reader: broken_reader.c
	$(CC) $(CFLAGS) $< -o $@
asan: broken_reader.c
	$(CC) $(CFLAGS) -fsanitize=address -fno-omit-frame-pointer $< -o broken_reader_asan
clean:
	rm -f broken_reader broken_reader_asan
.PHONY: all asan clean
