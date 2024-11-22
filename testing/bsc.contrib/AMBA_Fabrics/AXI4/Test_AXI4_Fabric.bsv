// Copyright (c) 2021-2024 Bluespec, Inc. All Rights Reserved
//
// SPDX-License-Identifier: BSD-3-Clause

/*
  Unit test for AXI4_Fabric

  This test attempts to recreate traffic patterns that were observed
  to cause data corruption in an SoC.

  The fabric is instantiated with 3 M and 4 S ports. One S is
  connected to a DDR model, the rest are unconnected and unused.  Two
  M ports connect to M A and M B modules, defined here.  The third M
  port is unconnected and unused.

  M A behaves like a host.  For the tests here, it will read 32-bits
  from a single memory location (not overlapping with M B), bitwise
  invert the value, and write it back to the same location.

  M B behaves like uncached access from the processor in AWSteria.
  Across a 4kiB region of memory, it will perform the following, all
  as 32-bit accesses: (1) write zeros, (2) write sequential integers,
  and (3) read back check the integers.

  Various aspects of the behavior of the M and S modules may be
  adjusted.  See the struct TestParams.

  There are 5 test cases defined.  Supply '-D TESTCASE=<n>' to bsc
  to select which to compile.

*/

package Test_AXI4_Fabric;

import Assert ::*;
import BUtils ::*;
import Connectable ::*;
import FIFOF ::*;
import LFSR ::*;
import StmtFSM ::*;

import Semi_FIFOF ::*;

import AXI4_Deburster ::*;
import AXI4_Fabric ::*;
import AXI4_Types ::*;
import AXI4_Widener ::*;
import AXI4_DDR_Model ::*;

// ================================================================
// Help functions

function Action write_word_addr (AXI4_M_Xactor_IFC #(nid, naddr, ndata, nuser) xactor,
				 Bit#(naddr)                                   addr)
   provisos(
      Mul#(nbytes,8,ndata),
      // per bsc
      Mul#(32, a__, ndata)
      );
   action
      AXI4_Wr_Addr#(nid, naddr, nuser) wrreq = AXI4_Wr_Addr {
	 awid: 0,
	 awaddr: addr,
	 awlen: 0,
	 awsize: axsize_8,
	 awburst: 0,
	 awlock: 0,
	 awcache: 0,
	 awprot: 0,
	 awqos: 0,
	 awregion: 0,
	 awuser: 0
	 };

      xactor.i_wr_addr.enq(wrreq);
   endaction
endfunction

function Action write_word_data(AXI4_M_Xactor_IFC#(nid, naddr, ndata, nuser) xactor, Bit#(naddr) addr, Bit#(32) data)
   provisos(
      Mul#(nbytes,8,ndata),
      Add#(strbmask,1,nbytes),
      // per bsc
      Mul#(32, a__, ndata)
      );
   action
      AXI4_Wr_Data#(ndata, nuser) wrdata = AXI4_Wr_Data {
	 wdata: duplicate(data),
	 wstrb: 'hf << (addr & fromInteger(valueof(strbmask))),
	 wlast: True,
	 wuser: 0
	 };

      xactor.i_wr_data.enq(wrdata);
   endaction
endfunction

