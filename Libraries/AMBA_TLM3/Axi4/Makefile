PWD:=$(shell pwd)
TOP:=$(PWD)/../../..

LIBNAME=AMBA_TLM3/Axi4

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../../common.mk

# Requires files in Bus, TLM3, and Axi
BSCFLAGS += -p $(BUILDDIR)/../../Bus:$(BUILDDIR)/../TLM3:$(BUILDDIR)/../Axi:+

.PHONY: build
build:
	$(BSC) -u $(BSCFLAGS) $(notdir $(LIBNAME)).bsv

.PHONY: clean full_clean
clean full_clean:

