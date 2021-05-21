PWD:=$(shell pwd)
TOP:=$(PWD)/../../..

LIBNAME=FPGA/Xilinx

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../../common.mk

# Requires files in Misc
BSCFLAGS += -p $(BUILDDIR)/../Misc:+

.PHONY: build
build:
	$(BSC) -u $(BSCFLAGS) $(notdir $(LIBNAME)).bsv

.PHONY: clean full_clean
clean full_clean:

