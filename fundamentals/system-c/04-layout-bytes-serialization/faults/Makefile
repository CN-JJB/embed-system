CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
SANFLAGS = -fno-omit-frame-pointer
all: m07_faults
m07_faults: m07_faults.c
	$(CC) $(CFLAGS) $< -o $@
asan: m07_faults.c
	$(CC) $(CFLAGS) $(SANFLAGS) -fsanitize=address $< -o m07_faults_asan
ubsan: m07_faults.c
	$(CC) $(CFLAGS) $(SANFLAGS) -fsanitize=undefined $< -o m07_faults_ubsan
clean:
	rm -f m07_faults m07_faults_asan m07_faults_ubsan
.PHONY: all asan ubsan clean
