// Copyright (c) 2019-2024 Bluespec, Inc. All Rights Reserved.
// Author: Rishiyur S. Nikhil

// SPDX-License-Identifier: BSD-3-Clause

package AXI4_Mem_Model;

// ****************************************************************
// A memory-model to be used as an S on an AXI4 bus.
// Only partial functionality; to be gradually improved over time.
// Current status:
//     Address and Data bus widths: 64b
//     Bursts:      'fixed' and 'incr' only
//     Size:        Full 64-bit width reads/writes only
//     Strobes:     Not yet handled
//     memory size: See 'mem_size_word64' definition below

// ****************************************************************
// Exports

export mkAXI4_Mem_Model;

// ================================================================
// Bluespec library imports

import RegFile      :: *;
import FIFOF        :: *;
import GetPut       :: *;
import ClientServer :: *;

// ----------------
// Bluespec misc. libs

import GetPut_Aux :: *;
import Semi_FIFOF :: *;

// ================================================================
// Project imports

import AXI4_Types   :: *;

// ****************************************************************
// Simulation verbosity during simulation on stdout for this package (edit as desired)
//   0: quiet
//   1: show transactions, brief
//   2: show transactions, full AXI4 structs

Integer verbosity = 0;

// ****************************************************************

typedef enum { STATE_INIT_0, STATE_INIT_1, STATE_RUNNING } State
deriving (Bits, Eq, FShow);

// ****************************************************************
// IMPLEMENTATION

// "Memory words" (MW) are same bitwidth as AXI4 data bus (wd_data)