function Action write_word(AXI4_M_Xactor_IFC#(nid, naddr, ndata, nuser) xactor, Bit#(naddr) addr, Bit#(32) data)
   provisos(
      Mul#(nbytes,8,ndata),
      // per bsc
      Mul#(32, a__, ndata),
      Add#(b__, 1, nbytes)
      );
   action
      write_word_addr(xactor, addr);
      write_word_data(xactor, addr, data);
   endaction
endfunction

function Action write_word_resp(AXI4_M_Xactor_IFC#(nid, naddr, ndata, nuser) xactor);
   action
      xactor.o_wr_resp.deq;
   endaction
endfunction

function Action read_word_addr(AXI4_M_Xactor_IFC#(nid, naddr, ndata, nuser) xactor, Bit#(naddr) addr)
   provisos(
      Mul#(nbytes,8,ndata),
      // per bsc
      Mul#(32, a__, ndata)
      );
   action
      AXI4_Rd_Addr#(nid, naddr, nuser) rdreq = AXI4_Rd_Addr {
	 arid: 0,
	 araddr: addr,
	 arlen: 0,
	 arsize: axsize_8,
	 arburst: 0,
	 arlock: 0,
	 arcache: 0,
	 arprot: 0,
	 arqos: 0,
	 arregion: 0,
	 aruser: 0
	 };

      xactor.i_rd_addr.enq(rdreq);
   endaction
endfunction

function ActionValue#(Bit#(32)) read_word_data(AXI4_M_Xactor_IFC#(nid, naddr, ndata, nuser) xactor, Bit#(naddr) addr)
   provisos(
      Mul#(nbytes,8,ndata),
      // per bsc
      Mul#(32, a__, ndata)
      );
   actionvalue
      let rddata = xactor.o_rd_data.first;
      xactor.o_rd_data.deq;
      Bit#(naddr) addrmask = fromInteger(valueOf(nbytes)) - 1;
      return cExtend(rddata.rdata >> ((addr & addrmask) * 8));
   endactionvalue
endfunction

// ================================================================

module mkLatencyFIFO#(Integer cycles)(FIFOF#(t))
   provisos(Bits#(t, a__));

   Bit#(32) bcycles = fromInteger(cycles);

   staticAssert((bcycles >= 0) && (bcycles <= 256), "cycles must be between 0 and 256, inclusive");
   staticAssert((bcycles == 0) || ((bcycles & (bcycles - 1)) == 0), "non-zero cycles must be a power of two");

   Bit#(32) mask = bcycles - 1;
   Reg#(Maybe#(Bit#(32))) count <- mkReg(tagged Invalid);
   let lfsr <- mkLFSR_8;

   FIFOF#(t) f_in <- mkLFIFOF;
   FIFOF#(t) f_out <- mkLFIFOF;

   if (bcycles == 0)
      mkConnection(to_FIFOF_O(f_in), to_FIFOF_I(f_out));
   else begin
      rule rl_start(count matches tagged Invalid &&& f_in.notEmpty);
	 count <= tagged Valid (cExtend(lfsr.value) & mask);
	 lfsr.next;
      endrule

      rule rl_count(count matches tagged Valid .x &&& x != 0);
	 count <= tagged Valid (x - 1);
      endrule

      rule rl_forward(count matches tagged Valid .x &&& x == 0);
	 count <= tagged Invalid;
	 f_out.enq(f_in.first);
	 f_in.deq;
      endrule
   end

   method enq = f_in.enq;
   method deq = f_out.deq;
   method first = f_out.first;
   method notFull = f_in.notFull;
   method notEmpty = f_out.notEmpty;
   method Action clear();
      action
	 f_in.clear;
	 f_out.clear;
	 count <= tagged Invalid;
      endaction
   endmethod
endmodule

// ================================================================

module mkAXI4LatencyInjection#(Integer req_cycles, Integer resp_cycles)
   (Tuple2#(
      AXI4_M_IFC #(nid, naddr, ndata, nuser),
      AXI4_S_IFC #(nid, naddr, ndata, nuser)));

   AXI4_M_Xactor_IFC#(nid, naddr, ndata, nuser) m <- mkAXI4_M_Xactor;
   AXI4_S_Xactor_IFC#(nid, naddr, ndata, nuser) s <- mkAXI4_S_Xactor;

   FIFOF#(AXI4_Wr_Addr#(nid, naddr, nuser)) f_wr_addr <- mkLatencyFIFO(req_cycles);
   FIFOF#(AXI4_Wr_Data#(ndata, nuser)) f_wr_data <- mkLatencyFIFO(req_cycles);
   FIFOF#(AXI4_Wr_Resp#(nid, nuser)) f_wr_resp <- mkLatencyFIFO(resp_cycles);

   FIFOF#(AXI4_Rd_Addr#(nid, naddr, nuser)) f_rd_addr <- mkLatencyFIFO(req_cycles);
   FIFOF#(AXI4_Rd_Data#(nid, ndata, nuser)) f_rd_data <- mkLatencyFIFO(resp_cycles);

   mkConnection(m.i_wr_addr, to_FIFOF_O(f_wr_addr));
   mkConnection(to_FIFOF_I(f_wr_addr), s.o_wr_addr);

   mkConnection(m.i_wr_data, to_FIFOF_O(f_wr_data));
   mkConnection(to_FIFOF_I(f_wr_data), s.o_wr_data);

   mkConnection(m.o_wr_resp, to_FIFOF_I(f_wr_resp));
   mkConnection(to_FIFOF_O(f_wr_resp), s.i_wr_resp);

   mkConnection(m.i_rd_addr, to_FIFOF_O(f_rd_addr));
   mkConnection(to_FIFOF_I(f_rd_addr), s.o_rd_addr);

   mkConnection(m.o_rd_data, to_FIFOF_I(f_rd_data));
   mkConnection(to_FIFOF_O(f_rd_data), s.i_rd_data);

   return tuple2(m.axi_side, s.axi_side);
endmodule

// ================================================================

// continually read and write address 0x1000
module mkM_A(AXI4_M_IFC#(nid, naddr, ndata, nuser))
   provisos(
      // per bsc
      Add#(a__, 1, b__),
      Mul#(b__, 8, ndata),
      Mul#(32, c__, ndata)
   );
   AXI4_M_Xactor_IFC#(nid, naddr, ndata, nuser) xactor <- mkAXI4_M_Xactor;

   Reg#(Bit#(32)) iter <- mkReg(1);
   Reg#(Bit#(32)) data <- mkRegU;
   Reg#(Bit#(4)) r <- mkRegU;
   let lfsr <- mkLFSR_4;

   Stmt s =
   seq
      write_word(xactor, 'h1000, 'haaaaaaaa);
      write_word_resp(xactor);

      while (True) seq
	 if (iter % 1000 == 0)
	    $display("A %d", iter);
	 iter <= iter + 1;

	 read_word_addr(xactor, 'h0004);
	 action
	    let d <- read_word_data(xactor, 'h0004);
	 endaction

	 read_word_addr(xactor, 'h1000);
	 action
	    let d <- read_word_data(xactor, 'h1000);
	    data <= d;
	 endaction

	 write_word(xactor, 'h1000, ~data);
	 write_word_resp(xactor);

	 action
	    lfsr.next;
	    r <= cExtend(lfsr.value);
	 endaction
	 while (r > 0)
	    r <= r - 1;
      endseq
   endseq;

   let fsm <- mkAutoFSM(s);

   return xactor.axi_side;
endmodule

// ================================================================

module mkM_A_Parallel(AXI4_M_IFC#(nid, naddr, ndata, nuser))
   provisos(
      // per bsc
      Add#(a__, 1, b__),
      Mul#(b__, 8, ndata),
      Mul#(32, c__, ndata)
   );
   AXI4_M_Xactor_IFC#(nid, naddr, ndata, nuser) xactor <- mkAXI4_M_Xactor;

   Reg#(Bit#(32)) iter <- mkReg(1);
   Reg#(Bit#(32)) data <- mkRegU;
   Reg#(Bit#(4)) r <- mkRegU;
   let lfsr <- mkLFSR_4;

   Stmt s =
   seq
      write_word(xactor, 'h1000, 'haaaaaaaa);
      write_word_resp(xactor);

      par
	 while (True) seq
	    if (iter % 1000 == 0)
	       $display("A %d", iter);
	    iter <= iter + 1;

	    read_word_addr(xactor, 'h1000);
	    action
	       let d <- read_word_data(xactor, 'h1000);
	       data <= d;
	    endaction

	    action
	       lfsr.next;
	       r <= cExtend(lfsr.value);
	    endaction
	    while (r > 0)
	       r <= r - 1;
	 endseq

	 while (True) seq
	    write_word(xactor, 'h1000, ~data);
	 endseq

	 while (True) seq
	    write_word_resp(xactor);
	 endseq
      endpar
   endseq;

   let fsm <- mkAutoFSM(s);

   return xactor.axi_side;
endmodule

// ================================================================

module mkM_A_SplitWrite(AXI4_M_IFC#(nid, naddr, ndata, nuser))
   provisos(
      // per bsc
      Add#(a__, 1, b__),
      Mul#(b__, 8, ndata),
      Mul#(32, c__, ndata)
   );
   AXI4_M_Xactor_IFC#(nid, naddr, ndata, nuser) xactor <- mkAXI4_M_Xactor;

   Reg#(Bit#(32)) iter <- mkReg(1);
   Reg#(Bit#(32)) data <- mkRegU;
   Reg#(Bit#(4)) r <- mkRegU;
   let lfsr <- mkLFSR_4;

   Stmt s =
   seq
      write_word_addr(xactor, 'h1000);
      write_word_data(xactor, 'h1000, 'haaaaaaaa);
      write_word_resp(xactor);

      while (True) seq
	 if (iter % 1000 == 0)
	    $display("A %d", iter);
	 iter <= iter + 1;

	 read_word_addr(xactor, 'h0004);
	 action
	    let d <- read_word_data(xactor, 'h0004);
	 endaction

	 read_word_addr(xactor, 'h1000);
	 action
	    let d <- read_word_data(xactor, 'h1000);
	    data <= d;
	 endaction

	 write_word_data(xactor, 'h1000, ~data);
	 action
	    lfsr.next;
	    r <= cExtend(lfsr.value);
	 endaction
	 while (r > 0)
	    r <= r - 1;
	 write_word_addr(xactor, 'h1000);
	 write_word_resp(xactor);

	 action
	    lfsr.next;
	    r <= cExtend(lfsr.value);
	 endaction
	 while (r > 0)
	    r <= r - 1;
      endseq
   endseq;

   let fsm <- mkAutoFSM(s);

   return xactor.axi_side;
endmodule

// ================================================================

// sweep addresses 0 through 0xfff
//   write zero
//   write sequential integers
//   read and check integers
module mkM_B(AXI4_M_IFC#(nid, naddr, ndata, nuser))
   provisos(
      // per bsc
      Add#(a__, 1, b__),
      Mul#(b__, 8, ndata),
      Mul#(32, c__, ndata)
   );
   AXI4_M_Xactor_IFC#(nid, naddr, ndata, nuser) xactor <- mkAXI4_M_Xactor;

   Reg#(Bit#(64)) data <- mkRegU;
   Reg#(Bit#(32)) i <- mkRegU;
   Reg#(Bit#(32)) j <- mkRegU;
   Reg#(Bit#(32)) iter <- mkReg(1);

   Stmt s =
   seq
      while (True) seq
	 if (iter % 10 == 0)
	    $display("B %d", iter);
	 iter <= iter + 1;

	 par
	    for (i <= 0; i < 'h400; i <= i + 1) seq
	       write_word(xactor, cExtend(i * 4), cExtend(0));
	    endseq

	    for (j <= 0; j < 'h400; j <= j + 1) seq
	       write_word_resp(xactor);
	    endseq
	 endpar

	 par
	    for (i <= 0; i < 'h400; i <= i + 1) seq
	       write_word(xactor, cExtend(i * 4), cExtend(i));
	    endseq

	    for (j <= 0; j < 'h400; j <= j + 1) seq
	       write_word_resp(xactor);
	    endseq
	 endpar

	 seq
	    for (i <= 0; i < 'h400; i <= i + 1) seq
	       read_word_addr(xactor, cExtend(i * 4));
	       action
		  let d <- read_word_data(xactor, cExtend(i * 4));
		  if (cExtend(d) != i) begin
		     $display("FAIL addr %x (!= %x)", i, d);
		     $finish;
		  end
	       endaction
	    endseq
	 endseq
      endseq
   endseq;

   let fsm <- mkAutoFSM(s);

   return xactor.axi_side;
endmodule

// ================================================================

module mkM_B_SplitWrite(AXI4_M_IFC#(nid, naddr, ndata, nuser))
   provisos(
      // per bsc
      Add#(a__, 1, b__),
      Mul#(b__, 8, ndata),
      Mul#(32, c__, ndata)
   );
   AXI4_M_Xactor_IFC#(nid, naddr, ndata, nuser) xactor <- mkAXI4_M_Xactor;

   Reg#(Bit#(32)) iter <- mkReg(1);
   Reg#(Bit#(64)) data <- mkRegU;
   Reg#(Bit#(32)) i <- mkRegU;
   Reg#(Bit#(32)) j <- mkRegU;
   Reg#(Bit#(4)) r <- mkRegU;
   let lfsr <- mkLFSR_4;

   Stmt s =
   seq
      while (True) seq
	 if (iter % 10 == 0)
	    $display("B %d", iter);
	 iter <= iter + 1;

	 par
	    for (i <= 0; i < 'h400; i <= i + 1) seq
	       write_word_data(xactor, cExtend(i * 4), cExtend(0));
	       write_word_addr(xactor, cExtend(i * 4));
	    endseq

	    for (j <= 0; j < 'h400; j <= j + 1) seq
	       write_word_resp(xactor);
	    endseq
	 endpar

	 par
	    for (i <= 0; i < 'h400; i <= i + 1) seq
	       write_word_data(xactor, cExtend(i * 4), cExtend(i));
	       action
		  lfsr.next;
		  r <= cExtend(lfsr.value);
	       endaction
	       while (r > 0)
		  r <= r - 1;
	       write_word_addr(xactor, cExtend(i * 4));
	    endseq

	    for (j <= 0; j < 'h400; j <= j + 1) seq
	       write_word_resp(xactor);
	    endseq
	 endpar

	 seq
	    for (i <= 0; i < 'h400; i <= i + 1) seq
	       read_word_addr(xactor, cExtend(i * 4));
	       action
		  let d <- read_word_data(xactor, cExtend(i * 4));
		  if (cExtend(d) != i) begin
		     $display("FAIL addr %x (!= %x)", i, d);
		     $finish;
		  end
	       endaction
	    endseq
	 endseq
      endseq
   endseq;

   let fsm <- mkAutoFSM(s);

   return xactor.axi_side;
endmodule

typedef enum {
   Normal,
   DDR
   } MemType deriving (Bits, Eq);

typedef enum {
   Normal,
   Parallel,
   SplitWrite
   } M_A_Type deriving (Bits, Eq);

typedef enum {
   Normal,
   Narrow,
   Narrow_SplitWrite
   } M_B_Type deriving (Bits, Eq);

typedef struct {
   MemType  mem_type;
   M_A_Type m_a_type;
   M_B_Type m_b_type;
   Integer  s_request_latency;
   Integer  s_response_latency;
   Integer  m_request_latency;
   Integer  m_response_latency;
   } TestParams deriving (Bits, Eq);

instance DefaultValue#(TestParams);
   defaultValue = TestParams {
      mem_type: DDR,
      m_a_type: Normal,
      m_b_type: Normal,
      s_request_latency: 0,
      s_response_latency: 0,
      m_request_latency: 0,
      m_response_latency: 0
      };
endinstance

function Action fn_print_params (TestParams params);
   action
      case (params.mem_type)
	 Normal: $display ("  mem_type = Normal");
	 DDR:    $display ("  mem_type = DDR");
      endcase
      case (params.m_a_type)
	 Normal:     $display ("  m_a_type = Normal");
	 Parallel:   $display ("  m_a_type = Parallel");
	 SplitWrite: $display ("  m_a_type = SplitWrite");
      endcase
      case (params.m_b_type)
	 Normal:            $display ("  m_b_type = Normal");
	 Narrow:            $display ("  m_b_type = Narrow");
	 Narrow_SplitWrite: $display ("  m_b_type = Narrow_SplitWrite");
      endcase
      $display ("  s_request_latency  = %0d", params.s_request_latency);
      $display ("  s_response_latency = %0d", params.s_response_latency);
      $display ("  m_request_latency  = %0d", params.m_request_latency);
      $display ("  m_response_latency = %0d", params.m_response_latency);
   endaction
endfunction

// ================================================================

typedef  16  Nid;
typedef  64  Naddr;
typedef 512  Ndata;
typedef   0  Nuser;

typedef   2  Num_Ms;
typedef   1  Num_Ss;

(* synthesize *)
module mkAXI4_Fabric_inst (AXI4_Fabric_IFC#(Num_Ms, Num_Ss, Nid, Naddr, Ndata, Nuser));
   function fn_addr(addr);
      return tuple2(True, 0);
   endfunction

   let m <- mkAXI4_Fabric (fn_addr);
   return m;
endmodule

// ================================================================

module mkTestGenerator#(TestParams params)(Empty)
   provisos(
      NumAlias#(nid, 16),
      NumAlias#(naddr, 64),
      NumAlias#(ndata, 512),
      NumAlias#(nuser, 0),
      NumAlias#(num_Ms, 2),
      NumAlias#(num_Ss, 1)
      // NumAlias#(num_Ms, 3),
      // NumAlias#(num_Ss, 4)
      );
   function fn_addr(addr);
      return tuple2(True, 0);
   endfunction

   // AXI4_Fabric_IFC#(num_Ms, num_Ss, nid, naddr, ndata, nuser) fabric <- mkAXI4_Fabric(fn_addr);
   AXI4_Fabric_IFC#(num_Ms, num_Ss, nid, naddr, ndata, nuser) fabric <- mkAXI4_Fabric_inst;

   if (params.mem_type == Normal) begin
      staticAssert(False, "normal memory not supported yet");

      //let mem <- mkMem_Model(0, 0, False, "", 0, 'h80000000, 'h80000000);
      AXI4_Deburster_IFC#(nid, naddr, ndata, nuser) deburster <- mkAXI4_Deburster;

      //mkConnection(deburster.to_S, mem);
      mkConnection(fabric.v_to_Ss[0], deburster.from_M);
   end
   else if (params.mem_type == DDR) begin
      let mem <- mkDDR_A_Model;
      Tuple2#(
	 AXI4_M_IFC #(nid, naddr, ndata, nuser),
	 AXI4_S_IFC #(nid, naddr, ndata, nuser)) mem_latency <-
            mkAXI4LatencyInjection(params.s_request_latency, params.s_response_latency);

      mkConnection(tpl_1(mem_latency), mem);
      mkConnection(fabric.v_to_Ss[0], tpl_2(mem_latency));
   end

   AXI4_M_IFC#(nid, naddr, ndata, nuser) m_a = ?;
   if (params.m_a_type == Normal)
      m_a <- mkM_A;
   else if (params.m_a_type == Parallel)
      m_a <- mkM_A_Parallel;
   else if (params.m_a_type == SplitWrite)
      m_a <- mkM_A_SplitWrite;
   else
      staticAssert(False, "M A type not supported");

   AXI4_M_IFC#(nid, naddr, ndata, nuser) m_b = ?;
   AXI4_M_IFC#(nid, naddr, 64, nuser) m_b_orig = ?;
   if (params.m_b_type == Normal)
      m_b <- mkM_B;
   else if (params.m_b_type == Narrow) begin
      m_b_orig <- mkM_B;
   end
   else if (params.m_b_type == Narrow_SplitWrite)
      m_b_orig <- mkM_B_SplitWrite;
   else
      staticAssert(False, "M B type not supported");

   if (params.m_b_type != Normal) begin
      AXI4_Widener_IFC#(nid, naddr, 64, ndata, nuser) widener <- mkAXI4_Widener;
      mkConnection(m_b_orig, widener.from_M);
      m_b = widener.to_S;
   end

   Tuple2#(
      AXI4_M_IFC #(nid, naddr, ndata, nuser),
      AXI4_S_IFC #(nid, naddr, ndata, nuser)) m_a_latency <-
         mkAXI4LatencyInjection(params.m_request_latency, params.m_response_latency);

   Tuple2#(
      AXI4_M_IFC #(nid, naddr, ndata, nuser),
      AXI4_S_IFC #(nid, naddr, ndata, nuser)) m_b_latency <-
         mkAXI4LatencyInjection(params.m_request_latency, params.m_response_latency);

   mkConnection(m_a, tpl_2(m_a_latency));
   mkConnection(tpl_1(m_a_latency), fabric.v_from_Ms[0]);

   mkConnection(m_b, tpl_2(m_b_latency));
   mkConnection(tpl_1(m_b_latency), fabric.v_from_Ms[1]);
endmodule

// ================================================================

module mkTestCase#(Integer n)(Empty);
   TestParams params = defaultValue;

   if (n == 1) begin
      // default
   end
   else if (n == 2) begin
      params.m_b_type = Narrow;
   end
   else if (n == 3) begin
      params.m_a_type = SplitWrite;
      params.m_b_type = Narrow;
   end
   else if (n == 4) begin
      params.m_a_type = SplitWrite;
      params.m_b_type = Narrow_SplitWrite;
      params.s_response_latency = 16;
   end
   else if (n == 5) begin
      params.m_b_type = Narrow;
      params.m_request_latency = 16;
      params.m_response_latency = 16;
      params.s_request_latency = 16;
      params.s_response_latency = 16;
   end
   else begin
      staticAssert(False, "invalid test case");
   end

   let _ifc <- mkTestGenerator(params);

   // ----------------
   Reg #(Bool) rg_once_done <- mkReg (False);

   rule rl_once (! rg_once_done);
      $display ("params:");
      fn_print_params (params);
      rg_once_done <= True;
   endrule
endmodule

// ================================================================

(* synthesize *)
module sysTest_AXI4_Fabric (Empty);

   Integer n = 1;

   Integer time_limit = (genC ? 100000000 : 10000000);

`ifdef TESTCASE
   n = `TESTCASE;
`endif

   let test <- mkTestCase(n);

   // This FSM just stops the test after a suitable delay
   Stmt s =
   seq
      $display("test %d", n);
      while (True) seq
	 action
	    let t <- $time;
	    if (t > fromInteger (time_limit)) begin
	    // if (t > 1000000) begin
	       $display("PASS");
	       $finish;
	    end
	 endaction
      endseq
   endseq;

   let fsm <- mkAutoFSM(s);
endmodule

endpackage
