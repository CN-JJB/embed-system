CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic

.PHONY: all objects clean
all: symbols_app
objects: main.o symbols.o undefined_only.o

main.o: main.c symbols.h
	$(CC) $(CFLAGS) -c $< -o $@

symbols.o: symbols.c symbols.h
	$(CC) $(CFLAGS) -c $< -o $@

undefined_only.o: undefined_only.c
	$(CC) $(CFLAGS) -c $< -o $@

symbols_app: main.o symbols.o
	$(CC) $^ -o $@

clean:
	rm -f *.o symbols_app
