CC ?= gcc
CPPFLAGS := -Isrc
BASE := -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread
SRC := src/main.c src/parser.c src/codec.c src/queue.c src/stats.c
LIBSRC := src/parser.c src/codec.c src/queue.c src/stats.c
BUILD := build

.PHONY: all test san tsan clean faults unknown-repro unknown-solution

all: $(BUILD)/telemetry $(BUILD)/test_unit faults $(BUILD)/unknown_repro $(BUILD)/unknown_solution

$(BUILD):
	mkdir -p $@

$(BUILD)/telemetry: $(SRC) | $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) $(SRC) -o $@

$(BUILD)/test_unit: tests/test_unit.c $(LIBSRC) | $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) tests/test_unit.c $(LIBSRC) -o $@

# Fault Campaign stations
$(BUILD)/fault_f1: faults/f1_queue_race/station.c | $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) faults/f1_queue_race/station.c -o $@

$(BUILD)/fault_f2: faults/f2_shutdown_hang/station.c | $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) faults/f2_shutdown_hang/station.c -o $@

$(BUILD)/fault_f3: faults/f3_fd_leak/station.c | $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) faults/f3_fd_leak/station.c -o $@

$(BUILD)/fault_f4: faults/f4_bad_boundary/station.c src/codec.c src/parser.c | $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) faults/f4_bad_boundary/station.c src/codec.c src/parser.c -o $@

faults: $(BUILD)/fault_f1 $(BUILD)/fault_f2 $(BUILD)/fault_f3 $(BUILD)/fault_f4

# Unknown Fault Harnesses
$(BUILD)/unknown_repro: faults/unknown/repro.c | $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) faults/unknown/repro.c -o $@

$(BUILD)/unknown_solution: reviewer/unknown_solution.c | $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) reviewer/unknown_solution.c -o $@

unknown-repro: $(BUILD)/unknown_repro
	-./$(BUILD)/unknown_repro

unknown-solution: $(BUILD)/unknown_solution
	./$(BUILD)/unknown_solution

test: all $(BUILD)/test_unit unknown-solution
	./$(BUILD)/test_unit
	./scripts/integration.sh ./$(BUILD)/telemetry fixtures

san: clean
	mkdir -p $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) -fsanitize=address,undefined -fno-omit-frame-pointer $(SRC) -o $(BUILD)/telemetry
	$(CC) $(CPPFLAGS) $(BASE) -fsanitize=address,undefined -fno-omit-frame-pointer tests/test_unit.c $(LIBSRC) -o $(BUILD)/test_unit
	$(CC) $(CPPFLAGS) $(BASE) -fsanitize=address,undefined -fno-omit-frame-pointer reviewer/unknown_solution.c -o $(BUILD)/unknown_solution
	ASAN_OPTIONS=detect_leaks=1 ./$(BUILD)/test_unit
	ASAN_OPTIONS=detect_leaks=1 ./$(BUILD)/unknown_solution
	ASAN_OPTIONS=detect_leaks=1 ./scripts/integration.sh ./$(BUILD)/telemetry fixtures

tsan: clean
	mkdir -p $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) -fsanitize=thread $(SRC) -o $(BUILD)/telemetry
	$(CC) $(CPPFLAGS) $(BASE) -fsanitize=thread tests/test_unit.c $(LIBSRC) -o $(BUILD)/test_unit
	$(CC) $(CPPFLAGS) $(BASE) -fsanitize=thread reviewer/unknown_solution.c -o $(BUILD)/unknown_solution
	./$(BUILD)/test_unit
	./$(BUILD)/unknown_solution
	./scripts/integration.sh ./$(BUILD)/telemetry fixtures

clean:
	rm -rf $(BUILD)
