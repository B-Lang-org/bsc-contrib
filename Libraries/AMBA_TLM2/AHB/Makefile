PWD:=$(shell pwd)
TOP:=$(PWD)/../../..

LIBNAME=AMBA_TLM2/AHB

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../../common.mk

# Requires files in Bus and TLM
BSCFLAGS += -p $(BUILDDIR)/../../Bus:$(BUILDDIR)/../TLM:+

INSTALLFILES = \
	AHB.pdf \

.PHONY: build
build:
	$(BSC) -u $(BSCFLAGS) $(notdir $(LIBNAME)).bsv

.PHONY: clean full_clean
clean full_clean:

