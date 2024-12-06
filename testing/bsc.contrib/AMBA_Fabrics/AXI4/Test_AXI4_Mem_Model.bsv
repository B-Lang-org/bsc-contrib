// Copyright (c) 2021-2023 Bluespec, Inc.  All Rights Reserved
// Copyright (c) 2024 Rishiyur S. Nikhil.

// SPDX-License-Identifier: BSD-3-Clause

package Test_AXI4_Mem_Model;

// ================================================================
// Standalone unit tester for AXI4_Mem_Model.bsv

// The top-level module is: sysTest_AXI4_Mem_Model

// Instantiates an Mbox (stimulus generator)
// Instantiates a memory module (which is an Sbox) passing in the MBox.

// The Mbox generates 'num_xactions' read and write requests containing
// random values in:
//   axid, axaddr, axuser        (both in and out of bounds)
//   wdata, wstrb, wuser
// Currently does not do read or write bursts.

// The Mbox contains a register file for a "reference memory"
// Each request is sent into the AXI4 port, and also performed in the reference memory.

// For B responses,
//     The same write is performed on "reference memory"
//     check: bid == awid, buser == awuser
// For R responses:
//     The same read is performed on "reference memory" and checked with rdata
//     check: rid == arid, ruser == aruser

// POTENTIAL IMPROVEMENTS:
// * Currently does not generate/test bursts (all transactions are single-beat)

// ================================================================
// Bluespec library imports

import Vector      :: *;
import FIFOF       :: *;
import RegFile     :: *;
import LFSR        :: *;

// ----------------
// BSV additional libs

import Semi_FIFOF  :: *;
import GetPut_Aux  :: *;    // for FIFO 'pop'

// ================================================================
// Project imports

import AXI4_Types     :: *;
import AXI4_Mem_Model :: *;

// ****************************************************************
// Number of rd/wr transactions to generate (by each M).
// This number chosen for reasonable runtime in iverilog.

Integer num_xactions = 10000;

// ================================================================
// Simulation verbosity during simulation on stdout for this package (edit as desired)
//   0: quiet
//   1: show xactions brief
//   2: show xactions detail

Integer verbosity = 0;

// ================================================================
// Fabric parameters

// ================================================================
// AXI4 parameters

typedef Bit #(20) Serial_Num;    // xaction serial number

typedef 5  Wd_Id;    // M number
typedef 14 Wd_Addr;  // to accomodate upto addr_lim
typedef 32 Wd_Data;  // == 4 Bytes

AXI4_Size axsize_full = axsize_4;    // full width of data bus

// 'user' field in AXI4 responses contain this struct
typedef struct {
   Bit #(10)   user;
   Serial_Num  serial_num;
} User_struct
deriving (Bits, FShow);

typedef SizeOf #(User_struct) Wd_User;

// More compact output than fshow
function Fmt fmt_User_struct (User_struct u);
   Fmt f = $format ("User{user:%0h #0x%0h}", u.user, u.serial_num);
   return f;
endfunction

// ================================================================
// Addresses for the Mem_Model

Integer addr_base = 'h_2000;    // 8KB
Integer addr_lim  = 'h_3000;    // size 4 KB

// Memory is implemented with Bit #(Wd_Data) words (4 bytes wide)

typedef 12 Wd_AddrMW;    // width of address of memword

Integer addrMW_base = addr_base / 4;
Integer addrMW_lim  = addr_lim  / 4;

// ****************************************************************
// M box for stimulus generation

interface Stim_IFC;
   interface AXI4_M_IFC #(Wd_Id, Wd_Addr, Wd_Data, Wd_User) ifc_M;
   method Bool completed;
   method Action print_stats;
endinterface

// ----------------------------------------------------------------
// Currently we don't stream requests to memory, because we have no
// mechanism to order reads and writes, which travel on entirely
// separate busses (and thus may be serviced by memory out of order).

// So, the MBox is a simple state machine

typedef enum {STATE_INIT_1,
	      STATE_INIT_2,
	      STATE_Ax,
	      STATE_W,
	      STATE_B,
	      STATE_R } State
deriving (Bits, Eq, FShow);

// ----------------------------------------------------------------
// Help functions to create AXI4 packets

