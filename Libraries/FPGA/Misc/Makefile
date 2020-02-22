PWD:=$(shell pwd)
TOP:=$(PWD)/../../..

LIBNAME=FPGA/Misc

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../../common.mk

.PHONY: build
build:
	$(BSC) -u $(BSCFLAGS) FPGA_Misc.bsv

.PHONY: clean full_clean
clean full_clean:

