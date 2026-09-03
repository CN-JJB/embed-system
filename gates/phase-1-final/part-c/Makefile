CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -Isrc

SRCS = src/main.c src/calc.c src/state.c
OBJS = src/main.o src/calc.o src/state.o

.PHONY: all objects failing-link fixed-link clean

all: objects fixed-link

objects: $(OBJS)

src/%.o: src/%.c
	$(CC) $(CFLAGS) -c $< -o $@

# Demonstrates link-time failure (missing state.o containing external references)
failing-link: src/main.o src/calc.o
	@echo "--- Attempting Link Without state.o ---"
	$(CC) src/main.o src/calc.o -o failing_app

fixed-link: $(OBJS)
	$(CC) $^ -o part_c_app

clean:
	rm -f src/*.o part_c_app failing_app
