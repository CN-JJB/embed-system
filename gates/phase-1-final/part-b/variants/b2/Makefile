CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror

SRCS = spool.c harness.c
OBJS = $(SRCS:.c=.o)
BIN = repro

.PHONY: all repro clean

all: repro

repro: $(SRCS)
	$(CC) $(CFLAGS) $^ -o $(BIN)

clean:
	rm -f $(OBJS) $(BIN) /tmp/b2_test_*.log
