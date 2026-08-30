CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic

.PHONY: all clean
all: pipeline producer filter fd_zombie_lab

pipeline: starter/pipeline.c
	$(CC) $(CFLAGS) $< -o $@
producer: fixtures/producer.c
	$(CC) $(CFLAGS) $< -o $@
filter: fixtures/filter.c
	$(CC) $(CFLAGS) $< -o $@
fd_zombie_lab: starter/fd_zombie_lab.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f pipeline producer filter fd_zombie_lab
