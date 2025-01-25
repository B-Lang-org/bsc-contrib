PWD:=$(shell pwd)
TOP:=$(PWD)/../..

LIBNAME=Misc

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../common.mk

.PHONY: build
build:
	$(BSC) -u $(BSCFLAGS) CreditCounter.bsv
	$(BSC) -u $(BSCFLAGS) Cur_Cycle.bsv
	$(BSC) -u $(BSCFLAGS) EdgeFIFOFs.bsv
	$(BSC) -u $(BSCFLAGS) GetPut_Aux.bsv
	$(BSC) -u $(BSCFLAGS) Semi_FIFOF.bsv
	$(BSC) -u $(BSCFLAGS) VectorFIFOF.bsv

.PHONY: clean full_clean
clean full_clean:
