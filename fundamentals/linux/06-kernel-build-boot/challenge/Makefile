# P3-M02 Challenge Makefile
ARTIFACTS_DIR := ../fixtures/artifacts
CONFIGS_DIR := ../fixtures/configs

.PHONY: all clean

all: fixtures

fixtures:
	mkdir -p fixtures
	cp $(CONFIGS_DIR)/effective_kernel.config fixtures/candidate_effective.config
	cp $(ARTIFACTS_DIR)/vmlinux fixtures/vmlinux_eval
	cp $(ARTIFACTS_DIR)/System.map fixtures/System.map_eval

clean:
	rm -rf fixtures
