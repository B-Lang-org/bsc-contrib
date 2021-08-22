PWD := $(shell pwd)
TOP := $(PWD)

PREFIX   ?= $(TOP)/inst
BUILDDIR ?= $(TOP)/build

.PHONY: all
all: install

# -------------------------

.PHONY: rem_inst
rem_inst:
	rm -fr $(PREFIX)

.PHONY: rem_build
rem_build:
	rm -fr $(BUILDDIR)

# -------------------------

.PHONY: install clean full_clean
install clean full_clean:
	$(MAKE)  -C Libraries  PREFIX=$(PREFIX)  $@
	$(MAKE)  -C Verilog    PREFIX=$(PREFIX)  $@

clean full_clean: rem_inst rem_build

# -------------------------
