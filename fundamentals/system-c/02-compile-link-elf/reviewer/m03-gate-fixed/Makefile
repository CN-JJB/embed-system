CC ?= gcc
CPPFLAGS ?= -Iinclude
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
DEPFLAGS = -MMD -MP
SRC = src/main.c src/sampler.c src/format.c src/report.c src/version.c
OBJ = $(SRC:src/%.c=build/%.o)
DEP = $(OBJ:.o=.d)
.PHONY: all clean
all: gate_app
build:
	mkdir -p build
build/%.o: src/%.c | build
	$(CC) $(CPPFLAGS) $(CFLAGS) $(DEPFLAGS) -c $< -o $@
gate_app: $(OBJ)
	$(CC) $(OBJ) -o $@
-include $(DEP)
clean:
	rm -rf build gate_app
