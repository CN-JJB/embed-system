CC ?= gcc
CPPFLAGS := -Isrc
BASE := -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread
SRC := src/main.c src/parser.c src/codec.c src/queue.c src/stats.c
LIBSRC := src/parser.c src/codec.c src/queue.c src/stats.c
BUILD := build

.PHONY: all test san tsan clean
all: $(BUILD)/telemetry
$(BUILD):
	mkdir -p $@
$(BUILD)/telemetry: $(SRC) | $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) $(SRC) -o $@
$(BUILD)/test_unit: tests/test_unit.c $(LIBSRC) | $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) tests/test_unit.c $(LIBSRC) -o $@
test: all $(BUILD)/test_unit
	./$(BUILD)/test_unit
	./scripts/integration.sh ./$(BUILD)/telemetry fixtures
san: clean
	mkdir -p $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) -fsanitize=address,undefined -fno-omit-frame-pointer $(SRC) -o $(BUILD)/telemetry
	$(CC) $(CPPFLAGS) $(BASE) -fsanitize=address,undefined -fno-omit-frame-pointer tests/test_unit.c $(LIBSRC) -o $(BUILD)/test_unit
	ASAN_OPTIONS=detect_leaks=1 ./$(BUILD)/test_unit
	ASAN_OPTIONS=detect_leaks=1 ./scripts/integration.sh ./$(BUILD)/telemetry fixtures
tsan: clean
	mkdir -p $(BUILD)
	$(CC) $(CPPFLAGS) $(BASE) -fsanitize=thread $(SRC) -o $(BUILD)/telemetry
	$(CC) $(CPPFLAGS) $(BASE) -fsanitize=thread tests/test_unit.c $(LIBSRC) -o $(BUILD)/test_unit
	./$(BUILD)/test_unit
	./scripts/integration.sh ./$(BUILD)/telemetry fixtures
clean:
	rm -rf $(BUILD)
