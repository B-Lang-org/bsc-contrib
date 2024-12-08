// Copyright (c) 2021-2023 Bluespec, Inc. All Rights Reserved
// Copyright (c) 2024 Rishiyur S. Nikhil

// SPDX-License-Identifier: BSD-3-Clause

package Test_AXI4_to_LDST;

// ****************************************************************
// Standalone unit tester for AXI4_Deburster.bsv

// ****************************************************************
// Bluespec library imports

import FIFOF       :: *;
import Connectable :: *;
import Vector      :: *;
import StmtFSM     :: *;

// ----------------
// BSV additional libs

import Cur_Cycle  :: *;
import Semi_FIFOF     :: *;

// ================================================================
// Local imports

import AXI4_Types   :: *;
import AXI4_to_LDST :: *;

// ****************************************************************

Integer verbosity = 0;

// ================================================================
// Synthesized instance of module

typedef  16 Wd_Id;
typedef  64 Wd_Addr;
typedef 512 Wd_AXI_Data;
typedef   0 Wd_User;

typedef  64 Wd_LDST_Data;

typedef AXI4_to_LDST_IFC #(Wd_Id,
			   Wd_Addr,
			   Wd_AXI_Data,
			   Wd_User,
			   Wd_LDST_Data) AXI4_to_LDST_1_IFC;

/* DELETE
(* synthesize *)
module mkAXI4_to_LDST_1 (AXI4_to_LDST_1_IFC);
   let m <- mkAXI4_to_LDST;
   return m;
endmodule
*/

// ================================================================

(* synthesize *)
module sysTest_AXI4_to_LDST (Empty);

   // Transactor representing M
   AXI4_Buffer_IFC  #(Wd_Id, Wd_Addr, Wd_AXI_Data, Wd_User)
   axi4_M_xactor <- mkAXI4_Buffer;

   // The DUT
   AXI4_to_LDST_1_IFC dut <- mkAXI4_to_LDST (axi4_M_xactor.ifc_M);

   // This bool controls whether we issue the next AXI request only
   // after the prev one has responded, or whether we pipeline them.
   Reg #(Bool) rg_one_at_a_time <- mkReg (True);
   Reg #(Bool) rg_prev_done     <- mkReg (True);

   function Stmt fa_set_one_at_a_time (Bool b);
      return seq
		delay (32);    // To allow quiescence
		action
		   rg_one_at_a_time <= b;
		   $display ("================================================================");
		   if (b)
		      $display ("%0d: INFO: Setting Mode to: one-at-a-time", cur_cycle);
		   else
		      $display ("%0d: INFO: Setting Mode to: pipelined, cur_cycle", cur_cycle);
		endaction
	     endseq;
   endfunction

   // ================================================================
   // Templates for AXI structs (we modify these slightly in tests)

   AXI4_AW #(Wd_Id, Wd_Addr, Wd_User) aw0 = AXI4_AW {awid: 0,
						     awaddr: 'h_8000_0000,
						     awlen:  (1 - 1),
						     awsize: axsize_8,
						     awburst: axburst_incr,
						     awlock: 0,
						     awcache: 0,
						     awprot: 0,
						     awqos: 0,
						     awregion: 0,
						     awuser: 0};

   AXI4_AR #(Wd_Id, Wd_Addr, Wd_User) ar0 = AXI4_AR {arid: 0,
						     araddr: 'h_8000_0000,
						     arlen:  (1 - 1),
						     arsize: axsize_8,
						     arburst: axburst_incr,
						     arlock: 0,
						     arcache: 0,
						     arprot: 0,
						     arqos: 0,
						     arregion: 0,
						     aruser: 0};

   // 'values' is a vector of bytes [0, 1, 2, ...]
   function Bit #(8) fn_for_vector_gen (Integer i);
      return fromInteger (i);
   endfunction

   Vector #(TDiv #(Wd_AXI_Data, 8), Bit #(8)) values = genWith (fn_for_vector_gen);

   AXI4_W #(Wd_AXI_Data, Wd_User) w0 = AXI4_W {wdata: pack (values),
					       wstrb: '1,
					       wlast: True,
					       wuser: 0};

   function Action fa_show_axi_data (Bit #(Wd_AXI_Data) axi_data);
      action
	 Vector #(TDiv #(Wd_AXI_Data, Wd_LDST_Data),
		  Bit #(Wd_LDST_Data))               v_slices = unpack (axi_data);

	 Integer slices_per_axi_data_I = valueOf (TDiv #(Wd_AXI_Data, Wd_LDST_Data));

	 for (Integer row = 0; row < 2; row = row + 1) begin
	    $write ("    ");
	    for (Integer col = 0; col < 4; col = col + 1)
	       $write (" %016h", v_slices [row * 4 + (3 - col)]);    // little-endian
	    $display ("");
	 end
      endaction
   endfunction

   // ================================================================
   // The following rules handle the LD/ST requests emerging from
   // the AXI4_to_LDST transformer, returning synthetic responses.

   // ----------------
   // Store request handler

   rule rl_st_handler;
      match { .sizecode, .addr, .data } = dut.st_reqs.first;
      dut.st_reqs.deq;

      $write ("%0d:   rl_st_handler:", cur_cycle);
      case (sizecode)
	 2'b00: $write (" SB");
	 2'b01: $write (" SH");
	 2'b10: $write (" SW");
	 2'b11: $write (" SD");
      endcase
      $display (" addr %0h data %16h", addr, data);

      Bool aligned = (    (sizecode == ldst_b)
		      || ((sizecode == ldst_h) && (addr [0]   == 1'b0))
		      || ((sizecode == ldst_w) && (addr [1:0] == 2'b00))
		      || ((sizecode == ldst_d) && (addr [2:0] == 3'b000)));
      if (! aligned) begin
	 $display ("%0d: ERROR: rl_st_handler", cur_cycle);
	 $display ("    MISALIGNED sizecode %0h addr %0h data %0h", sizecode, addr, data);
      end

      dut.st_rsps.enq (! aligned);
   endrule

   // ----------------
   // Load request handler

   rule rl_ld_handler;
      match { .sizecode, .addr } = dut.ld_reqs.first;
      dut.ld_reqs.deq;

      Bool aligned = (    (sizecode == ldst_b)
		      || ((sizecode == ldst_h) && (addr [0]   == 1'b0))
		      || ((sizecode == ldst_w) && (addr [1:0] == 2'b00))
		      || ((sizecode == ldst_d) && (addr [2:0] == 3'b000)));

      let shift_amt = ((addr & 'h3F) << 3);
      Bit #(Wd_LDST_Data) rdata = truncate (pack (values) >> shift_amt);
      case (sizecode)
	 2'b00: rdata = (rdata & 'h_FF);
	 2'b01: rdata = (rdata & 'h_FFFF);
	 2'b10: rdata = (rdata & 'h_FFFF_FFFF);
      endcase

      $write ("%0d:   rl_ld_handler:", cur_cycle);
      case (sizecode)
	 2'b00: begin $write (" LB"); rdata = (rdata & 'h_FF); end
	 2'b01: begin $write (" LH"); rdata = (rdata & 'h_FFFF); end
	 2'b10: begin $write (" LW"); rdata = (rdata & 'h_FFFF_FFFF); end
	 2'b11: begin $write (" LD"); end
      endcase
      $write (" addr %0h", addr);
      $display (" => data %0h", rdata);

      if (! aligned) begin
	 $display ("%0d: ERROR: rl_ld_handler", cur_cycle);
	 $display ("    MISALIGNED sizecode %0h addr %0h", sizecode, addr);
      end

      dut.ld_rsps.enq (tuple2 ((! aligned), rdata));
   endrule

   // ================================================================
   // The following rules handle the final AXI responses

   // ----------------
   // AXI Wr_Resp sink

   rule rl_AXI4_B;
      let b <- pop_o (axi4_M_xactor.ifc_S.o_B);
      rg_prev_done <= True;

      $display ("%0d: rl_AXI4_B: ", cur_cycle, fshow (b));

      if (b.bid == '1) begin
	 $display ("    Sentinel b (bid == '1); exit");
	 $finish (0);
      end
   endrule

   // ----------------
   // AXI Rd_Data sink

   rule rl_AXI4_R;
      let r <- pop_o (axi4_M_xactor.ifc_S.o_R);
      rg_prev_done <= True;

      $display ("%0d: rl_AXI4_R: ", cur_cycle);
      $display ("    rid %0h  resp %0h  rlast %0h  ruser %0h",
		r.rid, r.rresp, r.rlast, r.ruser);
      fa_show_axi_data (r.rdata);

      if (r.rid == '1) begin
	 $display ("    Sentinel r (rid == '1); exit");
	 $finish (0);
      end
   endrule

   // ================================================================
   // Stimulus (AXI4 requests and responses)

   // ----------------

   function Action fa_wr_REQ (AXI4_AW #(Wd_Id, Wd_Addr, Wd_User) aw,
			      AXI4_W  #(Wd_AXI_Data, Wd_User)    w,
			      Bit #(16) id,
			      Bit #(64) addr,
			      AXI4_Size axsize);
      action
	 await ((! rg_one_at_a_time) || rg_prev_done);
	 aw.awid   = id;
	 aw.awaddr = addr;
	 aw.awsize = axsize;
	 axi4_M_xactor.ifc_S.i_AW.enq (aw);
	 axi4_M_xactor.ifc_S.i_W.enq (w);
	 if (rg_one_at_a_time)
	    rg_prev_done <= False;

	 $display ("================");
	 $display ("%0d: fa_wr_REQ: id %0h addr %0h sizecode %0h (0x%0h bytes) strb %016h",
		   cur_cycle,
		   id, addr,
		   axsize, fv_AXI4_Size_to_num_bytes (axsize),
		   w.wstrb);
	 fa_show_axi_data (w.wdata);
      endaction
   endfunction

   // ----------------

   function Action fa_rd_REQ (AXI4_AR #(Wd_Id, Wd_Addr, Wd_User) ar,
			      Bit #(16) id,
			      Bit #(64) addr,
			      AXI4_Size axsize);
      action
	 await ((! rg_one_at_a_time) || rg_prev_done);
	 ar.arid   = id;
	 ar.araddr = addr;
	 ar.arsize = axsize;
	 axi4_M_xactor.ifc_S.i_AR.enq (ar);
	 if (rg_one_at_a_time)
	    rg_prev_done <= False;

	 $display ("================");
	 $display ("%0d: fa_rd_REQ: id %0h addr %0h sizecode %0h (0x%0h bytes)",
		   cur_cycle,
		   id, addr,
		   axsize, fv_AXI4_Size_to_num_bytes (axsize));
      endaction
   endfunction

   // ----------------
   // Stimulus tests

   function Stmt test_illegal_wr_req (Bit #(16) id);
      return seq
		// ----------------
		// - num beats > 1
		// - wlast is True on first beat
		// - AWSIZE wider than axi data bus (when axi data bus < widest allowed)
		action
		   let aw1 = aw0;
		   aw1.awlen = 2;
		   let wr_data1 = w0;
		   wr_data1.wlast = True;
		   Integer num_bytes_axi_data = (valueOf (Wd_AXI_Data) / 8);
		   let axsize = axsize_32;
		   if (valueOf (Wd_AXI_Data) < 1024)
		      axsize = fv_num_bytes_to_AXI4_Size (fromInteger (num_bytes_axi_data * 2));
		   fa_wr_REQ (aw1, wr_data1, id, 'h_ffff_ffff, axsize);
		endaction
		// Send 2 more wr_data since awlen = 2
		axi4_M_xactor.ifc_S.i_W.enq (w0);
		axi4_M_xactor.ifc_S.i_W.enq (w0);
	     endseq;
   endfunction

   function Stmt test_illegal_rd_req (Bit #(16) id);
      return seq
		// ----------------
		// - num beats > 1
		// - AWSIZE wider than axi data bus (when axi data bus < widest allowed)
		action
		   let rd_addr1 = ar0;
		   rd_addr1.arlen = 2;
		   Integer num_bytes_axi_data = (valueOf (Wd_AXI_Data) / 8);
		   let axsize = axsize_32;
		   if (valueOf (Wd_AXI_Data) < 1024)
		      axsize = fv_num_bytes_to_AXI4_Size (fromInteger (num_bytes_axi_data * 2));
		   fa_rd_REQ (rd_addr1, id, 'h_ffff_ffff, axsize);
		endaction
	     endseq;
   endfunction

   function Stmt test_writes (Bool mode, Bit #(16) id0);
      return seq
		fa_set_one_at_a_time (mode);    // True: one-at-a-time, False: Pipelined

		test_illegal_wr_req (id0 + 1);

		// Addr at non-zero bytelane, varying sizes
		fa_wr_REQ (aw0, w0, id0 + 2, 'h_8000_0025, axsize_8);
		fa_wr_REQ (aw0, w0, id0 + 3, 'h_8000_0025, axsize_16);
		fa_wr_REQ (aw0, w0, id0 + 4, 'h_8000_0025, axsize_32);
		fa_wr_REQ (aw0, w0, id0 + 5, 'h_8000_0025, axsize_64);

		// Full data: aligned addr, size 64
		fa_wr_REQ (aw0, w0, id0 + 'h10, 'h_4000_0000, axsize_64);

		// Addr at non-zero bytelane, rest of size-window
		fa_wr_REQ (aw0, w0, id0 + 'h20, 'h_0001_0009, axsize_8);

		// Addr at non-zero bytelane, rest of size-window, reduced by wstrb
		action
		   let wr_data1 = w0;
		   wr_data1.wstrb = 'h_0000_0000_0000_7E00;
		   fa_wr_REQ (aw0, wr_data1, id0 + 'h21, 'h_0001_0009, axsize_8);
		endaction
	     endseq;
   endfunction

   function Stmt test_reads (Bool mode, Bit #(16) id0);
      return seq
		fa_set_one_at_a_time (mode);    // True: one-at-a-time, False: Pipelined

		test_illegal_rd_req (id0 + 1);

		// Addr at non-zero bytelane, varying sizes
		fa_rd_REQ (ar0, id0 + 2, 'h_8000_0025, axsize_8);
		fa_rd_REQ (ar0, id0 + 3, 'h_8000_0025, axsize_16);
		fa_rd_REQ (ar0, id0 + 4, 'h_8000_0025, axsize_32);
		fa_rd_REQ (ar0, id0 + 5, 'h_8000_0025, axsize_64);

		// Full data: aligned addr, size 64
		fa_rd_REQ (ar0, id0 + 'h10, 'h_4000_0000, axsize_64);

		// Addr at non-zero bytelane, rest of size-window
		fa_rd_REQ (ar0, id0 + 'h20, 'h_0001_0009, axsize_8);
	     endseq;
   endfunction

   // ----------------
   // Stimulus FSM
   // Set 'if (True/False)' below to do/skip tests.

   FSM fsm_reqs <- mkFSM
   (seq
       test_writes (True,  'h1000);    // one-at-a-time
       test_writes (False, 'h2000);    // pipelined

       test_reads (True,   'h3000);    // one-at-a-time
       test_reads (False,  'h4000);    // pipelined

       delay (1024);    // Drain all pipelines

       // ----------------
       // Sentinel (last) test signalled by arid/awid = '1
       // only one of the follwing is needed

       // fa_wr_REQ (aw0, w0, '1, 'h_ffff_ffff, axsize_8);
       fa_rd_REQ (ar0, '1, 'h_ffff_ffff, axsize_8);
    endseq);

   // ----------------
   // Start the FSM

   Reg #(Bool) rg_fsm_started <- mkReg (False);

   rule rl_start (! rg_fsm_started);
      fsm_reqs.start;
      rg_fsm_started <= True;
   endrule

endmodule

// ================================================================

endpackage