module mkAXI4_Mem_Model #(Integer        id,           // Use unique ids for each instance
			  Bit #(wd_addr) addr_base,    // byte addr
			  Bit #(wd_addr) addr_lim,     // byte addr
			  Bool           init_zero,
			  Bool           init_with_memhex,
			  String         memhex_filename,
                          AXI4_M_IFC #(wd_id, wd_addr, wd_data, wd_user) ifc_M)
                        (Empty)
   provisos (Div #(wd_data, 8, wd_data_B),     // see comments on provisos below
	     Log #(wd_data_B, wd_ix_B_in_MW),
	     Add #(wd_addrMW, wd_ix_B_in_MW, wd_addr),
	     Add #(_, 8, wd_addrMW),
	     Mul #(wd_data_B, 8, wd_data));

   // ================================================================
   // Derived constants (some are computed in provisos above)

   // See provisos above for computation of these numeric types:
   //   wd_data_B:     data width in bytes
   //   wd_ix_B_in_MW: bitwidth of index of a byte in a memword
   //   wd_addrMW:     bitwidth of address of a memword

   // Integer values thereof
   Integer i_wd_data_B     = valueOf (wd_data_B);
   Integer i_wd_ix_B_in_MW = valueOf (wd_ix_B_in_MW);

   // memword addr of first memword
   Bit #(wd_addrMW) addrMW_base = truncate (addr_base >> i_wd_ix_B_in_MW);

   // Byte address of byte 0 in first memword
   Bit #(wd_addr)   addr_base_0 = zeroExtend (addrMW_base) << i_wd_ix_B_in_MW;

   // Number of mem words
   Bit #(wd_addrMW) num_MW = truncate ((addr_lim - addr_base_0 - 1 + fromInteger (i_wd_data_B))
				       >>  i_wd_ix_B_in_MW);
   // memword addr just beyond the last memword
   Bit #(wd_addrMW) addrMW_lim = addrMW_base + num_MW;

   // Memory is modeled as a RegFile where each word is full AXI4 data width (wd_data)
   // and indexed by memword addrs
   RegFile #(Bit #(wd_addrMW), Bit #(wd_data))
   regfile <- (init_with_memhex
	  ? mkRegFileLoad (memhex_filename, addrMW_base, addrMW_lim - 1)
	  : mkRegFile     (                 addrMW_base, addrMW_lim - 1));

   Reg #(State) rg_state <- mkReg (STATE_INIT_0);

   // ----------------
   // Check well-formedness of an AXI4 request

   function ActionValue #(Bool) fav_is_well_formed (Bit #(wd_addr)    addr,
						    Bit #(wd_addrMW)  addrMW,
						    AXI4_Len          axlen,
						    AXI4_Size         axsize,
						    AXI4_Burst        axburst);
      actionvalue
	 // Check axsize legal for data bus width
	 Bool ok          = True;
	 Bit #(11) size_b = { fv_AXI4_Size_to_num_bytes (axsize), 3'h0 };
	 if (size_b > fromInteger (valueOf (wd_data))) begin
	    $display ("AXI4_Mem_Model[%0d]: ERROR: axsize > wd_data", id);
	    $display ("    axsize:  %0h (= %d bits)", axsize, size_b);
	    $display ("    wd_data: %0d", valueOf (wd_data));
	    ok = False;
	 end

	 // Check address is not below addr_base
	 if (addr < addr_base) begin
	    $display ("AXI4_Mem_Model[%0d]: ERROR: addr < addr_base", id);
	    $display ("    addr:      0x%0h", addr);
	    $display ("    addr_base: 0x%0h", addr_base);
	    ok = False;
	 end

	 // Check address is not beyond last memory word
	 if (addrMW >= addrMW_lim) begin
	    $display ("AXI4_Mem_Model[%0d]: ERROR: access beyond mem limit", id);
	    $display ("    addr_lim:     0x%0h", addr_lim);
	    ok = False;
	 end

	 // Check that burst mode is supported
	 if (axburst == axburst_wrap) begin
	    $display ("AXI4_Mem_Model[%0d]: ERROR: axburst = wrap; not supported yet.", id);
	    ok = False;
	 end
	 return ok;
      endactionvalue
   endfunction

   // ****************************************************************
   // BEHAVIOR

   rule rl_init (rg_state == STATE_INIT_0);
      $display ("================================");
      $display ("AXI4_Mem_Model[%0d]: initialization", id);

      if (addr_base >= addr_lim) begin
	 $display ("  ERROR: init: addr_base >= addr_lim", id);
	 $display ("    addr_base 0x%0h", addr_base);
	 $display ("    addr_lim  0x%0h", addr_lim);
	 $finish (1);
      end

      // Check legal wd_data (8, 16, 32, 64, 128, 256, 512, or 1024 bits)
      // i.e., exactly one bit should be set in wd[10:3]
      Bit #(11) wd = fromInteger (valueOf (wd_data));  // checks wd_data <= 11'h7FF
      if ((countOnes (wd) != 1) || ((wd & 'b111) != 0)) begin
	 $display ("  ERROR: wd_addr should be 8,16,32,...,1024", id);
	 $display ("    addr_base 0x%0h", addr_base);
	 $display ("    addr_lim  0x%0h", addr_lim);
	 $finish (1);
      end

      $display ("    addr_base:  0x%0h  addr_lim:  0x%0h (byte addrs)",
		addr_base,   addr_lim);
      $display ("    addrMW_base:0x%0h  addrMW_lim:0x%0h (word addrs)",
		addrMW_base, addrMW_lim);
      $display ("    AXI4 params: wd_id:%0d  wd_addr:%0d  wd_data:%0d  wd_user:%0d",
		valueOf (wd_id), valueOf (wd_addr),
		valueOf (wd_data), valueOf (wd_user));
      $display ("    Memory contains %0d words, each wd_data bits (%0d bytes) wide",
		num_MW, i_wd_data_B);

      if (init_zero) begin
	 $display ("    Zeroing memory");
	 rg_state <= STATE_INIT_1;
      end
      else begin
	 if (init_with_memhex)
	    $display ("    Loading from memhex file %s: ", memhex_filename);
	 else
	    $display ("    Memory contents not initialized");
	 rg_state <= STATE_RUNNING;
      end
      $display ("================================");
   endrule

   // Iterate through memory, writing zeroes
   Reg #(Bit #(wd_addrMW)) rg_addrMW <- mkReg (addrMW_base);

   rule rl_init_mem (rg_state == STATE_INIT_1);
      regfile.upd (rg_addrMW, 0);
      if (rg_addrMW != (addrMW_lim - 1))
	 rg_addrMW <= rg_addrMW + 1;
      else begin
	 $display ("AXI4_Mem_Model[%0d]: zero'd memory", id);
	 rg_state <= STATE_RUNNING;
      end
   endrule

   // ================================================================
   // Read requests
   // TODO: on a bad addr (or other error), does AXI4 specs say to return 'burst-len'
   //       err responses or just one?

   Reg #(Bit #(8)) rg_R_beat <- mkReg (0);

   // Recv request on RD_ADDR bus
   // Send burst responses on RD_DATA bus
   rule rl_AR (rg_state == STATE_RUNNING);
      let ar  = ifc_M.o_AR.first;

      Bit #(wd_addrMW) addrMW = truncateLSB (ar.araddr);
      if (ar.arburst == axburst_incr)
	 addrMW = addrMW + zeroExtend (rg_R_beat);

      Bool ok <- fav_is_well_formed (ar.araddr, addrMW, ar.arlen, ar.arsize, ar.arburst);

      if (! ok) begin
	 $display ("AXI4_Mem_Model[%0d]: ERROR: AR is not well-formed", id);
	 $display ("    ", fshow_AR (ar));
      end

      let last = (rg_R_beat == ar.arlen);

      let data = (ok ? regfile.sub (addrMW) : 0);

      AXI4_R #(wd_id, wd_data, wd_user)
      r = AXI4_R {rid:   ar.arid,
		  rdata: data,
		  rresp: (ok ? axi4_resp_okay : axi4_resp_slverr),
		  rlast: last,
		  ruser: ar.aruser};
      ifc_M.i_R.enq (r);

      if (last) begin
	 ifc_M.o_AR.deq;
	 rg_R_beat <= 0;
      end
      else
	 rg_R_beat <= rg_R_beat + 1;

      if (verbosity != 0) begin
	 $display ("AXI4_Mem_Model[%0d]: rl_AR", id);
	 $display ("    ", fshow_AR (ar));
	 $display ("    ", fshow_R  (r));
	 $display ("    memword addr 0x%0h beat %0d ", addrMW, rg_R_beat);
      end
   endrule

   // ================================================================
   // Write requests

   Reg #(Bit #(8)) rg_W_beat <- mkReg (0);

   // Recv request on AW bus and burst data on W bus,
   // send final response on B bus
   rule rl_AW_W (rg_state == STATE_RUNNING);
      let aw  = ifc_M.o_AW.first;
      let w  <- pop_o (ifc_M.o_W);

      Bit #(wd_addrMW) addrMW = truncateLSB (aw.awaddr);
      if (aw.awburst == axburst_incr)
	 addrMW = addrMW + zeroExtend (rg_W_beat);

      Bool ok <- fav_is_well_formed (aw.awaddr, addrMW, aw.awlen, aw.awsize, aw.awburst);

      if (! ok) begin
	 $display ("AXI4_Mem_Model[%0d]: ERROR: AW is not well-formed", id);
	 $display ("    ", fshow_AW (aw));
      end

      let last = (rg_W_beat == aw.awlen);

      Bit #(wd_data) mask = fn_strb_to_bitmask (w.wstrb);

      // Read-modify-write the memword using AXI4 memword and strobe
      if (ok) begin
	 let old_mw = regfile.sub (addrMW);
	 let new_mw = (old_mw & (~ mask)) | (w.wdata & mask);
	 regfile.upd (addrMW, new_mw);
      end

      if (last) begin
	 AXI4_B #(wd_id, wd_user) b = AXI4_B {bid:   aw.awid,
					      bresp: (ok ? axi4_resp_okay
						      : axi4_resp_slverr),
					      buser: aw.awuser};
	 ifc_M.i_B.enq (b);
	 ifc_M.o_AW.deq;
	 rg_W_beat <= 0;
	 if (verbosity != 0)
	    $display ("    ", fshow_B (b));
      end
      else
	 rg_W_beat <= rg_W_beat + 1;

      if (verbosity != 0) begin
	 $write ("AXI4_Mem_Model[%0d]: rl_AW_W", id);
	 $display ("    ", fshow_AW (aw));
	 $display ("    ", fshow_W (w));
	 $display ("    memword addr 0x%0h beat %0d ", addrMW, rg_W_beat);
      end
   endrule

   // ****************************************************************
   // INTERFACE

   // Empty
endmodule

// ****************************************************************

endpackage
