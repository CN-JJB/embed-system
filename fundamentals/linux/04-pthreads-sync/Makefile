CC?=cc
CFLAGS=-std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread
LABS=01-resource-model 02-lost-update 03-mutex-repair 04-shared-stats 05-condvar-predicate 06-lock-misuse
.PHONY: all test tsan clean
all: $(LABS:%=build/%) build/challenge.o
build:
	mkdir -p $@
build/%: labs/%/lab.c | build
	$(CC) $(CFLAGS) $< -o $@
build/challenge.o: challenge/shared_stats.c challenge/shared_stats.h | build
	$(CC) $(CFLAGS) -Ichallenge -c challenge/shared_stats.c -o $@
test: all
	./build/01-resource-model
	./build/03-mutex-repair
	./build/04-shared-stats
	./build/05-condvar-predicate
	./build/06-lock-misuse
tsan: clean | build
	$(CC) $(CFLAGS) -fsanitize=thread labs/02-lost-update/lab.c -o build/lost-update-tsan
	-./build/lost-update-tsan
clean:
	rm -rf build
