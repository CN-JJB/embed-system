CC ?= gcc
CPPFLAGS ?= -I.
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
OBJ = build/main.o build/stats.o build/format.o

.PHONY: all stages clean
all: app.elf

build:
	mkdir -p build

build/%.o: %.c | build
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

app.elf: $(OBJ)
	$(CC) $(OBJ) -o $@

stages: build
	$(CC) $(CPPFLAGS) $(CFLAGS) -E main.c -o build/main.i
	$(CC) $(CPPFLAGS) $(CFLAGS) -S main.c -o build/main.s
	$(CC) $(CPPFLAGS) $(CFLAGS) -c main.c -o build/main.o
	$(CC) $(CPPFLAGS) $(CFLAGS) -c stats.c -o build/stats.o
	$(CC) $(CPPFLAGS) $(CFLAGS) -c format.c -o build/format.o
	$(CC) $(OBJ) -o app.elf

clean:
	rm -rf build app.elf
