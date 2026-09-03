CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread

SRCS = src/main.c src/pipeline.c src/queue.c
OBJS = $(SRCS:.c=.o)
BIN = repro

.PHONY: all repro clean

all: repro

repro: $(SRCS)
	$(CC) $(CFLAGS) $^ -o $(BIN)

clean:
	rm -f src/*.o $(BIN)
