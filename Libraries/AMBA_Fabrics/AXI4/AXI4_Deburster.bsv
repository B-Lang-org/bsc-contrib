// Copyright (c) 2019-2023 Bluespec, Inc. All Rights Reserved
// Copyright (c) 2024 Rishiyur S. Nikhil.

// SPDX-License-Identifier: BSD-3-Clause

package AXI4_Deburster;

// ================================================================
// This package defines a AXI4-S-to-AXI4-S conversion module.
// The upstream interface (AXI4-S) is an AXI4-S that carries burst transactions.
// The module argument is the downstream interface, also an AXI4-S,
//    which does not have bursts.
// i.e., a multi-beat burst request from upstream is sent to the
// downstream as a series of 1-beat requests.

// ================================================================
// Bluespec library imports

import Vector       :: *;
import FIFOF        :: *;
import SpecialFIFOs :: *;
import ConfigReg    :: *;

// ----------------
// Bluespec misc. libs

import Cur_Cycle  :: *;
import Semi_FIFOF :: *;

// ----------------
// Project imports

import AXI4_Types   :: *;

// ****************************************************************
// Verbosity during simulation on stdout (edit this as desired):
//   0: quiet
//   1: display start of burst
//   2: display detail

Integer verbosity = 0;

// ****************************************************************
// The Deburster module

