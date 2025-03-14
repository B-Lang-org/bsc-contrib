// Copyright (c) 2019-2024 Bluespec, Inc. All Rights Reserved

// SPDX-License-Identifier: BSD-3-Clause

package Test_Fabric;

// ================================================================
// Standalone unit tester for AXI4L_Fabric.bsv

// ================================================================
// Bluespec library imports

import FIFOF       :: *;
import Connectable :: *;

// ----------------
// BSV additional libs

import Cur_Cycle  :: *;

// ================================================================
// Project imports

import Semi_FIFOF       :: *;
import AXI4L_Types  :: *;
import AXI4L_Fabric :: *;

// ================================================================
// Synthesized instance of Fabric

typedef 2 Num_Ms;
typedef 3 Num_Ss;

typedef 32 Wd_Addr;
typedef 64 Wd_Data;
typedef  0 Wd_User;

typedef AXI4L_Fabric_IFC #(Num_Ms,
			   Num_Ss,
			   Wd_Addr,
			   Wd_Data,
			   Wd_User)  AXI4L_Fabric_IFC_Inst;

function Tuple2 #(Bool, Bit #(TLog #(Num_Ss)))
         fn_addr_to_S_num (Bit #(Wd_Addr) addr);
   if ((addr & 'h_FFFF_0000) == 0)
      return tuple2 (True, 0);
   else if ((addr & 'h_FFFF_0000) == 1)
      return tuple2 (True, 1);
   else if ((addr & 'h_FFFF_0000) == 2)
      return tuple2 (True, 2);
   else
      return tuple2 (False, ?);
endfunction

(* synthesize *)
module mkAXI4L_Fabric_Inst (AXI4L_Fabric_IFC_Inst);
   let m <- mkAXI4L_Fabric (fn_addr_to_S_num);
   return m;
endmodule

AXI4L_M_IFC #(Wd_Addr, Wd_Data, Wd_User) dummy_AXI4L_M_ifc_inst = dummy_AXI4L_M_ifc;
AXI4L_S_IFC #(Wd_Addr, Wd_Data, Wd_User) dummy_AXI4L_S_ifc_inst = dummy_AXI4L_S_ifc;

// ================================================================

(* synthesize *)
module sysTest_Fabric (Empty);
   AXI4L_Fabric_IFC_Inst fabric <- mkAXI4L_Fabric_Inst;

   AXI4L_M_Xactor_IFC #(Wd_Addr, Wd_Data, Wd_User) m0 <- mkAXI4L_M_Xactor;
   AXI4L_S_Xactor_IFC #(Wd_Addr, Wd_Data, Wd_User) s0 <- mkAXI4L_S_Xactor;

   mkConnection (m0.axi_side,         fabric.v_from_Ms [0]);
   mkConnection (dummy_AXI4L_M_ifc_inst,  fabric.v_from_Ms [1]);

   mkConnection (fabric.v_to_Ss [0], s0.axi_side);
   mkConnection (fabric.v_to_Ss [1], dummy_AXI4L_S_ifc_inst);
   mkConnection (fabric.v_to_Ss [2], dummy_AXI4L_S_ifc_inst);

   Reg #(Bit #(32)) rg_test <- mkReg (0);    // Chooses which test to run

   FIFOF #(Bit #(64)) f_wdata <- mkFIFOF;

   Reg #(Bit #(32)) rg_idle_count <- mkReg (0);

   // ================================================================
   // Help function to create AXI4L channel payloads

   function AXI4L_Wr_Addr #(Wd_Addr, Wd_User)
            fv_mk_wr_addr (Bit #(Wd_Addr)  addr, Bit #(Wd_User)  user);

      return AXI4L_Wr_Addr {awaddr: addr, awprot: 0, awuser: user};
   endfunction

   function AXI4L_Wr_Data #(Wd_Data)
            fv_mk_wr_data (Bit #(Wd_Data)  data);

      return AXI4L_Wr_Data {wdata: data, wstrb: 'hFF};
   endfunction

   function AXI4L_Wr_Resp #(Wd_User)
            fv_mk_wr_resp (AXI4L_Wr_Data #(Wd_Data) wd, Bit #(Wd_User) user);

      return AXI4L_Wr_Resp {bresp: AXI4L_OKAY, buser: user};
   endfunction

   function AXI4L_Rd_Addr #(Wd_Addr, Wd_User)
            fv_mk_rd_addr (Bit #(Wd_Addr)  addr, Bit #(Wd_User)  user);

      return AXI4L_Rd_Addr {araddr: addr, arprot: 0, aruser: user};
   endfunction

   function AXI4L_Rd_Data #(Wd_Data, Wd_User)
            fv_mk_rd_data (AXI4L_Rd_Addr #(Wd_Addr, Wd_User) ar);

      return AXI4L_Rd_Data {rresp: AXI4L_OKAY,
			    rdata: zeroExtend (ar.araddr + 'h10_000),
			    ruser: ar.aruser};
   endfunction

   // ================================================================
   // STIMULUS

   Bit #(Wd_User) user1 = ((valueOf (Wd_User) == 0) ? 0 : ?);

   rule rl_step0_wra (rg_test == 0);
      let wa = fv_mk_wr_addr ('h1000, user1);
      m0.i_wr_addr.enq (wa);

      f_wdata.enq (fromInteger ('h1000));
      rg_idle_count <= 0;
      rg_test       <= 1;

      $display ("%0d: M.rl_step0_wra", cur_cycle);
      $display ("    ", fshow (wa));
   endrule

   rule rl_step1_wra (rg_test == 1);
      let wa = fv_mk_wr_addr ('h1004, user1);
      m0.i_wr_addr.enq (wa);

      f_wdata.enq (fromInteger ('h1004));
      rg_idle_count <= 0;
      rg_test       <= 2;

      $display ("%0d: M.rl_step2_wra", cur_cycle);
      $display ("    ", fshow (wa));
   endrule

   rule rl_step2_rda (rg_test == 2);
      let ra = fv_mk_rd_addr ('h2000, user1);
      m0.i_rd_addr.enq (ra);
      rg_idle_count <= 0;
      rg_test <= 3;

      $display ("%0d: M.rl_step2_rda", cur_cycle);
      $display ("    ", fshow (ra));
   endrule

   rule rl_step3_rda (rg_test == 3);
      let ra = fv_mk_rd_addr ('h2004, user1);
      m0.i_rd_addr.enq (ra);
      rg_idle_count <= 0;
      rg_test       <= 4;

      $display ("%0d: M.rl_step3_rda", cur_cycle);
      $display ("    ", fshow (ra));
   endrule

   rule rl_step4_rda (rg_test == 4);
      let ra = fv_mk_rd_addr ('h0003_0000, user1);
      m0.i_rd_addr.enq (ra);
      rg_idle_count <= 0;
      rg_test       <= 5;

      $display ("%0d: M.rl_step4_rda", cur_cycle);
      $display ("    ", fshow (ra));
   endrule

   // ----------------------------------------------------------------
   // M: write data for write-transaction

   rule rl_wr_data;
      let data = f_wdata.first; f_wdata.deq;

      let wd = fv_mk_wr_data (data);
      m0.i_wr_data.enq (wd);
      rg_idle_count <= 0;

      $display ("%0d: M.rl_wr_data", cur_cycle);
      $display ("    ", fshow (wd));
   endrule

   // ================================================================
   // M: Drain and display responses received by M

   rule rl_wr_resps;
      let wr_resp <- pop_o (m0.o_wr_resp);
      $display ("%0d: M.rl_wr_resps", cur_cycle);
      $display ("    ", fshow (wr_resp));
      rg_idle_count <= 0;
   endrule

   rule rl_rd_resps;
      let rd_resp <- pop_o (m0.o_rd_data);
      $display ("%0d: M.rl_rd_resps", cur_cycle);
      $display ("    ", fshow (rd_resp));
      rg_idle_count <= 0;
   endrule

   // ================================================================
   // S: return functional responses

   rule rl_S_IP_model_wr_addr;
      let wa <- pop_o (s0.o_wr_addr);

      $display ("    %0d: rl_S_IP_model_wr_addr", cur_cycle);
      $display ("        ", fshow (wa));
   endrule

   rule rl_S_IP_model_wr_data;
      let wd <- pop_o (s0.o_wr_data);
      s0.i_wr_resp.enq (fv_mk_wr_resp (wd, user1));

      $display ("    %0d: rl_S_IP_model_wr_data", cur_cycle);
      $display ("        ", fshow (wd));
   endrule

   rule rl_S_IP_model_rd_addr;
      let ra <- pop_o (s0.o_rd_addr);
      s0.i_rd_data.enq (fv_mk_rd_data (ra));

      $display ("    %0d: rl_S_IP_model_rd_addr", cur_cycle);
      $display ("        ", fshow (ra));
   endrule

   // ================================================================
   // Watchdog

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
