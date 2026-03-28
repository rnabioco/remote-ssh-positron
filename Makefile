PREFIX := $(HOME)/.local/bin
SCRIPTS := positron-remote-alpine.sh positron-remote-bodhi.sh

.PHONY: install uninstall

install:
	mkdir -p $(PREFIX)
	cp $(SCRIPTS) $(PREFIX)/
	chmod +x $(addprefix $(PREFIX)/,$(SCRIPTS))

uninstall:
	rm -f $(addprefix $(PREFIX)/,$(SCRIPTS))
