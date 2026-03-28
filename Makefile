PREFIX := $(HOME)/.local/bin
SCRIPTS := alpine-positron.sh bodhi-positron.sh

.PHONY: install uninstall

install:
	mkdir -p $(PREFIX)
	cp $(SCRIPTS) $(PREFIX)/
	chmod +x $(addprefix $(PREFIX)/,$(SCRIPTS))

uninstall:
	rm -f $(addprefix $(PREFIX)/,$(SCRIPTS))
