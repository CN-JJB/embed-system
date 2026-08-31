CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all clean
all: relocation_app
main.o: main.c stats.h
	$(CC) $(CFLAGS) -c $< -o $@
stats.o: stats.c stats.h
	$(CC) $(CFLAGS) -c $< -o $@
relocation_app: main.o stats.o
	$(CC) $^ -o $@
clean:
	rm -f *.o relocation_app
