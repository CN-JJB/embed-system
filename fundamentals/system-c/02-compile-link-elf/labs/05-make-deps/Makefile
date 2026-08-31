CC ?= gcc
CPPFLAGS ?= -Iinclude
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
DEPFLAGS = -MMD -MP
SRC = src/main.c src/stats.c src/format.c
OBJ = $(SRC:src/%.c=build/%.o)
DEP = $(OBJ:.o=.d)

.PHONY: all clean
all: make_demo

build:
	mkdir -p build

build/%.o: src/%.c | build
	$(CC) $(CPPFLAGS) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

make_demo: $(OBJ)
	$(CC) $(OBJ) -o $@

-include $(DEP)

clean:
	rm -rf build make_demo
