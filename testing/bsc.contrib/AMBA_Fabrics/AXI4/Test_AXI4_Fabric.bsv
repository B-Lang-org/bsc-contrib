// Copyright (c) 2021-2023 Bluespec, Inc.  All Rights Reserved
// Copyright (c) 2024 Rishiyur S. Nikhil.

// SPDX-License-Identifier: BSD-3-Clause

package Test_AXI4_Fabric;

// ================================================================
// Standalone unit tester for AXI4_Fabric.bsv

// The top-level module is: sysTest_AXI4_Fabric

// Instantiates a 2-M, 3-S AXI4 fabric.

// Instantiates 2-M test-generators, connected to fabric M ports 0,1.
// Instantiates 3-S modules, connected to fabric S ports 0,1,2.

// Each M generates 'num_xactions' read and write requests containing,
// in the following fields:
//   axid    source id (0,1)
//   axaddr  a random address
//   axuser  User_struct { wild, M_num, S_num, serial_num }
// AW transactions send W.data = AW.awaddr+1

// Ss (and the fabric, if fabric error) copy awuser into buser, aruser into ruser
// Ss check s_num
// Ss check aw.addr+1 = w.data for AW/W transactions

// Ms check buser/ruser
// Ms check R responses for addr+1=data

// POTENTIAL IMPROVEMENTS:
// * Currently does not generate/test bursts (all transactions are single-beat)

// ================================================================
// Bluespec library imports

import FIFOF       :: *;
import Vector      :: *;
import Connectable :: *;
import LFSR        :: *;

// ----------------
// BSV additional libs

import Semi_FIFOF  :: *;
import GetPut_Aux  :: *;    // for FIFO 'pop'

// ================================================================
// Project imports

import AXI4_Types  :: *;
import AXI4_Fabric :: *;

// ****************************************************************
// Number of rd/wr transactions to generate (by each M).
// This number chosen for reasonable runtime in iverilog.

Integer num_xactions = 10000;

// ================================================================
// Verbosity during simulation on stdout (edit this as desired):
//   0: quiet
//   1: show xactions brief
//   2: show xactions detail

Integer verbosity = 0;

// ================================================================
// Fabric parameters

typedef 2 Num_Ms;
typedef 3 Num_Ss;

typedef TLog #(Num_Ms)   Wd_M_Num;
typedef Bit #(Wd_M_Num)  M_Num;

typedef TLog #(Num_Ss)   Wd_S_Num;
typedef Bit #(Wd_S_Num)  S_Num;

// ----------------
// Address map of the three memory units
// Note: requests to gaps should return error responses

// Mem unit 0
Integer addr_base_0 = 'h_0000_0000;
Integer addr_lim_0  = 'h_0100_0000 - 'h_0000_1000;    // size 16MB - 4KB

// Gap of 4KB

// Mem unit 1
Integer addr_base_1 = 'h_0100_0000;
Integer addr_lim_1  = 'h_0180_0000;    // size 8MB

// Mem unit 2
Integer addr_base_2 = 'h_0180_0000;
Integer addr_lim_2  = 'h_01C0_0000;    // size 4MB

// Gap to 'h_FFFF_FFFF (rest of addr space

Integer addr_msb = 24;    // [24:0]

// ================================================================
// AXI4 parameters

typedef Bit #(20) Serial_Num;    // per-M xaction serial number

typedef 4                               Wd_Id_M;    // M number
typedef TAdd #(Wd_Id_M, TLog #(Num_Ms)) Wd_Id_S;
typedef 25                              Wd_Addr;    // to accomodate upto addr_lim_X
typedef 32                              Wd_Data;    // carries addr+1, for testing

// 'user' field in AXI4 responses contain this struct
typedef struct {
   Bool                   wild;
   Bit #(TLog #(Num_Ms))  m_num;
   Bit #(TLog #(Num_Ss))  s_num;
   Bit #(Wd_Addr)         addr;
   Serial_Num             serial_num;
} User_struct
deriving (Bits, FShow);

