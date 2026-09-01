CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror
all: overflow
overflow: overflow.c
	$(CC) $(CFLAGS) $< -o $@
ubsan: overflow.c
	$(CC) $(CFLAGS) -fsanitize=undefined -fno-sanitize-recover=undefined $< -o overflow_ubsan
clean:
	rm -f overflow overflow_ubsan
.PHONY: all ubsan clean
