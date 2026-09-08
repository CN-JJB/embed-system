CROSS_COMPILE ?= arm-none-linux-gnueabihf-
ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
  ifneq ($(shell which arm-linux-gnueabihf-gcc 2>/dev/null),)
    CROSS_COMPILE := arm-linux-gnueabihf-
  endif
endif

CC := $(CROSS_COMPILE)gcc
HOST_CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2

FIXTURES_DIR := fixtures

.PHONY: all clean

all: $(FIXTURES_DIR)/candidate_alpha $(FIXTURES_DIR)/candidate_beta $(FIXTURES_DIR)/candidate_gamma

$(FIXTURES_DIR)/candidate_alpha:
	mkdir -p $(FIXTURES_DIR)
	# Alpha: ARM dynamic binary
	echo 'int main(){return 1;}' | $(CC) -x c - -O2 -o $@

$(FIXTURES_DIR)/candidate_beta:
	mkdir -p $(FIXTURES_DIR)
	# Beta: Host binary (Wrong architecture for ARM target)
	echo 'int main(){return 2;}' | $(HOST_CC) -x c - -O2 -o $@

$(FIXTURES_DIR)/candidate_gamma:
	mkdir -p $(FIXTURES_DIR)
	# Gamma: ARM static binary (Ready for minimal rootfs)
	echo 'int main(){return 3;}' | $(CC) -x c - -static -O2 -o $@

clean:
	rm -rf $(FIXTURES_DIR)
