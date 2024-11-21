PWD:=$(shell pwd)
TOP:=$(PWD)/../../..

LIBNAME=AMBA_Fabrics/Adapters

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../../common.mk

# Requires files in Misc and AMBA_Fabrics/AXI4 and AMBA_Fabrics/AXI4_Lite
BSCFLAGS += -p $(BUILDDIR)/../../AMBA_Fabrics/AXI4:+ \
	    -p $(BUILDDIR)/../../AMBA_Fabrics/AXI4_Lite:+ \
	    -p $(BUILDDIR)/../../Misc:+

.PHONY: build
build:
	$(BSC) -u $(BSCFLAGS) AXI4L_S_to_AXI4_M_Adapter.bsv
	$(BSC) -u $(BSCFLAGS) AXI4_AXI4L_Adapters.bsv

.PHONY: clean full_clean
clean full_clean:
