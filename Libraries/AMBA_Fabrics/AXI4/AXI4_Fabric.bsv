// Copyright (c) 2013-2023 Bluespec, Inc. All Rights Reserved
// Copyright (c) 2024 Rishiyur S. Nikhil.

// SPDX-License-Identifier: BSD-3-Clause

package AXI4_Fabric;

// ****************************************************************
// This package defines a module mkAXI4_Fabric with an Empty interface.
// It is a crossbar connecting a vector of Ms to a vector of Ss.

// It is parameterized by:
// * number of Ms
// * number of Ss
// * widths of the various AXI4 buses.
// * a "routing function" address -> S num that specifies which S
//     (or none) services a request.

// Note that M-side ID fields (ARID, AWID) are narrower than S-side ID
// fields (RID, BID). The extra S-side ID bits encode, for each AXI4
// transaction, which M it came from, so that the response can be
// routed back appropriately.

// Handles bursts (read and write).

// ****************************************************************
// Bluespec library imports

import Vector       :: *;
import FIFOF        :: *;
import SpecialFIFOs :: *;

// ----------------
// Bluespec misc. libs

import Semi_FIFOF :: *;

// ----------------
// Project imports

import AXI4_Types :: *;

// ================================================================
// Project exports

export mkAXI4_Fabric;

// ****************************************************************
// The Fabric module
// The function parameter is an address-decode function, which
// returns (True,  j)    if address maps to Sj
//         (False, ?)    if address is wild (does not map to any Sj)

