CC ?= gcc
CFLAGS ?= -std=c11 -g3 -O0 -Wall -Wextra -Wpedantic

.PHONY: all fault-link tsan clean
all: fault_seg fault_corruption fault_race fault_link_main.o fault_link_provider.o

fault_seg: starter/fault_seg.c
	$(CC) $(CFLAGS) $< -o $@
fault_corruption: starter/fault_corruption.c
	$(CC) $(CFLAGS) $< -o $@
fault_race: starter/fault_race.c
	$(CC) $(CFLAGS) -pthread $< -o $@
fault_link_main.o: starter/fault_link_main.c
	$(CC) $(CFLAGS) -c $< -o $@
fault_link_provider.o: starter/fault_link_provider.c
	$(CC) $(CFLAGS) -c $< -o $@
fault-link: fault_link_main.o fault_link_provider.o
	$(CC) $^ -o fault_link

tsan:
	$(CC) $(CFLAGS) -pthread -fsanitize=thread starter/fault_race.c -o fault_race_tsan

clean:
	rm -f fault_seg fault_corruption fault_race fault_race_tsan fault_link *.o
