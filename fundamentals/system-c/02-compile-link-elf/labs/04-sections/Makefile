CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all clean
all: sections sections.o
sections.o: sections.c
	$(CC) $(CFLAGS) -c $< -o $@
sections: sections.o
	$(CC) $< -o $@
clean:
	rm -f sections sections.o
