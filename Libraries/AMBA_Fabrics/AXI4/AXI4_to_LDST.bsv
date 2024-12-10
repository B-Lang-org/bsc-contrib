// Copyright (c) 2021-2024 Rishiyur S. Nikhil and Bluespec, Inc. All Rights Reserved

// SPDX-License-Identifier: BSD-3-Clause

package AXI4_to_LDST;

// ================================================================
// This package defines module mkAXI4_to_LDST and its interface.
// The module's argment is an AXI4_M_IFC from some upstream M.
// It does not accept bursts (use a Deburster in front, if needed).

// The module's interface has 4 FIFOs for LO/ST requests and responses.
// Load and store requests
// - have a width (B/H/W/D) for 1/2/4/8 bytes (but limited to wd_axi_data)
// - addresses are properly aligned (lsbs are 0 for H, 00 for W and 000 for D)
// - data are always in LSBS no matter the address (unlike AXI4's lane-alignment)
// - wd_axi_dat  must be >= wd_ldst_data
// - This module 'slices' the axi4_S data (width wd_axi_data)
//     into slices of width wd_ldst_data for the load/store data bus.

// Terminology:
//   POT                    power of two
//   NAPOT                  naturally aligned power of two
//   wd_...                 width in bits
//   wdB_...                width in bytes
//   wd_...                 width as a type (numeric kind)
//   wd_..._I               width as an Integer value
//   wd_..._B               width as a Bit #(n) value

//   wd_axi_data            width of AXI4 data bus
//   wd_ldst_data           width of load-store data bus
//   slice                  NAPOT slice of axi wdata/rdata, of width wd_ldst_data
//   slices_per_axi_data    number of wd_ldst_data slices in wd_axi_data
//   szwindow               NAPOT window of size specified by AWSIZE, containing AWADDR

// ****************************************************************

export ldst_b, ldst_h, ldst_w, ldst_d;
export AXI4_to_LDST_IFC (..);
export mkAXI4_to_LDST;

// ================================================================
// Bluespec library imports

import Vector       :: *;
import FIFOF        :: *;

// ----------------
// Bluespec misc. libs

import Cur_Cycle  :: *;
import Semi_FIFOF :: *;

// ================
// Local imports

import AXI4_Types         :: *;
import AXI4_to_LDST_utils :: *;
import AXI4_to_LD         :: *;
import AXI4_to_ST         :: *;

// ****************************************************************
// The interface for the module

interface AXI4_to_LDST_IFC #(numeric type wd_id,
			     numeric type wd_addr,
			     numeric type wd_axi_data,
			     numeric type wd_user,
			     numeric type wd_ldst_data);
   // Stores
   interface FIFOF_O #(Tuple3 #(Bit #(2),                // width B/H/W/D
				Bit #(wd_addr),          // addr
				Bit #(wd_ldst_data)))    // wdata
             st_reqs;

   interface FIFOF_I #(Bool)    // True <=> err
             st_rsps;

   // Loads
   interface FIFOF_O #(Tuple2 #(Bit #(2),           // width B/H/W/D
				Bit #(wd_addr)))    // addr
             ld_reqs;

   interface FIFOF_I #(Tuple2 #(Bool,                      // True <=> err
				Bit #(wd_ldst_data)))    // rdata
             ld_rsps;
endinterface

// ================================================================
// The module (uses separate modules, below, for Load and Store, respectively

module mkAXI4_to_LDST #(AXI4_M_IFC #(wd_id, wd_addr, wd_axi_data, wd_user) ifc_M)
                      (AXI4_to_LDST_IFC #(wd_id,
					  wd_addr,
					  wd_axi_data,
					  wd_user,
					  wd_ldst_data))

   provisos (Add #(a__,           8,                   wd_addr),

	     Mul #(wd_ldst_data,  slices_per_axi_data, wd_axi_data),

	     Mul #(wdB_axi_data,  8,                   wd_axi_data),
	     // bsc demands this next proviso though it seems redundant
	     // (maybe not redundant due to integer div?)
	     Div #(wd_axi_data,   8,                   wdB_axi_data),

             Mul #(wdB_ldst_data, 8,                   wd_ldst_data),

	     // Redundant, but bsc doesn't work it out
	     Mul #(wdB_ldst_data, slices_per_axi_data, wdB_axi_data),

	     Add #(b__,           TLog #(TAdd #(1, wdB_ldst_data)), 8)
	     );

   // Store converter
   AXI4_to_ST_IFC #(wd_addr, wd_ldst_data)
   st_ifc <- mkAXI4_to_ST (ifc_M.o_AW, ifc_M.o_W, ifc_M.i_B);

   // Load converter
   AXI4_to_LD_IFC #(wd_addr, wd_ldst_data)
   ld_ifc <- mkAXI4_to_LD (ifc_M.o_AR, ifc_M.i_R);

   // ----------------------------------------------------------------
   // INTERFACE

   interface st_reqs = st_ifc.reqs;
   interface st_rsps = st_ifc.rsps;

   interface ld_reqs = ld_ifc.reqs;
   interface ld_rsps = ld_ifc.rsps;
endmodule

// ================================================================

endpackage: AXI4_to_LDST
