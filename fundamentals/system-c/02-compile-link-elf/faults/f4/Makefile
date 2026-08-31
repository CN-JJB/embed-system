CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all clean
all: stale_demo
worker.o: worker.c
	$(CC) $(CFLAGS) -c $< -o $@
main.o: main.c
	$(CC) $(CFLAGS) -c $< -o $@
stale_demo: main.o worker.o
	$(CC) $^ -o $@
clean:
	rm -f *.o stale_demo
