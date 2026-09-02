CC?=gcc
CFLAGS=-std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread
LABS=01-resource-model 02-lost-update 03-mutex-repair 04-shared-stats 05-condvar-predicate 06-lock-misuse

.PHONY: all test tsan clean test-challenge-starter test-challenge-solution gate-seeded gate-solution

all: $(LABS:%=build/%) build/test_challenge_starter build/test_challenge_solution build/gate_seeded build/gate_solution

build:
	mkdir -p $@

build/%: labs/%/lab.c | build
	$(CC) $(CFLAGS) $< -o $@

build/challenge_starter.o: challenge/shared_stats.c challenge/shared_stats.h | build
	$(CC) $(CFLAGS) -Ichallenge -c challenge/shared_stats.c -o $@

build/challenge_solution.o: reviewer/challenge_solution.c challenge/shared_stats.h | build
	$(CC) $(CFLAGS) -Ichallenge -c reviewer/challenge_solution.c -o $@

build/test_challenge_starter: challenge/test_challenge.c build/challenge_starter.o | build
	$(CC) $(CFLAGS) -Ichallenge challenge/test_challenge.c build/challenge_starter.o -o $@

build/test_challenge_solution: challenge/test_challenge.c build/challenge_solution.o | build
	$(CC) $(CFLAGS) -Ichallenge challenge/test_challenge.c build/challenge_solution.o -o $@

build/gate_seeded: gate/gate_seeded.c | build
	$(CC) $(CFLAGS) $< -o $@

build/gate_solution: reviewer/gate_solution.c | build
	$(CC) $(CFLAGS) $< -o $@

test-challenge-starter: build/test_challenge_starter
	-./build/test_challenge_starter

test-challenge-solution: build/test_challenge_solution
	./build/test_challenge_solution

gate-seeded: build/gate_seeded
	-./build/gate_seeded all

gate-solution: build/gate_solution
	./build/gate_solution all

test: all test-challenge-solution gate-solution
	./build/01-resource-model
	./build/03-mutex-repair
	./build/04-shared-stats
	./build/05-condvar-predicate
	./build/06-lock-misuse

tsan: clean | build
	$(CC) $(CFLAGS) -fsanitize=thread labs/02-lost-update/lab.c -o build/lost-update-tsan
	-./build/lost-update-tsan
	$(CC) $(CFLAGS) -fsanitize=thread gate/gate_seeded.c -o build/gate-seeded-tsan
	-./build/gate-seeded-tsan race
	$(CC) $(CFLAGS) -fsanitize=thread reviewer/gate_solution.c -o build/gate-solution-tsan
	./build/gate-solution-tsan race

clean:
	rm -rf build
