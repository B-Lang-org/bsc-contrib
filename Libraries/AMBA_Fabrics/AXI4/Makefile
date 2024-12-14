PWD:=$(shell pwd)
TOP:=$(PWD)/../../..

LIBNAME=AMBA_Fabrics/AXI4

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../../common.mk

# Requires files in Misc and Utils
BSCFLAGS += -p $(BUILDDIR)/../../Misc:+
BSCFLAGS += -p $(BUILDDIR)/../Utils:+

.PHONY: build
build:
	$(BSC) -u $(BSCFLAGS) AXI4_Types.bsv
	$(BSC) -u $(BSCFLAGS) AXI4_BSV_RTL.bsv
	$(BSC) -u $(BSCFLAGS) AXI4_Mem_Model.bsv
	$(BSC) -u $(BSCFLAGS) AXI4_to_LD.bsv
	$(BSC) -u $(BSCFLAGS) AXI4_to_LDST.bsv
	$(BSC) -u $(BSCFLAGS) AXI4_to_LDST_utils.bsv
	$(BSC) -u $(BSCFLAGS) AXI4_to_ST.bsv
	$(BSC) -u $(BSCFLAGS) AXI4_Addr_Translator.bsv
	$(BSC) -u $(BSCFLAGS) AXI4_Clock_Crossers.bsv
	$(BSC) -u $(BSCFLAGS) AXI4_Deburster.bsv
	$(BSC) -u $(BSCFLAGS) AXI4_Fabric.bsv
	$(BSC) -u $(BSCFLAGS) AXI4_Gate.bsv
	$(BSC) -u $(BSCFLAGS) AXI4_Widener.bsv

.PHONY: clean full_clean
clean full_clean:
