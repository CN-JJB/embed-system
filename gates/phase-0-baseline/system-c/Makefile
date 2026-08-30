CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic

.PHONY: all bug-hunt bug-hunt-san event-bus-test clean
all: bug-hunt

bug-hunt:
	$(CC) $(CFLAGS) starter/telemetry_bug_hunt.c -o telemetry_bug_hunt

bug-hunt-san:
	$(CC) $(CFLAGS) -fsanitize=address,undefined -fno-omit-frame-pointer starter/telemetry_bug_hunt.c -o telemetry_bug_hunt_san

event-bus-test:
	$(CC) $(CFLAGS) -Istarter starter/event_bus.c fixtures/test_event_bus.c -o event_bus_test
	./event_bus_test

clean:
	rm -f telemetry_bug_hunt telemetry_bug_hunt_san event_bus_test
