CC ?= gcc
CFLAGS ?= -std=c17 -D_POSIX_C_SOURCE=200809L -O0 -g3 -Wall -Wextra -Wpedantic -Werror
all: m08_faults
m08_faults: m08_faults.c
	$(CC) $(CFLAGS) $< -o $@
asan: m08_faults.c
	$(CC) $(CFLAGS) -fsanitize=address -fno-omit-frame-pointer $< -o m08_faults_asan
clean:
	rm -f m08_faults m08_faults_asan
.PHONY: all asan clean
