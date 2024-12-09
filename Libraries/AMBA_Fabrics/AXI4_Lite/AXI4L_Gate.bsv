// Copyright (c) 2021-2023 Bluespec, Inc. All Rights Reserved
//
// SPDX-License-Identifier: BSD-3-Clause
// Author: Rishiyur S. Nikhil

package AXI4L_Gate;

// ================================================================
// This package defines an AXI4-M-to-AXI4-S 'gate' module,
// that either allows or blocks the 5 AXI4 channels,
// depending on a Bool 'enable' input.

// An optional Bool module parameter controls whether, when the gate
// is disabled, whether to justs block traffic or respond to M with
// errors.

// ================================================================
// Bluespec library imports

import Vector       :: *;
import FIFOF        :: *;

// ----------------
// Bluespec misc. libs

import Cur_Cycle  :: *;
import GetPut_Aux :: *;
import Semi_FIFOF :: *;

// ================================================================
// Project imports

import AXI4L_Types :: *;

// ================================================================
// The interface for the gate module

interface AXI4L_Gate_IFC #(numeric type wd_addr_t,
			   numeric type wd_data_t,
			   numeric type wd_user_t);
   // From M
   interface AXI4L_S_IFC #(wd_addr_t, wd_data_t, wd_user_t) axi4L_S;
   // To S
   interface AXI4L_M_IFC #(wd_addr_t, wd_data_t, wd_user_t) axi4L_M;

   // Enable control signal. Continuously driven with Bool arg.
   (* always_ready, always_enabled *)
   method Action m_enable (Bool enabled);
endinterface

// ================================================================
// The Gate module

Integer verbosity = 0;

module mkAXI4L_Gate
   #(Bool respond_with_err)    // False: block traffic; True: respond with err
   (AXI4L_Gate_IFC #(wd_addr_t, wd_data_t, wd_user_t));

   // ----------------
   // Transactor facing M
   AXI4L_S_Xactor_IFC  #(wd_addr_t, wd_data_t, wd_user_t)
      xactor_from_M <- mkAXI4L_S_Xactor;

   // Transactor facing S
   AXI4L_M_Xactor_IFC #(wd_addr_t, wd_data_t, wd_user_t)
       xactor_to_S <- mkAXI4L_M_Xactor;

   Reg #(Bool) rg_enabled <- mkReg (False);

   // ----------------------------------------------------------------
   // BEHAVIOR

   // ----------------
   // When gate is enabled: pass-through everything M-to-S and S-to-M

   rule rl_wr_addr (rg_enabled);
      let wra <- pop_o (xactor_from_M.o_wr_addr);
      xactor_to_S.i_wr_addr.enq (wra);
   endrule

   rule rl_wr_data (rg_enabled);
      let wrd <- pop_o (xactor_from_M.o_wr_data);
      xactor_to_S.i_wr_data.enq (wrd);
   endrule

   rule rl_wr_resp (rg_enabled);
      let wrr <- pop_o (xactor_to_S.o_wr_resp);
      xactor_from_M.i_wr_resp.enq (wrr);
   endrule

   rule rl_rd_addr (rg_enabled);
      let rda <- pop_o (xactor_from_M.o_rd_addr);
      xactor_to_S.i_rd_addr.enq (rda);
   endrule

   rule rl_rd_data (rg_enabled);
      let rdd <- pop_o (xactor_to_S.o_rd_data);
      xactor_from_M.i_rd_data.enq (rdd);
   endrule

   // ----------------
   // When gate is disabled: return error responses to M;
   //     don't send anything to S or expect anything from S.

   rule rl_wr_addr_disabled (respond_with_err && (! rg_enabled));
      let wra <- pop_o (xactor_from_M.o_wr_addr);
      let wrr = AXI4L_Wr_Resp {bresp: AXI4L_SLVERR,
			       buser: wra.awuser};
      xactor_from_M.i_wr_resp.enq (wrr);

      $display ("WARNING: rl_wr_addr_disabled: rec'd wr request from M when gate disabled.");
      $display ("    ", fshow (wra));
      $display ("    %0d: Returning error response.", cur_cycle);
   endrule

   rule rl_wr_data_disabled (respond_with_err && (! rg_enabled));
      let wrd <- pop_o (xactor_from_M.o_wr_data);
      // Discard the data
   endrule

   rule rl_wr_resp_disabled_drain_S (respond_with_err && (! rg_enabled));
      let wrr <- pop_o (xactor_to_S.o_wr_resp);
      $display ("WARNING: rl_wr_resp_disabled: rec'd wr resp from S when gate disabled; ignoring");
      $display ("    %0d: (there couldn't have been a request)", cur_cycle);
   endrule

   rule rl_rd_addr_disabled (respond_with_err && (! rg_enabled));
      let rda <- pop_o (xactor_from_M.o_rd_addr);
      let rdd = AXI4L_Rd_Data {rresp: AXI4L_SLVERR,
			       rdata: ?,
			       ruser: rda.aruser};
      xactor_from_M.i_rd_data.enq (rdd);

      $display ("WARNING: rl_rd_addr_disabled: rec'd rd request from M when gate disabled.");
      $display ("    ", fshow (rda));
      $display ("    %0d: Returning error response.", cur_cycle);
   endrule

   rule rl_rd_data_disabled_drain_S (respond_with_err && (! rg_enabled));
      let rdd <- pop_o (xactor_to_S.o_rd_data);
      $display ("WARNING: rl_rd_data_disabled: rec'd rd resp from S when gate disabled; ignoring");
      $display ("    %0d: (there couldn't have been a request)", cur_cycle);
   endrule

   // ----------------------------------------------------------------
   // INTERFACE

   interface axi4L_S = xactor_from_M.axi_side;
   interface axi4L_M = xactor_to_S  .axi_side;

   method Action m_enable (Bool enabled);
      if (enabled && (! rg_enabled) && (verbosity != 0))
	 $display ("%0d: AXI4L ENABLING", cur_cycle);
      else if ((! enabled) && rg_enabled && (verbosity != 0))
	 $display ("%0d: AXI4L DISABLING", cur_cycle);

      rg_enabled <= enabled;
   endmethod
endmodule

// ================================================================

endpackage: AXI4L_Gate
