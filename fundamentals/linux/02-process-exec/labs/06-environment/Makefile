CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic
.PHONY: all clean
all: env_parent env_image
env_parent: env_parent.c
	$(CC) $(CFLAGS) $< -o $@
env_image: env_image.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f env_parent env_image
