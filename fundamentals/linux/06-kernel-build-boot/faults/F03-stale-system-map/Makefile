# Fault F03: Stale / Mismatched System.map Fixture
ARTIFACTS_DIR := ../../fixtures/artifacts

.PHONY: all clean setup-fixtures

all: setup-fixtures

setup-fixtures:
	mkdir -p fixtures
	cp $(ARTIFACTS_DIR)/vmlinux fixtures/vmlinux
	cp $(ARTIFACTS_DIR)/System.map fixtures/System.map.current
	cp $(ARTIFACTS_DIR)/stale_System.map fixtures/System.map.stale

clean:
	rm -rf fixtures
