PWD:=$(shell pwd)
TOP:=$(PWD)/../../..

LIBNAME=AMBA_Fabrics/AXI4_Lite

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../../common.mk

# Requires files in Misc and Utils
BSCFLAGS += -p $(BUILDDIR)/../../Misc:+
BSCFLAGS += -p $(BUILDDIR)/../Utils:+

.PHONY: build
build:
	$(BSC) -u $(BSCFLAGS) AXI4L_ClockCrossing.bsv
	$(BSC) -u $(BSCFLAGS) AXI4L_Clock_Crossers.bsv
	$(BSC) -u $(BSCFLAGS) AXI4L_Gate.bsv
	$(BSC) -u $(BSCFLAGS) AXI4L_Xactors.bsv
	$(BSC) -u $(BSCFLAGS) AXI4L_Fabric.bsv
	$(BSC) -u $(BSCFLAGS) AXI4L_Types.bsv

.PHONY: clean full_clean
clean full_clean:
