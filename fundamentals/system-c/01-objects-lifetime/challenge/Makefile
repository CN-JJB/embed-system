CC ?= gcc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -Wconversion -g3 -O0

all: test_span

test_span: span_u8.c span_u8.h test_span.c
	$(CC) $(CFLAGS) span_u8.c test_span.c -o $@

clean:
	rm -f test_span
.PHONY: all clean
