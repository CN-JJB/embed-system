CC ?= gcc
CPPFLAGS ?= -Iinclude
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
OBJ = build/main.o build/registry.o build/report.o # format.o deliberately omitted
.PHONY: all objects clean
all: registry_app
objects: build/main.o build/registry.o build/report.o build/format.o
build:
	mkdir -p build
build/%.o: src/%.c | build
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@
registry_app: $(OBJ)
	$(CC) $(OBJ) -o $@
clean:
	rm -rf build registry_app