typedef SizeOf #(User_struct) Wd_User;

// More compact output than fshow
function Fmt fmt_User_struct (User_struct u);
   Fmt f = $format ("User{m%0d", u.m_num);
   if (u.wild)
      f = f + $format (" wild");
   else
      f = f + $format (" s%0d", u.s_num);
   f = f + $format (" addr:%0h}", u.addr);
   f = f + $format (" #0x%0h}", u.serial_num);
   return f;
endfunction

AXI4_Size axsize_full1 = axsize_32;    // full width of data bus

// ****************************************************************
// Routing function used by crossbar switch

function Tuple2 #(Bool, S_Num)
         fn_addr_to_S_num (Bit #(Wd_Addr) addr);
   if ((fromInteger (addr_base_0) <= addr) && (addr < fromInteger (addr_lim_0)))
      return tuple2 (True, 0);

   else if ((fromInteger (addr_base_1) <= addr) && (addr < fromInteger (addr_lim_1)))
      return tuple2 (True, 1);

   else if ((fromInteger (addr_base_2) <= addr) && (addr < fromInteger (addr_lim_2)))
      return tuple2 (True, 2);

   else
      return tuple2 (False, ?);
endfunction

// ****************************************************************
// M box for stimulus generation

interface Stim_IFC;
   interface AXI4_M_IFC #(Wd_Id_M, Wd_Addr, Wd_Data, Wd_User) ifc_M;
   method Bool completed;
   method ActionValue #(Bool) print_stats;
endinterface

// ----------------------------------------------------------------
// Help functions to create AXI4 packets

function AXI4_AW #(Wd_Id_M, Wd_Addr, Wd_User)
         fv_mkAW (Bit #(Wd_Id_M) id, Bit #(Wd_Addr) addr, Bit #(Wd_User) user);

   return AXI4_AW {awid:     id,
		   awaddr:   addr,
		   awlen:    0,            // 1 beat
		   awsize:   axsize_full1,
		   awburst:  axburst_incr,
		   awlock:   axlock_normal,
		   awcache:  awcache_norm_noncache_nonbuf,
		   awprot:   0,
		   awqos:    0,
		   awregion: 0,
		   awuser:   user};
endfunction

function AXI4_AR #(Wd_Id_M, Wd_Addr, Wd_User)
         fv_mkAR (Bit #(Wd_Id_M) id, Bit #(Wd_Addr) addr, Bit #(Wd_User) user);

   return AXI4_AR {arid:     id,
		   araddr:   addr,
		   arlen:    0,            // 1 beat
		   arsize:   axsize_full1,
		   arburst:  axburst_incr,
		   arlock:   axlock_normal,
		   arcache:  arcache_norm_noncache_nonbuf,
		   arprot:   0,
		   arqos:    0,
		   arregion: 0,
		   aruser:   user};
endfunction

function AXI4_W #(Wd_Data, Wd_User)
         fv_mkW (Bit #(Wd_Data) data, Bit #(Wd_User) user);

   return AXI4_W {wdata: data,
		  wstrb: '1,      // all ones
		  wlast: True,    // Last beat in burst
		  wuser: user};
endfunction

function AXI4_R #(Wd_Id_S, Wd_Data, Wd_User)
         fv_mkR (Bit #(Wd_Id_S) id, Bit #(Wd_Data) data, Bit #(Wd_User) user);
   return AXI4_R {rid:   id,
		  rdata: data,
		  rresp: axi4_resp_okay,
		  rlast: True,            // Last beat in burst
		  ruser: user};
endfunction

function AXI4_B #(Wd_Id_S, Wd_User)
         fv_mkB (Bit #(Wd_Id_S) req_id, Bit #(Wd_User) req_user);
   return AXI4_B {bid:   req_id,
		  bresp: axi4_resp_okay,
		  buser: req_user};
endfunction

// ----------------------------------------------------------------
// An M box for stimulus and responses
// This M box generates 'num_xactions' random AXI4 requests
// and (concurrently) processes the AXI4 responses.

(* synthesize *)
module mkMbox #(parameter Bit #(4) id)  (Stim_IFC);

   // Transactor for interface
   AXI4_Buffer_IFC #(Wd_Id_M, Wd_Addr, Wd_Data, Wd_User) buf_M <- mkAXI4_Buffer;

   // Pseudo-random number generator
   LFSR #(Bit #(32)) lfsr_a <- mkLFSR_32;

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
   // FIFOs of request serial numbers to check against responses.
   // Because responses from different Ss may return in a different order,
   // we keep separate FIFOs for each S.
   // Size of FIFOs should be > latency to S and back.

   // Reads
   Vector #(Num_Ss, FIFOF #(Serial_Num))
   vf_rd_serial_nums <- replicateM (mkSizedFIFOF (256));
   // Writes
   Vector #(Num_Ss, FIFOF #(Serial_Num))
   vf_wr_serial_nums <- replicateM (mkSizedFIFOF (256));

   // ----------------------------------------------------------------
   // Initialize random num generator

   rule rl_init_LFSR (rg_serial_num == 0);
      Vector #(32, Bit #(TAdd #(Wd_Id_M,1))) v = replicate ({id,1'b1});
      Bit #(32) x = truncate (pack (v));
      if (verbosity != 0)
	 $display ("M%0d: lfsr seed is %0h", x);

      lfsr_a.seed (x);
      rg_serial_num <= 1;
   endrule

   // ================================================================
   // Request generation

   // Generate read and write requests
   rule rl_AR_AW ((0 < rg_serial_num) && (rg_serial_num <= fromInteger (num_xactions)));
      let            a32  = lfsr_a.value; lfsr_a.next;
      Bit #(Wd_Addr) addr = truncate (a32);

      // Compute 'user' field
      match { .routable, .s_num } = fn_addr_to_S_num (addr);
      Bool wild = (! routable);
      let u_struct = User_struct {wild:       wild,
				  m_num:      truncate (id),
				  s_num:      s_num,
				  addr:       addr,
				  serial_num: rg_serial_num};
      Bit #(Wd_User) u = pack (u_struct);

      // Read transactions
      if (a32 [31] == 0) begin
	 let ar = fv_mkAR (id, addr, u);
	 buf_M.ifc_S.i_AR.enq (ar);

	 if (! wild) begin
	    vf_rd_serial_nums [s_num].enq (rg_serial_num);
	    rg_num_AR <= rg_num_AR + 1;
	 end
	 else
	    rg_num_AR_wild <= rg_num_AR_wild + 1;

	 if (verbosity == 1) begin
	    $display ("M%0d: ", id, fshow_AR (ar));
	    $display ("M%0d:    ", id, fmt_User_struct (u_struct));
	 end
	 else if (verbosity > 1) begin
	    $display ("M%0d: ", id, fshow    (ar));
	    $display ("M%0d:    ", id, fmt_User_struct (u_struct));
	 end
      end

      // Write transactions
      else begin
	 let aw = fv_mkAW (id, addr, u);
	 buf_M.ifc_S.i_AW.enq (aw);

	 // Enqueue a request to produce W.
	 // The data is addr+1, which will be checked by S
	 Bit #(Wd_Data) d = zeroExtend (addr) + 1;
	 f_W_info.enq (tuple2 (d, u));

	 if (! wild) begin
	    vf_wr_serial_nums [s_num].enq (rg_serial_num);
	    rg_num_AW <= rg_num_AW + 1;
	 end
	 else
	    rg_num_AW_wild <= rg_num_AW_wild + 1;

	 if (verbosity == 1) begin
	    $display ("M%0d: ", id, fshow_AW (aw));
	    $display ("M%0d:    ", id, fmt_User_struct (u_struct));
	 end
	 else if (verbosity > 1) begin
	    $display ("M%0d: ", id, fshow    (aw));
	    $display ("M%0d:    ", id, fmt_User_struct (u_struct));
	 end
      end
      rg_serial_num <= rg_serial_num + 1;
   endrule

   // ----------------
   // M: write data for write-transaction

   rule rl_W;
      match { .data, .user } <- pop (f_W_info);

      let w = fv_mkW (data, user);
      buf_M.ifc_S.i_W.enq (w);

      User_struct u_struct = unpack (user);
      if (verbosity == 1) begin
	 $display ("M%0d: ", id, fshow_W (w));
	 $display ("M%0d:    ", id, fmt_User_struct (u_struct));
      end
      else if (verbosity > 1) begin
	 $display ("M%0d: ", id, fshow   (w));
	 $display ("M%0d:    ", id, fmt_User_struct (u_struct));
      end
   endrule

   // ================================================================
   // Response collection and checking

   // ----------------------------------------------------------------
   // Response-checker function

   function ActionValue #(Bool)
            fav_check_resp (String         rd_wr_s,
			    Bit #(Wd_Id_M) rsp_id,
			    AXI4_Resp      rsp_resp,
			    Bit #(Wd_User) rsp_user,
			    Vector #(Num_Ss, FIFOF #(Serial_Num)) vf_serial_nums);
      actionvalue
	 User_struct user_struct = unpack (rsp_user);

	 let wild       = user_struct.wild;
	 let rsp_s_num  = user_struct.s_num;
	 let rsp_serial = user_struct.serial_num;

	 Bool err = False;

	 // Check if routed correctly (routable)
	 Bool addr_ok = (((! wild) && (rsp_resp == axi4_resp_okay))
			 || (wild && (rsp_resp != axi4_resp_okay)));
	 if (! addr_ok) begin
	    $display ("M%0d: ERROR: %s wild:", id, rd_wr_s, fshow (wild),
		      " but resp:", fshow_AXI4_Resp (rsp_resp));
	    err = True;
	 end
	 else if (id != rsp_id) begin
	    // Check if response returned to correct sender (id)
	    $display ("M%0d: ERROR: %s id (%0d) != rsp_id", id, rd_wr_s, id, rsp_id);
	    err = True;
	 end
	 else if (! wild) begin
	    // Check serial number
	    let exp_serial <- pop (vf_serial_nums [rsp_s_num]);
	    if (exp_serial != rsp_serial) begin
	       $display ("M%0d: ERROR: %s ser num mismatch: expected 0x%0x; response 0x%0x",
			 id, rd_wr_s, exp_serial, rsp_serial);
	       err = True;
	    end
	 end

	 return err;
      endactionvalue
   endfunction

   // Collect R response; display and check
   rule rl_R;
      let r <- pop_o (buf_M.ifc_S.o_R);
      rg_num_R <= rg_num_R + 1;

      User_struct u_struct = unpack (r.ruser);
      if (verbosity == 1) begin
	 $display ("    M%0d: ", id, fshow_R (r));
	 $display ("    M%0d:     ", id, fmt_User_struct (u_struct));
      end

      let err <- fav_check_resp ("R", r.rid, r.rresp, r.ruser, vf_rd_serial_nums);

      if ((r.rresp == axi4_resp_okay)
	  && (r.rdata != zeroExtend (u_struct.addr) + 1)) begin
	 $display ("    M%0d: ERROR: R data != addr+1");
	 err = True;
      end

      if (err || verbosity > 1) begin
	 $display ("    M%0d: ", id, fshow   (r));
	 $display ("    M%0d:     ", id, fmt_User_struct (u_struct));
      end

      if (err) begin
	 $display ("FAIL");
	 $finish (1);
      end
   endrule

   // Collect B response; display and check
   rule rl_B;
      let b <- pop_o (buf_M.ifc_S.o_B);
      rg_num_B <= rg_num_B + 1;

      User_struct u_struct = unpack (b.buser);
      if (verbosity == 1) begin
	 $display ("    M%0d: ", id, fshow_B (b));
	 $display ("    M%0d:     ", id, fmt_User_struct (u_struct));
      end

      let err <- fav_check_resp ("B", b.bid, b.bresp, b.buser, vf_wr_serial_nums);

      if (err || (verbosity > 1)) begin
	 $display ("    M%0d: ", id, fshow   (b));
	 $display ("    M%0d:     ", id, fmt_User_struct (u_struct));
      end

      if (err) begin
	 $display ("FAIL");
	 $finish (1);
      end
   endrule

   // ----------------------------------------------------------------
   // Stimulus generation completion

   rule rl_stimulus_completed (rg_serial_num == fromInteger (num_xactions + 1));
      $display ("M%0d: COMPLETED stimulus generation", id);
      rg_serial_num <= rg_serial_num + 1;
   endrule

   // ================================================================
   // INTERFACE

   interface ifc_M = buf_M.ifc_M;

   method completed = (rg_serial_num >= fromInteger (num_xactions));

   method print_stats;
      actionvalue
	 $display ("M%0d: total requests:%0d",
		   id, rg_num_AR + rg_num_AW + rg_num_AR_wild + rg_num_AW_wild);
	 $display ("        ARs:%7d      AWs:%7d    to supported addrs",
		   rg_num_AR, rg_num_AW);
	 $display ("        ARs:%7d      AWs:%7d    to wild (unsupported) addrs",
		   rg_num_AR_wild, rg_num_AW_wild);
	 $display ("         RS:%7d       BS:%7d", rg_num_R, rg_num_B);
	 Bool ok = ((rg_num_AR + rg_num_AW + rg_num_AR_wild + rg_num_AW_wild)
		    == (rg_num_R + rg_num_B));

	 if (! ok)
	    $display ("Mismatched number of requests and responses");
	 return ok;
      endactionvalue
   endmethod
endmodule: mkMbox

// ****************************************************************
// S box connected to an S port of the fabric
// AXI4 response is computed from AXI4 request.
// Reponse's id and user fields are copied from request.
// For AR request, R.data is set to AR.addr+1 (checked by M)

(* synthesize *)
module mkSbox #(Bit #(4) s_num)
              (AXI4_S_IFC #(Wd_Id_S, Wd_Addr, Wd_Data, Wd_User));

   AXI4_Buffer_IFC #(Wd_Id_S, Wd_Addr, Wd_Data, Wd_User) buf_S <- mkAXI4_Buffer;

   // ================================================================
   // BEHAVIOR

   // Responses for read requests
   rule rl_S_AR;
      let ar <- pop_o (buf_S.ifc_M.o_AR);
      let r   = fv_mkR (ar.arid, zeroExtend (ar.araddr + 1), ar.aruser);
      buf_S.ifc_M.i_R.enq (r);

      User_struct u_struct = unpack (ar.aruser);
      if (verbosity == 1) begin
	 $display ("        S%0d: ", s_num, fshow_AR (ar),
		   " ", fmt_User_struct (u_struct));
	 $display ("        S%0d: ", s_num, fshow_R (r));
      end
      else if (verbosity > 1) begin
	 $display ("        S%0d: ", s_num, fshow (ar),
		   " ", fmt_User_struct (u_struct));
	 $display ("        S%0d: ", s_num, fshow (r));
      end
   endrule

   // Responses for write requests
   rule rl_S_AW;
      let aw <- pop_o (buf_S.ifc_M.o_AW);
      let w  <- pop_o (buf_S.ifc_M.o_W);

      User_struct awuser_struct = unpack (aw.awuser);
      User_struct wuser_struct  = unpack (w.wuser);

      Bool ok = True;

      if (aw.awuser != w.wuser) begin
	 $display ("FAIL");
	 $display ("        S%0d: AW: Expecting aw.awuser == w.wuser", s_num);
	 ok = False;
      end

      if ((zeroExtend (aw.awaddr) + 1) != w.wdata) begin
	 $display ("FAIL");
	 $display ("        S%0d: W: Expecting aw.awaddr + 1 == w.wdata", s_num);
	 ok = False;
      end

      let wr  = fv_mkB (aw.awid, aw.awuser);
      buf_S.ifc_M.i_B.enq (wr);

      if ((! ok) || (verbosity == 1)) begin
	 $display ("        S%0d: ", s_num, fshow_AW (aw));
	 $display ("        S%0d:     ", fmt_User_struct (awuser_struct));
	 $display ("        S%0d: ", s_num, fshow_W (w));
	 $display ("        S%0d:     ", fmt_User_struct (awuser_struct));
      end

      if ((!ok ) || (verbosity > 1)) begin
	 $display ("        S%0d: ", s_num, fshow (aw));
	 $display ("        S%0d:     ", fmt_User_struct (awuser_struct));
	 $display ("        S%0d: ", s_num, fshow (w));
	 $display ("        S%0d:     ", fmt_User_struct (awuser_struct));
      end

      if (! ok)
	 $finish (1);
   endrule

   // ----------------------------------------------------------------

   return buf_S.ifc_S;
endmodule: mkSbox

// ================================================================
// Top-level of this testbench

(* synthesize *)
module sysTest_AXI4_Fabric (Empty);
   // ----------------
   // Ms

   Stim_IFC m0 <- mkMbox (0);
   Stim_IFC m1 <- mkMbox (1);

   Vector #(Num_Ms,
	    AXI4_M_IFC #(Wd_Id_M, Wd_Addr, Wd_Data, Wd_User)) v_Ms = newVector;
   v_Ms [0] = m0.ifc_M;
   v_Ms [1] = m1.ifc_M;

   // ----------------
   // Ss

   AXI4_S_IFC #(Wd_Id_S, Wd_Addr, Wd_Data, Wd_User) s0 <- mkSbox (0);
   AXI4_S_IFC #(Wd_Id_S, Wd_Addr, Wd_Data, Wd_User) s1 <- mkSbox (1);
   AXI4_S_IFC #(Wd_Id_S, Wd_Addr, Wd_Data, Wd_User) s2 <- mkSbox (2);

   Vector #(Num_Ss,
	    AXI4_S_IFC #(Wd_Id_S, Wd_Addr, Wd_Data, Wd_User)) v_Ss = newVector;
   v_Ss [0] = s0;
   v_Ss [1] = s1;
   v_Ss [2] = s2;

   // ----------------
   // AXI4 2x3 crossbar fabric, passing in Ms and Ss

   Empty fabric <- mkAXI4_Fabric (fn_addr_to_S_num, v_Ms, v_Ss);

   // ----------------
   // Linger for 256 cycles after both stimulus Ms have
   // finished generating requests, to allow transactions to complete.

   Reg #(Bit #(12)) rg_linger <- mkReg ('1);

   rule rl_quit (m0.completed && m1.completed);
      if (rg_linger == '1 - 5) begin
	 $display ("All Ms: stimulus generation complete.");
	 $display ("  Lingering to allow in-flight transactions to finish.");
      end

      else if (rg_linger == 1) begin
	 let ok0 <- m0.print_stats;
	 let ok1 <- m1.print_stats;
	 $display ("%s", ((ok0 && ok1) ? "PASS" :"FAIL"));
      end

      else if (rg_linger == 0) begin
	 $finish (0);
      end
      rg_linger <= rg_linger - 1;
   endrule

endmodule: sysTest_AXI4_Fabric

// ================================================================

endpackage
