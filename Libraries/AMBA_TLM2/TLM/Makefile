PWD:=$(shell pwd)
TOP:=$(PWD)/../../..

LIBNAME=AMBA_TLM2/TLM

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../../common.mk

# TLM2 requires files in Bus
BSCFLAGS += -p $(BUILDDIR)/../../Bus:+

INSTALLFILES = \
	ram_init.text \
	TLM.defines \
	TLM.pdf \

.PHONY: build
build:
	-rm -f $(BUILDDIR)/TLM.defines
	$(BSC) -u $(BSCFLAGS) TLM.bsv
	$(BSC) -u $(BSCFLAGS) TLM2.bsv
	cp $(INSTALLFILES) $(BUILDDIR)

.PHONY: clean full_clean
clean full_clean:

