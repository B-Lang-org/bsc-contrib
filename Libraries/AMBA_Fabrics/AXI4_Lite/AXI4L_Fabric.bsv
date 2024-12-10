// Copyright (c) 2013-2023 Bluespec, Inc. All Rights Reserved
//
// SPDX-License-Identifier: BSD-3-Clause

package AXI4L_Fabric;

// ================================================================
// This package defines a fabric connecting CPUs, Memories and DMAs
// and other IP blocks.

// ================================================================
// Bluespec library imports

import Vector       :: *;
import FIFOF        :: *;
import SpecialFIFOs :: *;
import ConfigReg    :: *;

// ----------------
// Bluespec misc. libs

import Cur_Cycle  :: *;

// ================================================================
// Project imports

import Semi_FIFOF      :: *;
import AXI4L_Types :: *;

// ================================================================
// The interface for the fabric module

interface AXI4L_Fabric_IFC #(numeric type num_M,
				 numeric type num_S,
				 numeric type wd_addr,
				 numeric type wd_data,
				 numeric type wd_user);
   method Action reset;
   method Action set_verbosity (Bit #(4) verbosity);

   // From Ms
   interface Vector #(num_M, AXI4L_S_IFC #(wd_addr, wd_data, wd_user))  v_from_Ms;

   // To Ss
   interface Vector #(num_S,  AXI4L_M_IFC #(wd_addr, wd_data, wd_user)) v_to_Ss;
endinterface

// ================================================================
// The Fabric module
// The function parameter is an address-decode function, which returns
// returns (True,  S-port-num)  if address is mapped to S-port-num
//         (False, ?)           if address is unmapped to any port

module mkAXI4L_Fabric #(function Tuple2 #(Bool, Bit #(TLog #(num_S)))
			             fn_addr_to_S_num (Bit #(wd_addr) addr))
                          (AXI4L_Fabric_IFC #(num_M, num_S, wd_addr, wd_data, wd_user))

   provisos (Log #(num_M, log_nm),
	     Log #(num_S,  log_ns),
	     Log #(TAdd #(num_M, 1), log_nm_plus_1),
	     Log #(TAdd #(num_S,  1), log_ns_plus_1),
	     Add #(_dummy, TLog #(num_S), log_ns_plus_1));

   Reg #(Bit #(4)) cfg_verbosity  <- mkConfigReg (0);

   Reg #(Bool) rg_reset <- mkReg (True);

   // Transactors facing Ms
   Vector #(num_M, AXI4L_S_Xactor_IFC  #(wd_addr, wd_data, wd_user))
      xactors_from_Ms <- replicateM (mkAXI4L_S_Xactor);

   // Transactors facing Ss
   Vector #(num_S,  AXI4L_M_Xactor_IFC #(wd_addr, wd_data, wd_user))
       xactors_to_Ss <- replicateM (mkAXI4L_M_Xactor);

   // FIFOs to keep track of which M originated a transaction, in
   // order to route corresponding responses back to that M.
   // Legal Ms are 0..(num_M-1)
   // The value of 'num_M' is used for decode errors (no such S)

   Vector #(num_M, FIFOF #(Bit #(log_ns_plus_1))) v_f_wr_sjs      <- replicateM (mkSizedFIFOF (8));
   Vector #(num_M, FIFOF #(Bit #(wd_user)))       v_f_wr_err_user <- replicateM (mkSizedFIFOF (8));
   Vector #(num_S,  FIFOF #(Bit #(log_nm_plus_1))) v_f_wr_mis      <- replicateM (mkSizedFIFOF (8));

   Vector #(num_M, FIFOF #(Bit #(log_ns_plus_1))) v_f_rd_sjs      <- replicateM (mkSizedFIFOF (8));
   Vector #(num_M, FIFOF #(Bit #(wd_user)))       v_f_rd_err_user <- replicateM (mkSizedFIFOF (8));
   Vector #(num_S,  FIFOF #(Bit #(log_nm_plus_1))) v_f_rd_mis      <- replicateM (mkSizedFIFOF (8));

   // ----------------------------------------------------------------
   // BEHAVIOR

   rule rl_reset (rg_reset);
      if (cfg_verbosity != 0)
	 $display ("%0d: AXI4L_Fabric.rl_reset", cur_cycle);

      for (Integer mi = 0; mi < valueOf (num_M); mi = mi + 1) begin
	 xactors_from_Ms [mi].reset;

	 v_f_wr_sjs [mi].clear;
	 v_f_wr_err_user [mi].clear;

	 v_f_rd_sjs [mi].clear;
	 v_f_rd_err_user [mi].clear;
      end

      for (Integer sj = 0; sj < valueOf (num_S); sj = sj + 1) begin
	 xactors_to_Ss [sj].reset;
	 v_f_wr_mis [sj].clear;
	 v_f_rd_mis [sj].clear;
      end
      rg_reset <= False;
   endrule

   // ----------------------------------------------------------------
   // Help functions for moving data from Ms to Ss

   Integer num_S_i = valueOf (num_S);

   function Bool wr_move_from_mi_to_sj (Integer mi, Integer sj);
      let addr = xactors_from_Ms [mi].o_wr_addr.first.awaddr;
      match { .legal, .s_num } = fn_addr_to_S_num (addr);
      return (legal
	      && (   (num_S_i == 1)
		  || (s_num == fromInteger (sj))));
   endfunction

   function Bool wr_illegal_sj (Integer mi);
      let addr = xactors_from_Ms [mi].o_wr_addr.first.awaddr;
      match { .legal, ._ } = fn_addr_to_S_num (addr);
      return (! legal);
   endfunction

   function Bool rd_move_from_mi_to_sj (Integer mi, Integer sj);
      let addr = xactors_from_Ms [mi].o_rd_addr.first.araddr;
      match { .legal, .s_num } = fn_addr_to_S_num (addr);
      return (legal
	      && (   (num_S_i == 1)
		  || (s_num == fromInteger (sj))));
   endfunction

   function Bool rd_illegal_sj (Integer mi);
      let addr = xactors_from_Ms [mi].o_rd_addr.first.araddr;
      match { .legal, ._ } = fn_addr_to_S_num (addr);
      return (! legal);
   endfunction

   // ----------------
   // Wr requests from Ms to Ss

   // Legal destination Ss
   for (Integer mi = 0; mi < valueOf (num_M); mi = mi + 1)
      for (Integer sj = 0; sj < valueOf (num_S); sj = sj + 1)

	 rule rl_wr_xaction_M_to_S (wr_move_from_mi_to_sj (mi, sj));
	    AXI4L_Wr_Addr #(wd_addr, wd_user) a <- pop_o (xactors_from_Ms [mi].o_wr_addr);
	    AXI4L_Wr_Data #(wd_data)          d <- pop_o (xactors_from_Ms [mi].o_wr_data);

	    xactors_to_Ss [sj].i_wr_addr.enq (a);
	    xactors_to_Ss [sj].i_wr_data.enq (d);

	    v_f_wr_mis        [sj].enq (fromInteger (mi));
	    v_f_wr_sjs        [mi].enq (fromInteger (sj));

	    if (cfg_verbosity > 1) begin
	       $display ("%0d: AXI4L_Fabric: wr M [%0d] -> S [%0d]", cur_cycle, mi, sj);
	       $display ("        ", fshow (a));
	       $display ("        ", fshow (d));
	    end
	 endrule

   // Non-existent destination Ss
   for (Integer mi = 0; mi < valueOf (num_M); mi = mi + 1)
	 rule rl_wr_xaction_no_such_S (wr_illegal_sj (mi));
	    AXI4L_Wr_Addr #(wd_addr, wd_user) a <- pop_o (xactors_from_Ms [mi].o_wr_addr);
	    AXI4L_Wr_Data #(wd_data)          d <- pop_o (xactors_from_Ms [mi].o_wr_data);

	    v_f_wr_sjs        [mi].enq (fromInteger (valueOf (num_S)));
	    v_f_wr_err_user   [mi].enq (a.awuser);

	    if (cfg_verbosity > 1) begin
	       $display ("%0d: AXI4L_Fabric: wr M [%0d] -> illegal addr", cur_cycle, mi);
	       $display ("        ", fshow (a));
	    end
	 endrule

   // ----------------
   // Rd requests from Ms to Ss

   // Legal destination Ss
   for (Integer mi = 0; mi < valueOf (num_M); mi = mi + 1)
      for (Integer sj = 0; sj < valueOf (num_S); sj = sj + 1)

	 rule rl_rd_xaction_M_to_S (rd_move_from_mi_to_sj (mi, sj));
	    AXI4L_Rd_Addr #(wd_addr, wd_user) a <- pop_o (xactors_from_Ms [mi].o_rd_addr);

	    xactors_to_Ss [sj].i_rd_addr.enq (a);

	    v_f_rd_mis [sj].enq (fromInteger (mi));
	    v_f_rd_sjs [mi].enq (fromInteger (sj));

	    if (cfg_verbosity > 1) begin
	       $display ("%0d: AXI4L_Fabric: rd M [%0d] -> S [%0d]", cur_cycle, mi, sj);
	       $display ("        ", fshow (a));
	    end
	 endrule

   // Non-existent destination Ss
   for (Integer mi = 0; mi < valueOf (num_M); mi = mi + 1)
	 rule rl_rd_xaction_no_such_S (rd_illegal_sj (mi));
	    AXI4L_Rd_Addr #(wd_addr, wd_user) a <- pop_o (xactors_from_Ms [mi].o_rd_addr);

	    v_f_rd_sjs      [mi].enq (fromInteger (valueOf (num_S)));
	    v_f_rd_err_user [mi].enq (a.aruser);

	    if (cfg_verbosity > 1) begin
	       $display ("%0d: AXI4L_Fabric: rd M [%0d] -> illegal addr", cur_cycle, mi);
	       $display ("        ", fshow (a));
	    end
	 endrule

   // ----------------
   // Wr responses from Ss to Ms

   for (Integer mi = 0; mi < valueOf (num_M); mi = mi + 1)
      for (Integer sj = 0; sj < valueOf (num_S); sj = sj + 1)

	 rule rl_wr_resp_S_to_M (   (v_f_wr_mis [sj].first == fromInteger (mi))
					  && (v_f_wr_sjs [mi].first == fromInteger (sj)));
	    v_f_wr_mis [sj].deq;
	    v_f_wr_sjs [mi].deq;
	    AXI4L_Wr_Resp #(wd_user) b <- pop_o (xactors_to_Ss [sj].o_wr_resp);

	    xactors_from_Ms [mi].i_wr_resp.enq (b);

	    if (cfg_verbosity > 1) begin
	       $display ("%0d: AXI4L_Fabric: wr M [%0d] <- S [%0d]", cur_cycle, mi, sj);
	       $display ("        ", fshow (b));
	    end
	 endrule

   // ----------------
   // Wr error responses to Ms
   // v_f_wr_sjs [mi].first has value num_S (illegal value)
   // v_f_wr_err_user [mi].first contains the request's 'user' data

   for (Integer mi = 0; mi < valueOf (num_M); mi = mi + 1)

      rule rl_wr_resp_err_to_M (v_f_wr_sjs [mi].first == fromInteger (valueOf (num_S)));
	 v_f_wr_sjs [mi].deq;
	 v_f_wr_err_user [mi].deq;

	 let b = AXI4L_Wr_Resp {bresp: AXI4L_DECERR, buser: v_f_wr_err_user [mi].first};

	 xactors_from_Ms [mi].i_wr_resp.enq (b);

	 if (cfg_verbosity > 1) begin
	    $display ("%0d: AXI4L_Fabric: wr M [%0d] <- error", cur_cycle, mi);
	    $display ("        ", fshow (b));
	 end
      endrule

   // ----------------
   // Rd responses from Ss to Ms

   for (Integer mi = 0; mi < valueOf (num_M); mi = mi + 1)
      for (Integer sj = 0; sj < valueOf (num_S); sj = sj + 1)

	 rule rl_rd_resp_S_to_M (   (v_f_rd_mis [sj].first == fromInteger (mi))
				 && (v_f_rd_sjs [mi].first == fromInteger (sj)));
	    v_f_rd_mis [sj].deq;
	    v_f_rd_sjs [mi].deq;
	    AXI4L_Rd_Data #(wd_data, wd_user) r <- pop_o (xactors_to_Ss [sj].o_rd_data);

	    xactors_from_Ms [mi].i_rd_data.enq (r);

	    if (cfg_verbosity > 1) begin
	       $display ("%0d: AXI4L_Fabric: rd M [%0d] <- S [%0d]", cur_cycle, mi, sj);
	       $display ("        ", fshow (r));
	    end
	 endrule

   // ----------------
   // Rd error responses to Ms
   // v_f_rd_sjs [mi].first has value num_S (illegal value)
   // v_f_rd_err_user [mi].first contains the request's 'user' data

   for (Integer mi = 0; mi < valueOf (num_M); mi = mi + 1)

      rule rl_rd_resp_err_to_M (v_f_rd_sjs [mi].first == fromInteger (valueOf (num_S)));
	 v_f_rd_sjs [mi].deq;
	 v_f_rd_err_user [mi].deq;

	 Bit #(wd_data) data = 0;
	 let r = AXI4L_Rd_Data {rresp: AXI4L_DECERR,
				ruser: v_f_rd_err_user [mi].first,
				rdata: data};

	 xactors_from_Ms [mi].i_rd_data.enq (r);

	 if (cfg_verbosity > 1) begin
	    $display ("%0d: AXI4L_Fabric: rd M [%0d] <- error", cur_cycle, mi);
	    $display ("        ", fshow (r));
	 end
      endrule

   // ----------------------------------------------------------------
   // INTERFACE

   function AXI4L_S_IFC  #(wd_addr, wd_data, wd_user) f1 (Integer j)
      = xactors_from_Ms [j].axi_side;
   function AXI4L_M_IFC #(wd_addr, wd_data, wd_user) f2 (Integer j)
      = xactors_to_Ss    [j].axi_side;

   method Action reset () if (! rg_reset);
      rg_reset <= True;
   endmethod

   method Action set_verbosity (Bit #(4) verbosity);
      cfg_verbosity <= verbosity;
   endmethod

   interface v_from_Ms = genWith (f1);
   interface v_to_Ss   = genWith (f2);
endmodule

// ================================================================

endpackage: AXI4L_Fabric
