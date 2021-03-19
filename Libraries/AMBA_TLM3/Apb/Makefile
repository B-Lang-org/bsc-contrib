PWD:=$(shell pwd)
TOP:=$(PWD)/../../..

LIBNAME=AMBA_TLM3/Apb

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../../common.mk

# Requires files in Bus and TLM3
BSCFLAGS += -p $(BUILDDIR)/../../Bus:$(BUILDDIR)/../TLM3:+

INSTALLFILES = \
	Apb.defines \

.PHONY: build
build:
	$(BSC) -u $(BSCFLAGS) $(notdir $(LIBNAME)).bsv
	cp $(INSTALLFILES) $(BUILDDIR)

.PHONY: clean full_clean
clean full_clean:

