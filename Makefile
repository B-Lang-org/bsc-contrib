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

.PHONY: install
install:
	$(MAKE)  -C Libraries  PREFIX=$(PREFIX)  install

# -------------------------

clean: rem_inst rem_build
	-$(MAKE)  -C Libraries  clean

full_clean: rem_inst rem_build
	-$(MAKE)  -C Libraries  full_clean

# -------------------------
