PREFIX ?= /usr/local

.PHONY: install uninstall lint test

install:
	install -d "$(PREFIX)/bin"
	install -m 0755 bin/duo-shots "$(PREFIX)/bin/duo-shots"

uninstall:
	rm -f "$(PREFIX)/bin/duo-shots"

lint:
	shellcheck bin/duo-shots tests/stubs/xcrun tests/stubs/hinge

test:
	bats tests
