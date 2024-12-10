// Copyright (c) 2021-2024 Bluespec, Inc. All Rights Reserved
// Author: Rishiyur S. Nikhil

// SPDX-License-Identifier: BSD-3-Clause

package AXI4_Gate;

// ================================================================
// This package defines a 'gate' module connecting an ifc_M to an ifc_S.
// When driving method 'm_enable(True)'  it passes AXI4 traffic through.
// When driving method 'm_enable(False)' it blocks AXI4 traffic.

// Can be used to control authorized access to an AXI4 connection.

// ================================================================
// Bluespec library imports

import Vector :: *;
import FIFOF  :: *;

// ----------------
// Bluespec misc. libs

import Cur_Cycle  :: *;
import GetPut_Aux :: *;
import Semi_FIFOF :: *;

// ================================================================
// Project imports

import AXI4_Types :: *;

// ================================================================

Integer verbosity = 0;

// ================================================================
// The interface for the gate module

interface AXI4_Gate_IFC #(numeric type wd_id,
			  numeric type wd_addr,
			  numeric type wd_data,
			  numeric type wd_user);
   // Enable control signal. Continuously driven with Bool arg.
   (* always_ready, always_enabled *)
   method Action m_enable (Bool enabled);
endinterface

// ================================================================
// The Gate module
// The Bool parameter: False: just block traffic; True: gen AXI4 err response

module mkAXI4_Gated_Buffer #(Bool respond_with_err,
			     AXI4_M_IFC #(wd_id, wd_addr, wd_data, wd_user) ifc_M,
			     AXI4_S_IFC #(wd_id, wd_addr, wd_data, wd_user) ifc_S)
                           (AXI4_Gate_IFC #(wd_id, wd_addr, wd_data, wd_user));

   Reg #(Bool) rg_enabled      <- mkReg (False);
   Reg #(Bool) rg_enabled_prev <- mkReg (False);

   // ================================================================
   // BEHAVIOR

   // ----------------
   // When gate is enabled: pass-through everything M-to-S and S-to-M

   rule rl_AW (rg_enabled);
      let wra <- pop_o (ifc_M.o_AW);
      ifc_S.i_AW.enq (wra);
   endrule

   rule rl_W (rg_enabled);
      let wrd <- pop_o (ifc_M.o_W);
      ifc_S.i_W.enq (wrd);
   endrule

   rule rl_B (rg_enabled);
      let wrr <- pop_o (ifc_S.o_B);
      ifc_M.i_B.enq (wrr);
   endrule

   rule rl_AR (rg_enabled);
      let rda <- pop_o (ifc_M.o_AR);
      ifc_S.i_AR.enq (rda);
   endrule

   rule rl_R (rg_enabled);
      let rdd <- pop_o (ifc_S.o_R);
      ifc_M.i_R.enq (rdd);
   endrule

   // ----------------
   // When gate is disabled: return error responses to M;
   //     don't send anything to S or expect anything from S.

   rule rl_AW_disabled (respond_with_err && (! rg_enabled));
      let aw <- pop_o (ifc_M.o_AW);
      let b  = AXI4_B {bid:   aw.awid,
		       bresp: axi4_resp_slverr,
		       buser: aw.awuser};
      ifc_M.i_B.enq (b);

      $display ("WARNING: rl_AW_disabled: rec'd wr request from M when gate disabled.");
      $display ("    ", fshow (aw));
      $display ("    %0d: Returning error response.", cur_cycle);
   endrule

   rule rl_W_disabled (respond_with_err && (! rg_enabled));
      let w <- pop_o (ifc_M.o_W);
      // Discard the data
   endrule

   rule rl_B_disabled_drain_S (respond_with_err && (! rg_enabled));
      let b <- pop_o (ifc_S.o_B);
      $display ("WARNING: rl_B_disabled: rec'd wr resp from S when gate disabled; ignoring");
      $display ("    %0d: (there couldn't have been a request)", cur_cycle);
   endrule

   Reg #(Bit #(9)) rg_rd_burst_len <- mkRegU;

   rule rl_AR_disabled (respond_with_err && (! rg_enabled));
      let ar = ifc_M.o_AR.first;

      // Pop this request only after sending burst responses

      // Note: AXI4 decodes burst len = arlen + 1
      rg_rd_burst_len <= zeroExtend (ar.arlen) + 1;

      $display ("WARNING: rl_rd_addr_disabled: rec'd rd request from M when gate disabled.");
      $display ("    ", fshow (ar));
      $display ("    %0d: Returning error response.", cur_cycle);
   endrule

   // Send burst of responses
   rule rl_R_disabled_burst_resps (respond_with_err
				   && (! rg_enabled)
				   && (rg_rd_burst_len != 0));
      let ar = ifc_M.o_AR.first;
      Bit #(wd_data) rdata = ?;
      let r = AXI4_R {rid:   ar.arid,
		      rresp: axi4_resp_slverr,
		      rdata: rdata,
		      rlast: (rg_rd_burst_len == 1),
		      ruser: ar.aruser};
      ifc_M.i_R.enq (r);

      if (r.rlast)
	 // Consume the request
	 ifc_M.o_AR.deq;
      else
	 rg_rd_burst_len <= rg_rd_burst_len - 1;
   endrule

   rule rl_R_disabled_drain_S (respond_with_err && (! rg_enabled));
      let r <- pop_o (ifc_S.o_R);
      $display ("WARNING: rl_R_disabled: rec'd rd resp from S when gate disabled; ignoring");
      $display ("    %0d: (there couldn't have been a request)", cur_cycle);
   endrule

   // ================================================================
   // INTERFACE

   method Action m_enable (Bool enabled);
      if (enabled && (! rg_enabled) && (verbosity != 0))
	 $display ("%0d: AXI4 ENABLING", cur_cycle);
      else if ((! enabled) && rg_enabled && (verbosity != 0))
	 $display ("%0d: AXI4 DISABLING", cur_cycle);

      rg_enabled      <= enabled;
   endmethod
endmodule

// ================================================================

endpackage: AXI4_Gate
