PWD:=$(shell pwd)
TOP:=$(PWD)/../../..

LIBNAME=AMBA_TLM3/TLM3

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../../common.mk

# Requires files in Bus
BSCFLAGS += -p $(BUILDDIR)/../../Bus:+

INSTALLFILES = \
	ram_init.text \
	SYN.defines \
	TLM.defines \

.PHONY: build
build:
	-rm -f $(BUILDDIR)/TLM.defines
	$(BSC) -u $(BSCFLAGS) $(notdir $(LIBNAME)).bsv
	cp $(INSTALLFILES) $(BUILDDIR)

.PHONY: clean full_clean
clean full_clean:

