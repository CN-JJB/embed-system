CC ?= gcc
BASE = -std=c11 -Wall -Wextra -Wpedantic -Wconversion -g3 -O0 -fno-omit-frame-pointer

all: faults-normal faults-asan faults-ubsan
faults-normal: faults.c
	$(CC) $(BASE) $< -o $@
faults-asan: faults.c
	$(CC) $(BASE) -fsanitize=address $< -o $@
faults-ubsan: faults.c
	$(CC) $(BASE) -fsanitize=undefined -fno-sanitize-recover=undefined $< -o $@
clean:
	rm -f faults-normal faults-asan faults-ubsan
.PHONY: all clean
