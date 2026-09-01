CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: test_codec
test_codec: telemetry_codec.c test_codec.c telemetry_codec.h
	$(CC) $(CFLAGS) telemetry_codec.c test_codec.c -o $@
clean:
	rm -f test_codec
.PHONY: all clean
