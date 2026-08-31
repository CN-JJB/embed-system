CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all clean
all: parent child_image child_image.o
parent: parent.c
	$(CC) $(CFLAGS) $< -o $@
child_image.o: child_image.c
	$(CC) $(CFLAGS) -c $< -o $@
child_image: child_image.o
	$(CC) $< -o $@
clean:
	rm -f parent child_image child_image.o