function AXI4_AW #(Wd_Id, Wd_Addr, Wd_User) fv_mkAW (Bit #(Wd_Id)   id,
						     Bit #(Wd_Addr) addr,
						     Bit #(Wd_User) user);

   return AXI4_AW {awid:     id,
		   awaddr:   addr,
		   awlen:    0,            // 1 beat
		   awsize:   axsize_full,
		   awburst:  axburst_incr,
		   awlock:   axlock_normal,
		   awcache:  awcache_norm_noncache_nonbuf,
		   awprot:   0,
		   awqos:    0,
		   awregion: 0,
		   awuser:   user};
endfunction

function AXI4_AR #(Wd_Id, Wd_Addr, Wd_User) fv_mkAR (Bit #(Wd_Id)   id,
						     Bit #(Wd_Addr) addr,
						     Bit #(Wd_User) user);

   return AXI4_AR {arid:     id,
		   araddr:   addr,
		   arlen:    0,            // 1 beat
		   arsize:   axsize_full,
		   arburst:  axburst_incr,
		   arlock:   axlock_normal,
		   arcache:  arcache_norm_noncache_nonbuf,
		   arprot:   0,
		   arqos:    0,
		   arregion: 0,
		   aruser:   user};
endfunction

function AXI4_W #(Wd_Data, Wd_User) fv_mkW (Bit #(Wd_Data)            data,
					    Bit #(TDiv #(Wd_Data, 8)) strb,
					    Bit #(Wd_User)            user);

   return AXI4_W {wdata: data,
		  wstrb: strb,
		  wlast: True,    // Last beat in burst
		  wuser: user};
endfunction

function AXI4_R #(Wd_Id, Wd_Data, Wd_User) fv_mkR (Bit #(Wd_Id)   id,
						   Bit #(Wd_Data) data,
						   Bit #(Wd_User) user);
   return AXI4_R {rid:   id,
		  rdata: data,
		  rresp: axi4_resp_okay,
		  rlast: True,            // Last beat in burst
		  ruser: user};
endfunction

function AXI4_B #(Wd_Id, Wd_User) fv_mkB (Bit #(Wd_Id)   req_id,
					  Bit #(Wd_User) req_user);
   return AXI4_B {bid:   req_id,
		  bresp: axi4_resp_okay,
		  buser: req_user};
endfunction

// ----------------------------------------------------------------
// M box for stimulus and responses.
// This M box generates 'num_xactions' random AXI4 requests
// and (concurrently) receives and checks the AXI4 responses.

(* synthesize *)
module mkMbox #(parameter Bit #(4) m_id)  (Stim_IFC);

   // Transactor for interface
   AXI4_Buffer_IFC #(Wd_Id, Wd_Addr, Wd_Data, Wd_User) buf_M <- mkAXI4_Buffer;

   // ----------------
   // Pseudo-random number generators
   LFSR #(Bit #(32)) lfsr_a <- mkLFSR_32;  // {1'r/w, 5'id, 10'axuser, 4'xxxx, 12'addr}

   function ActionValue #(Tuple4 #(Bool, Bit #(5), Bit #(10), Bit #(12)))
            fn_lfsr_a_fields;
      actionvalue
	 let            x32     = lfsr_a.value; lfsr_a.next;
	 Bool           is_read = (x32 [31] == 1'b0);
	 Bit #(Wd_Id)   id      = x32 [30:26];
	 Bit #(10)      user    = x32 [25:16];
	 Bit #(12)      offset  = x32 [11:0];
	 return tuple4 (is_read, id, user, offset);
      endactionvalue
   endfunction

   LFSR #(Bit #(32)) lfsr_b <- mkLFSR_32;  // wdata
   LFSR #(Bit #(32)) lfsr_c <- mkLFSR_32;  // {16'xxxx, 10'wuser, 4'wstrb}

   function ActionValue #(Tuple2 #(Bit #(10), Bit #(4)))
            fn_lfsr_c_fields;
      actionvalue
	 let       x32   = lfsr_a.value; lfsr_a.next;
	 Bit #(10) user  = x32 [13:4];
	 Bit #(4)  wstrb = x32 [3:0];
	 return tuple2 (user, wstrb);
      endactionvalue
   endfunction

   // ----------------
   // When we gen AW, this queue holds info to generate corresponding W
   FIFOF #(Tuple2 #(Bit #(Wd_Data), Bit #(Wd_User))) f_W_info <- mkFIFOF;

   // Transaction serial number
   Reg #(Serial_Num) rg_serial_num <- mkReg (0);

   // Statistics
   Reg #(Bit #(32)) rg_num_AR      <- mkReg (0);    // read requests
   Reg #(Bit #(32)) rg_num_AW      <- mkReg (0);    // write requests
   Reg #(Bit #(32)) rg_num_AR_wild <- mkReg (0);    // read/write reqs to wild addrs
   Reg #(Bit #(32)) rg_num_AW_wild <- mkReg (0);    // read/write reqs to wild addrs
   Reg #(Bit #(32)) rg_num_R       <- mkReg (0);    // read responses
   Reg #(Bit #(32)) rg_num_B       <- mkReg (0);    // write responses

   // ----------------
   // Reference memory

   RegFile #(Bit #(Wd_AddrMW),
	     Bit #(Wd_Data)) ref_mem <- mkRegFile (fromInteger (addrMW_base),
						   fromInteger (addrMW_lim - 1));

   // ----------------

   Reg #(State) rg_state <- mkReg (STATE_INIT_1);

   Reg #(AXI4_AW #(Wd_Id, Wd_Addr, Wd_User)) rg_AW <- mkRegU;
   Reg #(AXI4_W  #(Wd_Data, Wd_User))        rg_W  <- mkRegU;
   Reg #(AXI4_AR #(Wd_Id, Wd_Addr, Wd_User)) rg_AR <- mkRegU;

   // ================================================================

   Reg #(Bit #(Wd_AddrMW)) rg_addrMW <- mkReg (fromInteger (addrMW_base));

   rule rl_init_1 (rg_state == STATE_INIT_1);
      lfsr_a.seed (32'h_1111_1111);
      lfsr_b.seed (32'h_2222_2222);
      lfsr_c.seed (32'h_4444_4444);
      rg_state <= STATE_INIT_2;

      $display ("================================");
      $display ("Test_AXI4_Mem_Model: initialization");
      $display ("    addr_base:0x%0h  addr_lim:0x%0h", addr_base, addr_lim);
      $display ("    addrMW_base:0x%0h  addrMW_lim:0x%0h (word addrs)",
		addrMW_base, addrMW_lim);
      $display ("    AXI4 params: Wd_Id:%0d  Wd_Addr:%0d  Wd_Data:%0d  Wd_User:%0d",
		valueOf (Wd_Id), valueOf (Wd_Addr), valueOf (Wd_Data), valueOf (Wd_User));
      $display ("    Memory contains %0d words, each wd_data bits (%0d bytes) wide",
		addrMW_lim - addrMW_base, valueOf (Wd_Data) / 8);
      $display ("    Zeroing reference memory");
      $display ("================================");
   endrule

   rule rl_init_2 (rg_state == STATE_INIT_2);
      ref_mem.upd (rg_addrMW, 0);
      if (rg_addrMW != fromInteger (addrMW_lim - 1))
	 rg_addrMW <= rg_addrMW + 1;
      else begin
	 $display ("Test_AXI4_Mem_Model: zero'd reference memory");
	 rg_state <= STATE_Ax;
      end
   endrule

   // ================================================================
   // Request generation

   // Generate read and write requests
   rule rl_AR_AW ((rg_state == STATE_Ax)
		  && (rg_serial_num < fromInteger (num_xactions)));
      match {.is_read, .id, .user, .offset} <- fn_lfsr_a_fields;

      Bit #(Wd_Addr) addr = fromInteger (addr_base) + zeroExtend (offset);

      // Compute 'axuser' field
      let u_struct = User_struct {user:       user,
				  serial_num: rg_serial_num};
      Bit #(Wd_User) axuser = pack (u_struct);
      rg_serial_num <= rg_serial_num + 1;

      if (verbosity != 0)
	 $display ("----------------");

      // Read transactions
      if (is_read) begin
	 let ar = fv_mkAR (id, addr, axuser);
	 buf_M.ifc_S.i_AR.enq (ar);
	 rg_num_AR <= rg_num_AR + 1;

	 // Save for response-checking
	 rg_AR    <= ar;
	 rg_state <= STATE_R;

	 if (verbosity == 1)
	    $display ("mkMBox%0d: ", m_id, fshow_AR (ar));
	 else if (verbosity > 1)
	    $display ("mkMBox%0d: ", m_id, fshow    (ar));
      end

      // Write transactions
      else begin
	 let aw = fv_mkAW (id, addr, axuser);
	 buf_M.ifc_S.i_AW.enq (aw);
	 rg_num_AW <= rg_num_AW + 1;

	 // Save for W generation and response-checking
	 rg_AW    <= aw;
	 rg_state <= STATE_W;

	 if (verbosity == 1)
	    $display ("mkMBox%0d: ", m_id, fshow_AW (aw));
	 else if (verbosity > 1)
	    $display ("mkMBox%0d: ", m_id, fshow    (aw));
      end

      if (verbosity != 0)
	 $display ("mkMBox%0d:    ", m_id, fmt_User_struct (u_struct));
   endrule

   // ----------------
   // M: write data for write-transaction

   rule rl_W (rg_state == STATE_W);
      let aw = rg_AW;

      let wdata = lfsr_b.value; lfsr_b.next;
      match {.user, .wstrb} <- fn_lfsr_c_fields;

      // Compute 'wuser' field
      let u_struct = User_struct {user:       user,
				  serial_num: unpack (aw.awuser).serial_num};
      Bit #(Wd_User) wuser = pack (u_struct);

      let w     = fv_mkW (wdata, wstrb, wuser);
      buf_M.ifc_S.i_W.enq (w);

      // Save for response-checking
      rg_W     <= w;
      rg_state <= STATE_B;

      if (verbosity == 1) begin
	 $display ("mkMBox%0d: ", m_id, fshow_W (w));
	 $display ("mkMBox%0d:    ", m_id, fmt_User_struct (u_struct));
      end
      else if (verbosity > 1) begin
	 $display ("mkMBox%0d: ", m_id, fshow   (w));
	 $display ("mkMBox%0d:    ", m_id, fmt_User_struct (u_struct));
      end
   endrule

   // ----------------------------------------------------------------
   // Stimulus generation completion

   rule rl_stimulus_completed (rg_serial_num == fromInteger (num_xactions + 1));
      $display ("mkMBox%0d: COMPLETED stimulus generation", m_id);
      rg_serial_num <= rg_serial_num + 1;
   endrule

   // ================================================================
   // Response collection and checking

   // ----------------------------------------------------------------
   // B responses

   rule rl_B (rg_state == STATE_B);
      let b <- pop_o (buf_M.ifc_S.o_B);
      rg_num_B <= rg_num_B + 1;

      Bool err = False;
      if (rg_AW.awid != b.bid) begin
	 $display ("ERROR: rl_B: awid != bid");
	 err = True;
      end

      if (rg_AW.awuser != b.buser) begin
	 $display ("ERROR: rl_B: awuser != buser");
	 err = True;
      end

      // Perform the same write on reference memory
      if ((! err) && (b.bresp == axi4_resp_okay)) begin
	 Bit #(Wd_AddrMW) addrMW = truncateLSB (rg_AW.awaddr);
	 let            old_d32 = ref_mem.sub (addrMW);
	 Bit #(Wd_Data) mask    = fn_strb_to_bitmask (rg_W.wstrb);
	 let            new_d32 = (old_d32 & (~ mask)) | (rg_W.wdata & mask);
	 ref_mem.upd (addrMW, new_d32);
      end

      // Brief display
      if ((! err) && (verbosity == 1)) begin
	 $display ("Ok: rl_B");
	 $display ("    ", fshow_AW (rg_AW));
	 $display ("    ", fshow_W  (rg_W));
	 $display ("    ", fshow_B  (b));
	 $display ("        ", fmt_User_struct (unpack (b.buser)));
      end

      // Longer display
      if (err || (verbosity > 1)) begin
	 if (! err)
	    $display ("Ok: rl_B");
	 $display ("    ", fshow_AW (rg_AW));
	 $display ("        ", fmt_User_struct (unpack (rg_AW.awuser)));
	 $display ("    ", fshow_W  (rg_W));
	 $display ("        ", fmt_User_struct (unpack (rg_W.wuser)));
	 $display ("    ", fshow_B  (b));
	 $display ("        ", fmt_User_struct (unpack (b.buser)));
      end

      if (err) begin
	 $display ("FAIL");
	 $finish (1);
      end
      rg_state <= STATE_Ax;
   endrule

   // ----------------------------------------------------------------
   // R responses

   rule rl_R (rg_state == STATE_R);
      let r <- pop_o (buf_M.ifc_S.o_R);
      rg_num_R <= rg_num_R + 1;

      Bool err = False;
      if (rg_AR.arid != r.rid) begin
	 $display ("ERROR: rl_R: arid != rid");
	 err = True;
      end

      if (rg_AR.aruser != r.ruser) begin
	 $display ("ERROR: rl_R: aruser != ruser");
	 err = True;
      end

      // Perform the same read on reference memory
      if ((! err) && (r.rresp == axi4_resp_okay)) begin
	 Bit #(Wd_AddrMW) addrMW = truncateLSB (rg_AR.araddr);
	 let              old_d32 = ref_mem.sub (addrMW);
	 if (old_d32 != r.rdata) begin
	    $display ("ERROR: rl_R: rdata != expected value");
	    $display ("    addrMW:          %0h", addrMW);
	    $display ("    ref mem data:    %0h", old_d32);
	    $display ("    mem model rdata: %0h", r.rdata);
	    err = True;
	 end
      end

      // Brief display
      if ((! err) && (verbosity == 1)) begin
	 $display ("Ok: rl_R");
	 $display ("    ", fshow_AR (rg_AR));
	 $display ("    ", fshow_R  (r));
	 $display ("        ", fmt_User_struct (unpack (r.ruser)));
      end

      // Longer display
      if (err || (verbosity > 1)) begin
	 if (! err)
	    $display ("Ok: rl_R");
	 $display ("    ", fshow_AR (rg_AR));
	 $display ("        ", fmt_User_struct (unpack (rg_AR.aruser)));
	 $display ("    ", fshow_R  (r));
	 $display ("        ", fmt_User_struct (unpack (r.ruser)));
      end

      if (err) begin
	 $display ("FAIL");
	 $finish (1);
      end
      rg_state <= STATE_Ax;
   endrule

   // ================================================================
   // INTERFACE

   interface ifc_M = buf_M.ifc_M;

   method completed = (rg_serial_num >= fromInteger (num_xactions));

   method print_stats;
      action
	 $display ("mkMBox%0d: total requests:%0d",
		   m_id, rg_num_AR + rg_num_AW + rg_num_AR_wild + rg_num_AW_wild);
	 $display ("        ARs:%7d      AWs:%7d    to supported addrs",
		   rg_num_AR, rg_num_AW);
	 $display ("        ARs:%7d      AWs:%7d    to wild (unsupported) addrs",
		   rg_num_AR_wild, rg_num_AW_wild);
	 $display ("         RS:%7d       BS:%7d", rg_num_R, rg_num_B);
	 Bool ok = ((rg_num_AR + rg_num_AW + rg_num_AR_wild + rg_num_AW_wild)
		    == (rg_num_R + rg_num_B));

	 if (ok)
	    $display ("PASS");
	 else begin
	    $display ("Mismatched number of requests and responses");
	    $display ("FAIL");
	 end
      endaction
   endmethod
endmodule: mkMbox

// ****************************************************************
// Top-level of this testbench

(* synthesize *)
module sysTest_AXI4_Mem_Model (Empty);
   // ----------------
   // Ms

   Stim_IFC m0 <- mkMbox (0);

   Empty _ifc <- mkAXI4_Mem_Model (0, fromInteger (addr_base), fromInteger (addr_lim),
				   True,        // init to zero
				   False,       // init from memhex file
				   "memhex_filename",
				   m0.ifc_M);

   // ----------------
   // Linger for 256 cycles after both stimulus Ms have
   // finished generating requests, to allow transactions to complete.

   Reg #(Bit #(12)) rg_linger <- mkReg ('1);

   rule rl_quit (m0.completed);
      if (rg_linger == '1 - 5) begin
	 $display ("sysTest_AXI4_Mem_Model: All Ms: stimulus generation complete.");
	 $display ("    Lingering to allow in-flight transactions to finish.");
      end

      else if (rg_linger == 1)
	 let ok0 <- m0.print_stats;

      else if (rg_linger == 0) begin
	 $finish (0);
      end
      rg_linger <= rg_linger - 1;
   endrule

endmodule

// ================================================================

endpackage
