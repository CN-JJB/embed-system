CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: boundary_audit
boundary_audit: boundary_audit.c
	$(CC) $(CFLAGS) $< -o $@
asan: boundary_audit.c
	$(CC) $(CFLAGS) -fsanitize=address -fno-omit-frame-pointer $< -o boundary_audit_asan
clean:
	rm -f boundary_audit boundary_audit_asan
.PHONY: all asan clean
