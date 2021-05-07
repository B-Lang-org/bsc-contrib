PWD:=$(shell pwd)
TOP:=$(PWD)/..

INSTALL?=install -c

PREFIX?=$(TOP)/inst
INSTALLDIR=$(PREFIX)/lib/$(INSTALL_NAME)

INSTALL_NAME = Verilog

# -------------------------

VERI_FILES = \
	ASSIGN1.v \
	ClockGater.v \

.PHONY: install
install:
	$(INSTALL) -m 755 -d $(INSTALLDIR)
	$(INSTALL) -m 644 $(VERI_FILES) $(INSTALLDIR)

.PHONY: clean full_clean
clean full_clean:

# -------------------------
