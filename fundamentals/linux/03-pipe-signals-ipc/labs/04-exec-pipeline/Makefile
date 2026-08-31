
CC ?= gcc
CFLAGS ?= -std=c17 -O0 -g -Wall -Wextra -Wpedantic -Werror
all: producer consumer pipeline
producer: producer.c
	$(CC) $(CFLAGS) $< -o $@
consumer: consumer.c
	$(CC) $(CFLAGS) $< -o $@
pipeline: pipeline.c
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -f producer consumer pipeline
.PHONY: all clean
