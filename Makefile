
DART_INTERACTIVE_REPO  = https://github.com/fzyzcjy/dart_interactive
INTERACTIVE_DIR       ?= $(CURDIR)/dart_interactive

.PHONY: all
all:
	@


$(INTERACTIVE_DIR):
	@git clone $(DART_INTERACTIVE_REPO) $@

# $(INTERACTIVE_DIR)/packages/
# build-interactive:
