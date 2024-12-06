// Copyright (c) 2019-2023 Bluespec, Inc. All Rights Reserved
// Copyright (c) 2024 Rishiyur S. Nikhil.

// SPDX-License-Identifier: BSD-3-Clause

package Test_AXI4_Deburster;

// ****************************************************************
// Standalone unit tester for AXI4_Deburster.bsv

// ****************************************************************
// Bluespec library imports

import FIFOF       :: *;
import Connectable :: *;

// ----------------
// BSV additional libs

import Cur_Cycle  :: *;
import Semi_FIFOF :: *;

// ================================================================
// Project imports

import AXI4_Types     :: *;
import AXI4_Deburster :: *;

// ****************************************************************
// Synthesized instance of Deburster

typedef  4 Wd_Id;
typedef 32 Wd_Addr;
typedef 64 Wd_Data;
typedef 10 Wd_User;

// ================================================================

(* synthesize *)
module sysTest_AXI4_Deburster (Empty);

   // Buffer for downstream logic
   AXI4_Buffer_IFC #(Wd_Id, Wd_Addr, Wd_Data, Wd_User) s <- mkAXI4_Buffer;

   // Deburster, connected to downstream
   AXI4_S_IFC #(Wd_Id, Wd_Addr, Wd_Data, Wd_User) deburster <- mkAXI4_Deburster (s.ifc_S);

   Reg #(Bit #(32))  rg_test       <- mkReg (20);    // Chooses which test to run
   FIFOF #(Bit #(8)) f_len         <- mkFIFOF;
   Reg #(Bit #(8))   rg_beat       <- mkReg (0);
   Reg #(Bit #(32))  rg_idle_count <- mkReg (0);

   // ================================================================
   // Help function to create AXI4 channel payloads

   function AXI4_AW #(Wd_Id, Wd_Addr, Wd_User)
            fv_mkAW (Bit #(Wd_Id)    id,
		     Bit #(Wd_Addr)  addr,
		     Bit #(8)        len,
		     Bit #(2)        burst,
		     Bit #(Wd_User)  user);
      return AXI4_AW {awid: id,
		      awaddr: addr,
		      awlen: len,
		      awsize: axsize_8,
		      awburst: burst,
		      awlock: 0,
		      awcache: 0,
		      awprot: 0,
		      awqos: 0,
		      awregion: 0,
		      awuser: user};
   endfunction

   function AXI4_W #(Wd_Data, Wd_User)
            fv_mkW (Bit #(Wd_Data)  data,
		    Bit #(Wd_User)  user);
      Bool last = (rg_beat == f_len.first - 1);
      return AXI4_W {wdata: data,
		     wstrb: 'hFF,
		     wlast: last,
		     wuser: user};
   endfunction

   function AXI4_B #(Wd_Id, Wd_User)
            fv_mkB (AXI4_AW #(Wd_Id, Wd_Addr, Wd_User) aw);
      return AXI4_B {bid:   aw.awid,
		     bresp: axi4_resp_okay,
		     buser: aw.awuser};
   endfunction

   function AXI4_AR #(Wd_Id, Wd_Addr, Wd_User)
            fv_mkAR (Bit #(Wd_Id)    id,
		     Bit #(Wd_Addr)  addr,
		     Bit #(8)        len,
		     Bit #(2)        burst,
		     Bit #(Wd_User)  user);
      return AXI4_AR {arid: id,
		      araddr: addr,
		      arlen: len,
		      arsize: axsize_8,
		      arburst: burst,
		      arlock: 0,
		      arcache: 0,
		      arprot: 0,
		      arqos: 0,
		      arregion: 0,
		      aruser: user};
   endfunction

   function AXI4_R #(Wd_Id, Wd_Data, Wd_User)
            fv_mkR (AXI4_AR #(Wd_Id, Wd_Addr, Wd_User) ar);
      return AXI4_R {rid:   ar.arid,
		     rdata: zeroExtend (ar.araddr + 'h10_000),
		     rresp: axi4_resp_okay,
		     rlast: True,
		     ruser: ar.aruser};
   endfunction

   // ================================================================
   // STIMULUS

   Bit #(Wd_Id)   id1   = 1;
   Bit #(Wd_User) user1 = 1;

   // ----------------
   // Write tests

   rule rl_wr_single (rg_test == 0);
      Bit #(8) len = 1;
      let aw = fv_mkAW (id1, 'h1000, (len - 1), axburst_fixed, user1);
      deburster.i_AW.enq (aw);

      f_len.enq (len);
      rg_idle_count <= 0;
      rg_test       <= 100;

      $display ("%0d: M.rl_wr_single", cur_cycle);
      $display ("  ", fshow (aw));
   endrule

   rule rl_wr_burst_addr_0 (rg_test == 10);
      Bit #(8) len = 2;
      let aw = fv_mkAW (id1, 'h1000, (len - 1), axburst_incr, user1);
      deburster.i_AW.enq (aw);

      f_len.enq (len);
      rg_idle_count <= 0;
      rg_test       <= 11;

      $display ("%0d: M.rl_wr_burst_addr_0", cur_cycle);
      $display ("  ", fshow (aw));
   endrule

   rule rl_wr_burst_addr_1 (rg_test == 11);
      Bit #(8) len = 4;
      let aw = fv_mkAW (id1, 'h2000, (len - 1), axburst_incr, user1);
      deburster.i_AW.enq (aw);

      f_len.enq (len);
      rg_idle_count <= 0;
      rg_test       <= 100;

      $display ("%0d: M.rl_wr_burst_addr_1", cur_cycle);
      $display ("  ", fshow (aw));
   endrule

   rule rl_wr_data;
      let data = 'h1_0000 + zeroExtend (rg_beat);
      let wd = fv_mkW (data, user1);
      deburster.i_W.enq (wd);
      rg_idle_count <= 0;

      if (rg_beat < f_len.first - 1)
	 rg_beat <= rg_beat + 1;
      else begin
	 rg_beat <= 0;
	 f_len.deq;

	 rg_test <= '1;
      end

      $display ("%0d: M.rl_wr_data", cur_cycle);
      $display ("  ", fshow (wd));
   endrule

   // ----------------
   // Read tests

   rule rl_rd_single (rg_test == 2);
      let ar = fv_mkAR (id1, 'h1000, 1, axburst_fixed, user1);
      deburster.i_AR.enq (ar);
      rg_idle_count <= 0;
      rg_test <= '1;

      $display ("%0d: M.rl_rd_single", cur_cycle);
      $display ("  ", fshow (ar));
   endrule

   rule rl_rd_burst_addr_0 (rg_test == 20);
      Bit #(8) len = 2;
      let ar = fv_mkAR (id1, 'h1000, (len - 1), axburst_incr, user1);
      deburster.i_AR.enq (ar);

      rg_idle_count <= 0;
      rg_test       <= 21;

      $display ("%0d: M.rl_rd_burst_addr_0", cur_cycle);
      $display ("  ", fshow (ar));
   endrule

   rule rl_rd_burst_addr_1 (rg_test == 21);
      Bit #(8) len = 4;
      let ar = fv_mkAR (id1, 'h2000, (len - 1), axburst_incr, user1);
      deburster.i_AR.enq (ar);

      rg_idle_count <= 0;
      rg_test       <= 100;

      $display ("%0d: M.rl_rd_burst_addr_1", cur_cycle);
      $display ("  ", fshow (ar));
   endrule

   // ================================================================
   // Drain and display responses received by M

   rule rl_wr_resps;
      let wr_resp <- pop_o (deburster.o_B);
      $display ("%0d: M.rl_wr_resps", cur_cycle);
      $display ("  ", fshow (wr_resp));
      rg_idle_count <= 0;
   endrule

   rule rl_rd_resps;
      let rd_resp <- pop_o (deburster.o_R);
      $display ("%0d: M.rl_rd_resps", cur_cycle);
      $display ("  ", fshow (rd_resp));
      rg_idle_count <= 0;
   endrule

   // ================================================================
   // S: return functional responses
   // Note: we should not be receiving any bursts, since we're fronted by the Deburster.

   rule rl_S_IP_model_writes;
      $display ("%0d:    S.rl_S_IP_model_writes", cur_cycle);

      let aw <- pop_o (s.ifc_M.o_AW);
      let w  <- pop_o (s.ifc_M.o_W);

      let b = fv_mkB (aw);
      s.ifc_M.i_B.enq (b);
      $display ("        ", fshow (aw));
      $display ("        ", fshow (w));
      $display ("        ", fshow (b));
   endrule

   rule rl_S_IP_model_AR;
      let ar <- pop_o (s.ifc_M.o_AR);
      s.ifc_M.i_R.enq (fv_mkR (ar));

      $display ("%0d:    S.rl_S_IP_model_AR", cur_cycle);
      $display ("        ", fshow (ar));
   endrule

   // ================================================================

   rule rl_idle_quit;
      if (rg_idle_count == 100) begin
	 $display ("%0d: rl_idle_quit", cur_cycle);
	 $finish (0);
      end
      else begin
	 rg_idle_count <= rg_idle_count + 1;
      end
   endrule

endmodule

// ================================================================

endpackage
