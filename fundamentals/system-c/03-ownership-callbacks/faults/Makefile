CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
SAN ?= -fsanitize=address,undefined -fno-omit-frame-pointer
all: ownership_faults
ownership_faults: faults.c
	$(CC) $(CFLAGS) $< -o $@
san: faults.c
	$(CC) $(CFLAGS) $(SAN) $< -o ownership_faults_san
clean:
	rm -f ownership_faults ownership_faults_san
.PHONY: all san clean
