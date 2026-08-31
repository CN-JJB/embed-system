CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all clean
all: exec_demo child_image
exec_demo: exec_demo.c
	$(CC) $(CFLAGS) $< -o $@
child_image: child_image.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f exec_demo child_image
