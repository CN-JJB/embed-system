CC ?= gcc
CPPFLAGS ?= -Iinclude
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
SRC = src/main.c src/sampler.c src/format.c src/report.c src/version.c
OBJ = $(SRC:src/%.c=build/%.o)
.PHONY: all objects clean
all: gate_app
objects: $(OBJ)
build:
	mkdir -p build
# Deliberately missing generated/simple header dependencies.
build/%.o: src/%.c | build
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
# Deliberately omits report.o from the link line.
gate_app: $(OBJ)
	$(CC) build/main.o build/sampler.o build/format.o build/version.o -o $@
clean:
	rm -rf build gate_app
