PWD:=$(shell pwd)
TOP:=$(PWD)/../../..

LIBNAME=AMBA_Fabrics/Utils

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../../common.mk

# Requires files in Misc in Utils
BSCFLAGS += -p $(BUILDDIR)/../../Misc:+
BSCFLAGS += -p $(BUILDDIR)/../Utils:+

.PHONY: build
build:
	$(BSC) -u $(BSCFLAGS) ByteLane.bsv
	$(BSC) -u $(BSCFLAGS) AXIx_SyncBuffer.bsv

.PHONY: clean full_clean
clean full_clean:
