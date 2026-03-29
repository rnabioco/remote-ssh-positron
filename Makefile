PREFIX := $(HOME)/.local/bin
SCRIPT := positron-remote.sh

.PHONY: install uninstall

install:
	mkdir -p $(PREFIX)
	cp $(SCRIPT) $(PREFIX)/
	chmod +x $(PREFIX)/$(SCRIPT)

uninstall:
	rm -f $(PREFIX)/$(SCRIPT)
