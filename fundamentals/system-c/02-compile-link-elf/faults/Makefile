CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all f1 f2 f3 f4 clean
all: f1 f2 f3 f4

f1:
	mkdir -p build/f1
	$(CC) $(CFLAGS) -c f1/main.c -o build/f1/main.o
	$(CC) build/f1/main.o -o build/f1/app

f2:
	mkdir -p build/f2
	$(CC) $(CFLAGS) -c f2/a.c -o build/f2/a.o
	$(CC) $(CFLAGS) -c f2/b.c -o build/f2/b.o
	$(CC) $(CFLAGS) -c f2/main.c -o build/f2/main.o
	$(CC) build/f2/main.o build/f2/a.o build/f2/b.o -o build/f2/app

f3:
	mkdir -p build/f3
	$(CC) $(CFLAGS) -c f3/main.c -o build/f3/main.o
	$(CC) $(CFLAGS) -c f3/provider.c -o build/f3/provider.o
	$(CC) build/f3/main.o build/f3/provider.o -o build/f3/app

f4:
	$(MAKE) -C f4

clean:
	rm -rf build
	$(MAKE) -C f4 clean
