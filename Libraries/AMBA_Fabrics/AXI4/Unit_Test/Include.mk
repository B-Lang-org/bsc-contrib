# This is a common 'include' Makefile for the other Makefiles

help:
	@echo "Targets:"
	@echo "  b_all        = b_compile  b_link  b_sim    (for Bluesim)"
	@echo "  v_all        = v_compile  v_link  v_sim    (for VSIM)"
	@echo "  Define  VSIM = <verilog simulator>: verilator, iverilog, ..."
	@echo "  Current VSIM = $(VSIM)"

b_all:	 b_compile  b_link  b_sim
v_all:	 v_compile  v_link  v_sim

TOPFILE   ?= Test_AXI4_Fabric.bsv

# ****************************************************************

TOPMODULE ?= mkTop
EXEFILE_BSIM ?= exe_HW_bsim
EXEFILE_VSIM ?= exe_HW_vsim

BSCFLAGS += -keep-fires
BSCFLAGS += -opt-undetermined-vals
BSCFLAGS += -unspecified-to X
BSCFLAGS += -check-assert

#	-show-range-conflict \
#	-aggressive-conditions \
#	-no-warn-action-shadowing \
#	-no-inline-rwire \
#	-show-schedule \

BSC_C_FLAGS += \
	-Xc++  -D_GLIBCXX_USE_CXX11_ABI=0 \
	-Xl -v \
	-Xc -O3 -Xc++ -O3

# ****************************************************************
# Common BSC PATH

BSCPATH := ..
BSCPATH := $(BSCPATH):$(HOME)/Git/BSV_Additional_Libs/src
BSCPATH := $(BSCPATH):+

# ****************************************************************
# FOR BLUESIM

BSCDIRS_BSIM  = -simdir build_bsim -bdir build -info-dir build
BSCPATH_BSIM  = $(BSCPATH)

build_bsim:
	mkdir -p $@

build:
	mkdir -p $@

.PHONY: b_compile
b_compile: build_bsim build
	@echo Compiling for Bluesim ...
	bsc -u -sim $(BSCDIRS_BSIM)  $(BSCFLAGS)  -p $(BSCPATH_BSIM)  $(TOPFILE)
	@echo Compilation for Bluesim finished

.PHONY: b_link
b_link:
	@echo Linking for Bluesim ...
	bsc  -sim  -parallel-sim-link 8\
		$(BSCDIRS_BSIM)  -p $(BSCPATH_BSIM) \
		-e $(TOPMODULE) -o ./$(EXEFILE_BSIM) \
		-keep-fires \
		$(BSC_C_FLAGS)
	@echo Linking for Bluesim finished

.PHONY: b_sim
b_sim:
	@echo Simulation in Bluesim...
	./$(EXEFILE_BSIM)
	@echo Simulation in Bluesim finished

# ****************************************************************
# FOR VERILOG

BSCDIRS_V = -bdir build_v  -info-dir build_v  -vdir verilog

BSCPATH_V = $(BSCPATH)

VSIM ?= verilator
# VSIM ?= iverilog

build_v:
	mkdir -p $@

verilog:
	mkdir -p $@

.PHONY: v_compile
v_compile: build_v verilog
	@echo "Compiling for Verilog (Verilog generation) ..."
	bsc -u -elab -verilog  $(BSCDIRS_V)  $(BSCFLAGS)  -p $(BSCPATH_V)  $(TOPFILE)
	@echo Verilog generation finished

.PHONY: v_link
v_link:
	@echo "Linking for Verilog simulation (simulator: $(VSIM)) ..."
	bsc -verilog  -vsim $(VSIM)  -use-dpi  -keep-fires  $(BSCDIRS_V) \
		-e $(TOPMODULE) -o ./$(EXEFILE_VSIM)
	@echo "Linking for Verilog simulation finished (simulator: $(VSIM))"

.PHONY: v_sim
v_sim:
	@echo Verilog simulation ...
	./$(EXEFILE_VSIM)
	@echo Verilog simulation finished

# ****************************************************************

.PHONY: clean
clean:
	rm -f  *~   src_BSV/*~  build/*  build_bsim/*

.PHONY: full_clean
full_clean: clean
	rm -r -f  exe_*  build*  verilog  exe_HW_*

# ****************************************************************
