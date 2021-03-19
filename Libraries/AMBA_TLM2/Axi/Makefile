PWD:=$(shell pwd)
TOP:=$(PWD)/../../..

LIBNAME=AMBA_TLM2/Axi

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../../common.mk

# Requires files in Bus and TLM
BSCFLAGS += -p $(BUILDDIR)/../../Bus:$(BUILDDIR)/../TLM:+

INSTALLFILES = \
	Axi.defines \
	Axi.pdf \

.PHONY: build
build:
	-rm -f $(BUILDDIR)/Axi.defines
	$(BSC) -u $(BSCFLAGS) $(notdir $(LIBNAME)).bsv
	cp $(INSTALLFILES) $(BUILDDIR)

.PHONY: clean full_clean
clean full_clean:

