CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all clean
all: mini_supervisor worker_image
mini_supervisor: mini_supervisor.c
	$(CC) $(CFLAGS) $< -o $@
worker_image: worker_image.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f mini_supervisor worker_image supervisor.log