module mkAXI4_Fabric #(// Routing function
		       function Tuple2 #(Bool, Bit #(TLog #(tn_num_S)))
			        fn_addr_to_S_num (Bit #(wd_addr) addr),
		       // From Ms
		       Vector #(tn_num_M,
				AXI4_M_IFC #(wd_id_M, wd_addr, wd_data, wd_user)) v_ifc_M,
		       // To Ss
		       Vector #(tn_num_S,
				AXI4_S_IFC #(wd_id_S, wd_addr, wd_data, wd_user)) v_ifc_S)
		     (Empty)

   provisos (Log #(tn_num_M, log_nm),             // define log_nm
	     Log #(tn_num_S, log_ns),             // define log_ns
	     Add #(wd_id_M, log_nm, wd_id_S));    // assert

   // 0: quiet; 1: show transactions
   Integer verbosity = 0;

   Integer num_M = valueOf (tn_num_M);
   Integer num_S = valueOf (tn_num_S);

   // ----------------------------------------------------------------
   // Write-transaction control:

   // The AW and W buses are separate and not synchronized, but the
   // ordering is the same, i.e., in any AXI4 interface, the sequence
   // of W bursts (W0, W1, ...) is assumed to correspond to the
   // sequence of AW requests (AW0, AW1, ...).

   // In a fabric, two write-transaction scenarios where the ordering could go wrong:
   // A. Two M's to one S:
   //      From Mi and Mj, if we send AWi and AWj to Sk, in that order,
   //      then Wi should precede Wj.
   //      Also: beats from the Wi and Wj bursts should not be interleaved.
   // B. One M to two S's:
   //      From Mi, if we send AWi1 and AWi2 to Sj and Sk, in that order,
   //      then Wi1 should go to Sj and Wi2 should go to Sk
   //

   // For scenario A, we have a FIFO per-Sj which records order of M's
   // from which it should take Ws.

   Vector #(tn_num_S, FIFOF #(Bit #(log_nm)))    // FIFO of Mi
   v_f_W_Mi <- replicateM (mkFIFOF);

   // For scenario B, we have a FIFO per-Mi which records order of S's
   // to which it should send Ws.

   Vector #(tn_num_M, FIFOF #(Tuple2 #(Bool, Bit #(log_ns))))    // FIFO of Sj
   v_f_W_Sj <- replicateM (mkFIFOF);

   // For wild writes (addr does not map to any Sj), this FIFO records
   // info to consume the write-burst and then respond with error.
   // TODO: per-Mi FIFOs would add concurrency.

   FIFOF #(Tuple3 #(Bit #(log_nm),      // Mi of current AWCHAN req
		    Bit #(wd_id_M),     // AWID to reflect into BID
		    Bit #(wd_user)))    // AWUSER to reflect into BUSER
   f_W_wild <- mkFIFOF;

   // ----------------
   // Read-respose merge control

   // For "simultaneous" RCHAN responses from Sj1 and Sj2 to the same
   // Mi, the two bursts must not interleave. Each Sj must "own" Mi
   // for its full burst.

   Vector #(tn_num_M, Reg #(Maybe #(Bit #(log_ns))))
   v_rg_M_RCHAN_owners <- replicateM (mkReg (tagged Invalid));

   // ----------------------------------------------------------------
   // Predicates to check if Mi has transaction for Sj
   // The expression (s_num == fromInteger (sj)) is dodgy when num_S == 1
   // because it's a Bit#(0) comparision; so special case 'num_S == 1'


   function Bool fv_mi_has_wr_for_sj (Integer mi, Integer sj);
      let addr = v_ifc_M [mi].o_AW.first.awaddr;
      match { .legal, .s_num } = fn_addr_to_S_num (addr);
      return (legal
	      && (   (num_S == 1)
		  || (s_num == fromInteger (sj))));
   endfunction

   function Bool fv_mi_has_rd_for_sj (Integer mi, Integer sj);
      let addr = v_ifc_M [mi].o_AR.first.araddr;
      match { .legal, .s_num } = fn_addr_to_S_num (addr);
      return (legal
	      && (   (num_S == 1)
		  || (s_num == fromInteger (sj))));
   endfunction

   function Bool fv_mi_has_wr_for_none (Integer mi);
      let addr = v_ifc_M [mi].o_AW.first.awaddr;
      match { .legal, ._ } = fn_addr_to_S_num (addr);
      return (! legal);
   endfunction

   function Bool fv_mi_has_rd_for_none (Integer mi);
      let addr = v_ifc_M [mi].o_AR.first.araddr;
      match { .legal, ._ } = fn_addr_to_S_num (addr);
      return (! legal);
   endfunction

   // ================================================================
   // BEHAVIOR: AWCHAN (write-requests)

   Rules all_rules = emptyRules;

   // AW legal addrs
   for (Integer mi = 0; mi < num_M; mi = mi + 1) begin
      for (Integer sj = 0; sj < num_S; sj = sj + 1)
	 all_rules =
	 rJoinDescendingUrgency (
	    all_rules,
	    rules
	       rule rl_AW (fv_mi_has_wr_for_sj (mi, sj));
		  // Forward the AW transaction
		  let aw_in  <- pop_o (v_ifc_M [mi].o_AW);
		  let awid_S = { aw_in.awid, fromInteger (mi) };
		  let aw_out = fn_change_AW_id (aw_in, awid_S);
		  v_ifc_S [sj].i_AW.enq (aw_out);

		  // Enqueue mi->sj control info for W channel
		  v_f_W_Sj [mi].enq (tuple2 (True, fromInteger (sj)));
		  v_f_W_Mi [sj].enq (fromInteger (mi));

		  if (verbosity > 0) begin
		     $display ("AXI4_Fabric: AW m%0d -> s%0d", mi, sj);
		     $display ("    ", fshow (aw_in));
		  end
	       endrule
	    endrules);

      // AW wild addrs (awaddr does not map to any Sj)
      all_rules =
      rJoinDescendingUrgency (
	 all_rules,
	 rules
	    rule rl_AW_wild (fv_mi_has_wr_for_none (mi));
	       let aw_in  <- pop_o (v_ifc_M [mi].o_AW);

	       // Enqueue mi->sj control info for W channel
	       v_f_W_Sj [mi].enq (tuple2 (False, ?));
	       f_W_wild.enq (tuple3 (fromInteger (mi), aw_in.awid, aw_in.awuser));

	       if (verbosity > 0) begin
		  $display ("ERROR: AXI4_Fabric: AW m%0d -> wild", mi);
		  $display ("    ", fshow (aw_in));
	       end
	    endrule
	 endrules);
   end

   // ================================================================
   // BEHAVIOR: WCHAN (write-data)

   // W normal
   for (Integer mi = 0; mi < num_M; mi = mi + 1) begin
      for (Integer sj = 0; sj < num_S; sj = sj + 1)
	 all_rules =
	 rJoinDescendingUrgency (
	    all_rules,
	    rules

	       // W channel (with bursts)
	       // Invariant: v_rg_wd_beat_count == 0 between bursts
	       // Note: awlen encodes burst lengths of 1..256 as 0..255
	       rule rl_W ((v_f_W_Mi [sj].first == fromInteger (mi))
			  && tpl_1 (v_f_W_Sj [mi].first)
			  && (tpl_2 (v_f_W_Sj [mi].first) == fromInteger (sj)));

		  // Forward the W
		  let w <- pop_o (v_ifc_M [mi].o_W);
		  v_ifc_S [sj].i_W.enq (w);

		  if (verbosity > 0) begin
		     $display ("AXI4_Fabric: W m%0d -> s%0d", mi, sj);
		     $display ("    ", fshow (w));
		  end

		  if (w.wlast) begin
		     // End of burst; dequeue the control info
		     v_f_W_Mi [sj].deq;
		     v_f_W_Sj [mi].deq;
		  end
	       endrule
	    endrules);

      // W for wild addrs
      all_rules =
      rJoinDescendingUrgency (
	 all_rules,
	 rules
	    rule rl_W_wild (tpl_1 (f_W_wild.first) == fromInteger (mi)
			    && (! tpl_1 (v_f_W_Sj [mi].first)));

	       match { .mi, .bid, .buser } = f_W_wild.first;

	       // Consume the W and drop it
	       let w <- pop_o (v_ifc_M [mi].o_W);

	       if (verbosity > 0) begin
		  $display ("AXI4_Fabric: W m%0d -> WILD", mi);
		  $display ("    ", fshow (w));
	       end

	       if (w.wlast) begin
		  // End of burst; dequeue the control info
		  f_W_wild.deq;
		  v_f_W_Sj [mi].deq;

		  // Send error response to Mi
		  let b = AXI4_B {bid:   bid,
				  bresp: axi4_resp_decerr,
				  buser: buser};
		  v_ifc_M [mi].i_B.enq (b);
	       end
	    endrule
	 endrules);
   end

   // ================================================================
   // BEHAVIOR: BCHAN (write-responses)

   // Wr responses from Ss to Ms
   for (Integer sj = 0; sj < num_S; sj = sj + 1)
      all_rules =
      rJoinDescendingUrgency (
	 all_rules,
	 rules
	    rule rl_B;
	       // Incoming BCHAN response
	       AXI4_B #(wd_id_S, wd_user) b_in <- pop_o (v_ifc_S [sj].o_B);
	       // Extract mi and bid_M from incoming bid_S
	       Bit #(wd_id_S) bid_S = b_in.bid;
	       Bit #(log_nm)  mi    = truncate (bid_S);
	       Bit #(wd_id_M) bid_M = truncateLSB (bid_S);
	       // Replace bid_S with bid_M in BCHAN response, send to mi
	       AXI4_B #(wd_id_M, wd_user) b_out = fn_change_B_id (b_in, bid_M);
	       v_ifc_M [mi].i_B.enq (b_out);

	       if (verbosity > 0) begin
		  $display ("AXI4_Fabric: B m%0d <- s%0d", mi, sj);
		  $display ("    ", fshow (b_out));
	       end
	    endrule
	 endrules);

   // ================================================================
   // ARCHAN (read requests)

   // Legal addrs
   for (Integer mi = 0; mi < num_M; mi = mi + 1) begin
      for (Integer sj = 0; sj < num_S; sj = sj + 1)
	 all_rules =
	 rJoinDescendingUrgency (
	    all_rules,
	    rules
	       rule rl_AR (fv_mi_has_rd_for_sj (mi, sj));
		  let ar_in <- pop_o (v_ifc_M [mi].o_AR);
		  let arid_S = { ar_in.arid, fromInteger (mi) };
		  let ar_out = fn_change_AR_id (ar_in, arid_S);
		  v_ifc_S [sj].i_AR.enq (ar_out);

		  if (verbosity > 0) begin
		     $display ("AXI4_Fabric: AR m%0d -> s%0d", mi, sj);
		     $display ("    ", fshow (ar_in));
		  end
	       endrule
	    endrules);

      all_rules =
      rJoinDescendingUrgency (
	 all_rules,
	 rules
	    // Wild addr (araddr does not map to any Sj)
	    rule rl_AR_wild (fv_mi_has_rd_for_none (mi));
	       let ar <- pop_o (v_ifc_M [mi].o_AR);
	       let r = AXI4_R {rid:   ar.arid,
			       rdata: ?,
			       rresp: axi4_resp_decerr,
			       rlast: True,
			       ruser: ar.aruser};
	       v_ifc_M [mi].i_R.enq (r);

	       if (verbosity > 0) begin
		  $display ("ERROR: AR m%0d -> WILD", mi);
		  $display ("    ", fshow (ar));
	       end
	    endrule
	 endrules);
   end

   // ================================================================
   // RCHAN (read responses)

   for (Integer sj = 0; sj < num_S; sj = sj + 1)
      all_rules =
      rJoinDescendingUrgency (
	 all_rules,
	 rules
	    rule rl_R;
	       AXI4_R #(wd_id_S, wd_data, wd_user)
	       r_in = v_ifc_S [sj].o_R.first;

	       // Check if we already own Mi or if Mi is free (no owner)
	       Bit #(log_nm) mi = truncate (r_in.rid);
	       Bool we_own      = False;
	       if (v_rg_M_RCHAN_owners [mi] matches tagged Invalid)
		  we_own = True;
	       else if (v_rg_M_RCHAN_owners [mi] matches tagged Valid .sj2
			&&& (sj2 == fromInteger (sj)))
		  we_own = True;

	       if (we_own) begin
		  // Forward the R response
		  v_ifc_S [sj].o_R.deq;
		  Bit #(wd_id_S) rid_S = r_in.rid;
		  Bit #(wd_id_M) rid_M = truncateLSB (rid_S);
		  let r_M   = fn_change_R_id (r_in, rid_M);
		  v_ifc_M [mi].i_R.enq (r_M);

		  // Release ownership of Mi RCHAN on last beat
		  if (r_in.rlast)
		     v_rg_M_RCHAN_owners [mi] <= tagged Invalid;
		  else
		     // Record ownership for rest of beats
		     v_rg_M_RCHAN_owners [mi] <= tagged Valid (fromInteger (sj));

		  if (verbosity > 0) begin
		     $display ("AXI4_Fabric: R m%0d <- s%0d", mi, sj);
		     $display ("    ", fshow (r_M));
		  end
	       end
	    endrule
	 endrules);

   addRules (all_rules);

   // ****************************************************************
   // INTERFACE

   // Empty
endmodule

// ****************************************************************

endpackage: AXI4_Fabric
