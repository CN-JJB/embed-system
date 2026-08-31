CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
CPPFLAGS ?= -Istarter/include
OBJ = build/main.o build/metrics.o build/report.o build/format.o

.PHONY: all objects clean
all: baseline_elf

objects: $(OBJ)

build:
	mkdir -p build

build/%.o: starter/src/%.c | build
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

baseline_elf: $(OBJ)
	$(CC) $(OBJ) -o $@

clean:
	rm -rf build baseline_elf
