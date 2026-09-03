CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread

SRCS = main.c pipeline.c queue.c
OBJS = $(SRCS:.c=.o)
BIN = fixed_ref

.PHONY: all clean

all: $(BIN)

$(BIN): $(SRCS)
	$(CC) $(CFLAGS) $^ -o $@

clean:
	rm -f $(OBJS) $(BIN)