module mkAXI4_Deburster #(AXI4_S_IFC #(wd_id, wd_addr, wd_data, wd_user) ifc_S)
                        (AXI4_S_IFC #(wd_id, wd_addr, wd_data, wd_user))
   provisos (Add #(a__, 8, wd_addr));

   // Buffer facing M
   AXI4_Buffer_IFC #(wd_id, wd_addr, wd_data, wd_user) xactor_from_M <- mkAXI4_Buffer;

   // ----------------
   // Write-transaction book-keeping

   // This reg is W-channel burst beat count (0 => start of burst)
   Reg #(AXI4_Len) rg_w_beat_count <- mkReg (0);

   // Records awlen.
   // Size of FIFO should cover S latency (because used on B to
   // combine B responses).
   FIFOF #(AXI4_Len)  f_w_awlen <- mkSizedFIFOF (4);

   // This reg is the B-channel burst beat count which is the number
   // of individual (non-burst) responses from the S to be combined
   // into a single burst response to M. (0 => ready for next burst)
   Reg #(AXI4_Len) rg_b_beat_count <- mkReg (0);

   // All individual S responses may not have the same 'resp' on the B
   // channel. This reg remembers first 'non-okay' resp (if any), to
   // be returned to M in the burst response.
   Reg #(AXI4_Resp) rg_b_resp <- mkReg (axi4_resp_okay);

   // ----------------
   // Read-transaction book-keeping

   // Records arlen for S.
   // Size of FIFO should cover S latency (because used on R to
   // combine R-response into a burst).
   FIFOF #(AXI4_Len)  f_r_arlen <- mkSizedFIFOF (4);

   // This reg is the AR-channel burst beat count (0 => start of next burst)
   Reg #(AXI4_Len) rg_ar_beat_count <- mkReg (0);

   // This reg is the R-channel burst beat count (0 => ready for next burst)
   Reg #(AXI4_Len) rg_r_beat_count <- mkReg (0);

   // ----------------------------------------------------------------
   // Compute axaddr for beat

   function Bit #(wd_addr) fv_axaddr_for_beat (Bit #(wd_addr) start_addr,
					       AXI4_Size      axsize,
					       AXI4_Burst     axburst,
					       AXI4_Len       axlen,
					       AXI4_Len       beat_count);

      // For incrementing bursts this address is the next address
      Bit #(wd_addr) addr = start_addr;
      addr = start_addr + (1 << pack (axsize));

      // The actual length of the burst is one more than indicated by axlen
      Bit #(wd_addr) burst_len = zeroExtend (axlen) + 1;

      // Compute the mask used to wrap the address, given that burst lenths are
      // always powers of two
      Bit #(wd_addr) wrap_mask = (burst_len << pack (axsize)) - 1;

      // For wrapping bursts the wrap_mask needs to be applied to wrap the
      // address round when it reaaches the boundary
      if (axburst == axburst_wrap) begin
         addr = (start_addr & (~ wrap_mask)) | (addr & wrap_mask);
      end
      return addr;
   endfunction

   // ================================================================
   // BEHAVIOR

   // ----------------
   // AW and W channels (write requests)

   Reg #(Bit #(wd_addr)) rg_last_beat_waddr <- mkRegU;

   rule rl_AW_W;
      AXI4_AW #(wd_id, wd_addr, wd_user) aw_in = xactor_from_M.ifc_M.o_AW.first;
      AXI4_W  #(wd_data, wd_user)        w_in  = xactor_from_M.ifc_M.o_W.first;

      // Construct output AW item
      let aw_out = aw_in;
      // For the first beat the address is unchanged from the address
      // in the input request, for the remaining beats the address is
      // based on the previous address used
      if (rg_w_beat_count != 0)
         aw_out.awaddr = fv_axaddr_for_beat (rg_last_beat_waddr,
					     aw_in.awsize,
					     aw_in.awburst,
					     aw_in.awlen,
					     rg_w_beat_count);

      aw_out.awlen   = 0;
      aw_out.awburst = axburst_fixed; // Not necessary when awlen=1, but S may be finicky

      // Set WLAST to true since this is always last beat of outgoing xaction (awlen=1)
      let w_out   = w_in;
      w_out.wlast = True;

      // Send to S
      ifc_S.i_AW.enq (aw_out);
      ifc_S.i_W.enq  (w_out);

      xactor_from_M.ifc_M.o_W.deq;

      // Remember burst length so that individual responses from S can
      // be combined into a single burst response to M.

      if (rg_w_beat_count == 0)
	 f_w_awlen.enq (aw_in.awlen);

      if (rg_w_beat_count < aw_in.awlen) begin
	 rg_w_beat_count <= rg_w_beat_count + 1;
      end
      else begin
	 // Last beat of incoming burst; done with AW item
	 xactor_from_M.ifc_M.o_AW.deq;
	 rg_w_beat_count <= 0;

	 // Simulation-only assertion-check (no action, just display assertion failure)
	 // Last incoming beat must have WLAST = 1
	 if (! w_in.wlast) begin
	    $display ("%0d: ERROR: AXI4_Deburster.rl_AW_W: m -> s",
		      cur_cycle);
	    $display ("    WLAST not set on last data beat (awlen = %0d)", aw_in.awlen);
	    $display ("    ", fshow (w_in));
	 end
      end

      // Remember this beat's address for calculating the next beat address.
      // This is necessary to support wrapping bursts
      rg_last_beat_waddr <= aw_out.awaddr;

      // Debugging
      if (verbosity > 0) begin
	 $display ("%0d: AXI4_Deburster.rl_AW_W: m -> s, beat %0d",
		   cur_cycle, rg_w_beat_count);
	 if (rg_w_beat_count == 0)
	    $display ("    aw_in : ", fshow (aw_in));
	 if ((rg_w_beat_count == 0) || (verbosity > 1)) begin
	    $display ("    w_in :  ", fshow (w_in));
	    $display ("    aw_out: ", fshow (aw_out));
	    $display ("    w_out:  ", fshow (w_out));
	 end
      end
   endrule: rl_AW_W

   // ----------------
   // B channel (write responses): consume responses from until the
   // last response for a burst, then respond to M.  Remember if any
   // of them was not an 'okay' response.

   rule rl_B_S_to_M;
      AXI4_B #(wd_id, wd_user) b_in <- pop_o (ifc_S.o_B);

      if (rg_b_beat_count < f_w_awlen.first) begin
	 // Remember first non-okay response (if any) of a burst in rg_b_resp
	 if ((rg_b_resp == axi4_resp_okay) && (b_in.bresp != axi4_resp_okay))
	    rg_b_resp <= b_in.bresp;

	 // not last beat of burst
	 rg_b_beat_count <= rg_b_beat_count + 1;

	 if (verbosity > 1) begin
	    $display ("%0d: AXI4_Deburster.rl_B_S_to_M: m <- s, beat %0d",
		      cur_cycle, rg_b_beat_count);
	    $display ("    Consuming and discarding beat %0d", rg_b_beat_count);
	    $display ("    ", fshow (b_in));
	 end
      end
      else begin
	 // Last beat of burst
	 let b_out = b_in;
	 if (rg_b_resp != axi4_resp_okay)
	    b_out.bresp = rg_b_resp;
	 xactor_from_M.ifc_M.i_B.enq (b_out);

	 f_w_awlen.deq;

	 // Get ready for next burst
	 rg_b_beat_count <= 0;
	 rg_b_resp       <= axi4_resp_okay;

	 if (verbosity > 1) begin
	    $display ("%0d: AXI4_Deburster.rl_B_S_to_M: m <- s, beat %0d",
		      cur_cycle, rg_b_beat_count);
	    $display ("    b_in: ",  fshow (b_in));
	    $display ("    b_out: ", fshow (b_out));
	 end
      end
   endrule

   // ----------------
   // AR channel (read requests)

   Reg #(Bit #(wd_addr)) rg_last_beat_raddr <- mkRegU;
   rule rl_rd_xaction_M_to_S;
      AXI4_AR #(wd_id, wd_addr, wd_user) ar_in = xactor_from_M.ifc_M.o_AR.first;

      // Compute forwarded request for each beat, and send
      let ar_out = ar_in;

      // For the first beat the address is unchanged from the address in the
      // input request, for the remaining beats we have the update the address
      // based on the previous address used
      if (rg_ar_beat_count != 0) begin
         ar_out.araddr = fv_axaddr_for_beat (rg_last_beat_raddr,
					     ar_in.arsize,
					     ar_in.arburst,
					     ar_in.arlen,
					     rg_ar_beat_count);
      end

      ar_out.arlen   = 0;
      ar_out.arburst = axburst_fixed; // Not necessary when arlen=1, but S may be finicky
      ifc_S.i_AR.enq (ar_out);

      // On first beat, set up the response count
      if (rg_ar_beat_count == 0)
	 f_r_arlen.enq (ar_in.arlen);

      if (rg_ar_beat_count < ar_in.arlen) begin
	 rg_ar_beat_count <= rg_ar_beat_count + 1;
      end
      else begin
	 // Last beat sent; done with AR item
	 xactor_from_M.ifc_M.o_AR.deq;
	 rg_ar_beat_count <= 0;
      end

      // Remember this beat's address for calculating the next beat address.
      // This is necessary to support wrapping bursts
      rg_last_beat_raddr <= ar_out.araddr;

      // Debugging
      if (verbosity > 0) begin
	 $display ("%0d: AXI4_Deburster.rl_rd_xaction_M_to_S: m -> s, addr %08x beat %0d",
		   cur_cycle, ar_out.araddr, rg_ar_beat_count);
	 if (rg_ar_beat_count == 0)
	    $display ("    ar_in:  ", fshow (ar_in));
	 if ((rg_ar_beat_count == 0) || (verbosity > 1))
	    $display ("    ar_out: ", fshow (ar_out));
      end

   endrule: rl_rd_xaction_M_to_S

   // ----------------
   // Rd responses

   rule rl_rd_resp_S_to_M;
      AXI4_R #(wd_id, wd_data, wd_user) r_in <- pop_o (ifc_S.o_R);
      let arlen = f_r_arlen.first;

      let r_out = r_in;
      if (rg_r_beat_count < arlen) begin
	 // not last beat of burst
	 r_out.rlast = False;
	 rg_r_beat_count <= rg_r_beat_count + 1;
      end
      else begin
	 // Last beat of burst
	 rg_r_beat_count <= 0;
	 r_out.rlast = True;    // should be set already, but override if not
	 f_r_arlen.deq;
      end

      xactor_from_M.ifc_M.i_R.enq (r_out);

      // Debugging
      if (verbosity > 0) begin
	 $display ("%0d: AXI4_Deburster.rl_rd_resp_S_to_M: m <- s, beat %0d",
		   cur_cycle, rg_r_beat_count);
	 if ((rg_r_beat_count == 0) || (verbosity > 1)) begin
	    $display ("    r_in:  ", fshow (r_in));
	    $display ("    r_out: ", fshow (r_out));
	 end
      end
   endrule: rl_rd_resp_S_to_M

   // ****************************************************************
   // INTERFACE

   return xactor_from_M.ifc_S;
endmodule

// ****************************************************************

endpackage: AXI4_Deburster
