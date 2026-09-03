CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -MMD -MP
SAN_FLAGS ?= -fsanitize=address,undefined -fno-omit-frame-pointer

SRCS = main.c sifter.c parser.c
OBJS = $(SRCS:.c=.o)
DEPS = $(SRCS:.c=.d)
BIN = sifter
BIN_SAN = sifter_san

.PHONY: all test san clean

all: $(BIN)

$(BIN): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

san: $(SRCS)
	$(CC) $(CFLAGS) $(SAN_FLAGS) $^ -o $(BIN_SAN)

test: $(BIN)
	@echo "Running basic tests..."
	./$(BIN) --input ../../../part-a/fixtures/valid.txt --filter 0 --stats
	./$(BIN) --input ../../../part-a/fixtures/invalid.txt --stats
	./$(BIN) --input ../../../part-a/fixtures/empty.txt --stats
	@echo "Part A Reference tests passed."

clean:
	rm -f $(OBJS) $(DEPS) $(BIN) $(BIN_SAN)

-include $(DEPS)
