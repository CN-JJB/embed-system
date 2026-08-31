CC ?= gcc
CPPFLAGS ?= -Iinclude
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
DEPFLAGS ?= -MMD -MP
OBJ = build/main.o build/registry.o build/report.o build/format.o
DEP = $(OBJ:.o=.d)
.PHONY: all clean
all: registry_app
build:
	mkdir -p build
build/%.o: src/%.c | build
	$(CC) $(CPPFLAGS) $(CFLAGS) $(DEPFLAGS) -c $< -o $@
registry_app: $(OBJ)
	$(CC) $(OBJ) -o $@
-include $(DEP)
clean:
	rm -rf build registry_app
