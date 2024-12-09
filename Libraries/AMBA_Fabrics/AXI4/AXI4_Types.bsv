// Copyright (c) 2019-2023 Bluespec, Inc.  All Rights Reserved
// Copyright (c) 2024 Rishiyur S. Nikhil.

// SPDX-License-Identifier: BSD-3-Clause

package AXI4_Types;

// ================================================================
// Facilities for ARM AXI4, consisting of 5 independent channels:
//   AW (write address), W (write data), B (write response)
//   AR (read address),  R (read data)

// Ref: ARM document:
//    AMBA AXI and ACE Protocol Specification
//    AXI3, AXI4, and AXI4-Lite
//    ACE and ACE-Lite
//    ARM IHI 0022E (ID022613)
//    Issue E, 22 Feb 2013

// ****************************************************************
// BSV library imports

import FIFOF       :: *;
import Connectable :: *;
import Vector      :: *;

// ----------------
// Bluespec misc. libs

import Semi_FIFOF :: *;
import EdgeFIFOFs :: *;

// ****************************************************************
// ****************************************************************
// Section: Basic bus and bus-field types
// ****************************************************************
// ****************************************************************

// ----------------
// AxLen: burst length (# of transfers in a transaction)
//     Burst_Length = AxLEN[7:0] + 1    (1..256)
//     For wrapping bursts, burst length must be 2, 4, 8, or 16.
//     Burst must not cross a 4KB address boundary

typedef Bit #(8)  AXI4_Len;

// ----------------
// AxSIZE    # of bytes in each transfer    (1..128)
typedef Bit #(3)  AXI4_Size;

AXI4_Size  axsize_1   = 3'b_000;
AXI4_Size  axsize_2   = 3'b_001;
AXI4_Size  axsize_4   = 3'b_010;
AXI4_Size  axsize_8   = 3'b_011;
AXI4_Size  axsize_16  = 3'b_100;
AXI4_Size  axsize_32  = 3'b_101;
AXI4_Size  axsize_64  = 3'b_110;
AXI4_Size  axsize_128 = 3'b_111;

function Bit #(8) fv_AXI4_Size_to_num_bytes (AXI4_Size  axi4_size);
   return (case (axi4_size)
	      axsize_1: 1;
	      axsize_2: 2;
	      axsize_4: 4;
	      axsize_8: 8;
	      axsize_16: 16;
	      axsize_32: 32;
	      axsize_64: 64;
	      axsize_128: 128;
	      default: 0;        // Bogus
	   endcase);
endfunction

function AXI4_Size fv_num_bytes_to_AXI4_Size (Bit #(8) num_bytes);
   return (case (num_bytes)
	      1:   axsize_1;
	      2:   axsize_2;
	      4:   axsize_4;
	      8:   axsize_8;
	      16:  axsize_16;
	      32:  axsize_32;
	      64:  axsize_64;
	      128: axsize_128;
	      default: axsize_128;    // Bogus
	   endcase);
endfunction

function Bool fn_addr_is_aligned (Bit #(wd_addr) addr, AXI4_Size size);
   return (    (size == axsize_1)
	   || ((size == axsize_2)   && (addr [0]   == 1'b0))
	   || ((size == axsize_4)   && (addr [1:0] == 2'b0))
	   || ((size == axsize_8)   && (addr [2:0] == 3'b0))
	   || ((size == axsize_16)  && (addr [3:0] == 4'b0))
	   || ((size == axsize_32)  && (addr [4:0] == 5'b0))
	   || ((size == axsize_64)  && (addr [5:0] == 6'b0))
	   || ((size == axsize_128) && (addr [6:0] == 7'b0)));
endfunction

// ----------------
// AxBURST    Burst type

typedef Bit #(2)  AXI4_Burst;

AXI4_Burst  axburst_fixed = 2'b_00;
AXI4_Burst  axburst_incr  = 2'b_01;
AXI4_Burst  axburst_wrap  = 2'b_10;

// ----------------
// AxLOCK
typedef Bit #(1)  AXI4_Lock;

AXI4_Lock  axlock_normal    = 1'b_0;
AXI4_Lock  axlock_exclusive = 1'b_1;

// ----------------
// ARCACHE
typedef Bit #(4)  AXI4_Cache;

AXI4_Cache  arcache_dev_nonbuf           = 'b_0000;
AXI4_Cache  arcache_dev_buf              = 'b_0001;

AXI4_Cache  arcache_norm_noncache_nonbuf = 'b_0010;
AXI4_Cache  arcache_norm_noncache_buf    = 'b_0011;

AXI4_Cache  arcache_wthru_no_alloc       = 'b_1010;
AXI4_Cache  arcache_wthru_r_alloc        = 'b_1110;
AXI4_Cache  arcache_wthru_w_alloc        = 'b_1010;
AXI4_Cache  arcache_wthru_r_w_alloc      = 'b_1110;

AXI4_Cache  arcache_wback_no_alloc       = 'b_1011;
AXI4_Cache  arcache_wback_r_alloc        = 'b_1111;
AXI4_Cache  arcache_wback_w_alloc        = 'b_1011;
AXI4_Cache  arcache_wback_r_w_alloc      = 'b_1111;

// ----------------
// AWCACHE
AXI4_Cache  awcache_dev_nonbuf           = 'b_0000;
AXI4_Cache  awcache_dev_buf              = 'b_0001;

AXI4_Cache  awcache_norm_noncache_nonbuf = 'b_0010;
AXI4_Cache  awcache_norm_noncache_buf    = 'b_0011;

AXI4_Cache  awcache_wthru_no_alloc       = 'b_0110;
AXI4_Cache  awcache_wthru_r_alloc        = 'b_0110;
AXI4_Cache  awcache_wthru_w_alloc        = 'b_1110;
AXI4_Cache  awcache_wthru_r_w_alloc      = 'b_1110;

AXI4_Cache  awcache_wback_no_alloc       = 'b_0111;
AXI4_Cache  awcache_wback_r_alloc        = 'b_0111;
AXI4_Cache  awcache_wback_w_alloc        = 'b_1111;
AXI4_Cache  awcache_wback_r_w_alloc      = 'b_1111;

// ----------------
// PROT
typedef Bit #(3)  AXI4_Prot;

Bit #(1)  axprot_0_unpriv     = 0;    Bit #(1) axprot_0_priv       = 1;
Bit #(1)  axprot_1_secure     = 0;    Bit #(1) axprot_1_non_secure = 1;
Bit #(1)  axprot_2_data       = 0;    Bit #(1) axprot_2_instr      = 1;

// ----------------
// QoS
typedef Bit #(4)  AXI4_QoS;

// ----------------
// REGION
typedef Bit #(4)  AXI4_Region;

// ----------------
// RESP    Response type
typedef Bit #(2)  AXI4_Resp;

AXI4_Resp  axi4_resp_okay   = 2'b_00;
AXI4_Resp  axi4_resp_exokay = 2'b_01;
AXI4_Resp  axi4_resp_slverr = 2'b_10;
AXI4_Resp  axi4_resp_decerr = 2'b_11;

// ----------------
// Expand the AXI4 'wstrb' field into a bit-mask

function Bit #(wd_data) fn_strb_to_bitmask (Bit #(wd_data_B) strb)
   provisos (Mul #(wd_data_B, 8, wd_data));

   function Bit #(8) fn_bit_to_byte (Integer j);
      return ((strb [j] == 1'b0) ? 0 : 'hFF);
   endfunction

   begin
      Vector #(wd_Data_B, Bit #(8)) v_bytes = genWith (fn_bit_to_byte);
      return pack (v_bytes);
   end
endfunction

// ================================================================
// AR,R,AW,W,B struct types

// AW channel (Write Address)

typedef struct {
   Bit #(wd_id)    awid;
   Bit #(wd_addr)  awaddr;
   Bit #(8)        awlen;
   AXI4_Size       awsize;
   Bit #(2)        awburst;
   Bit #(1)        awlock;
   Bit #(4)        awcache;
   Bit #(3)        awprot;
   Bit #(4)        awqos;
   Bit #(4)        awregion;
   Bit #(wd_user)  awuser;
   } AXI4_AW #(numeric type wd_id,
	       numeric type wd_addr,
	       numeric type wd_user)
deriving (Bits, FShow);

// W channel (Write Data)

typedef struct {
   Bit #(wd_data)             wdata;
   Bit #(TDiv #(wd_data, 8))  wstrb;
   Bool                       wlast;
   Bit #(wd_user)             wuser;
   } AXI4_W #(numeric type wd_data,
	      numeric type wd_user)
deriving (Bits, FShow);

// B channel (Write Response)

typedef struct {
   Bit #(wd_id)    bid;
   Bit #(2)        bresp;
   Bit #(wd_user)  buser;
   } AXI4_B #(numeric type wd_id,
	      numeric type wd_user)
deriving (Bits, FShow);

// AR channel (Read Address)

typedef struct {
   Bit #(wd_id)    arid;
   Bit #(wd_addr)  araddr;
   Bit #(8)        arlen;
   AXI4_Size       arsize;
   Bit #(2)        arburst;
   Bit #(1)        arlock;
   Bit #(4)        arcache;
   Bit #(3)        arprot;
   Bit #(4)        arqos;
   Bit #(4)        arregion;
   Bit #(wd_user)  aruser;
   } AXI4_AR #(numeric type wd_id,
	       numeric type wd_addr,
	       numeric type wd_user)
deriving (Bits, FShow);

// R channel (Read Data))

typedef struct {
   Bit #(wd_id)    rid;
   Bit #(wd_data)  rdata;
   Bit #(2)        rresp;
   Bool            rlast;
   Bit #(wd_user)  ruser;
   } AXI4_R #(numeric type wd_id,
	      numeric type wd_data,
	      numeric type wd_user)
deriving (Bits, FShow);

// ================================================================
// The following functions change ID (possibly to different width).
// These are used in interconnect fabrics to 'push' extra id bits on
// M->S request traffic and 'pop' those bits in S->M response traffic.
// The extra bits specify to which M a response should be sent.

function AXI4_AW #(wd_id_out, wd_addr, wd_user)
         fn_change_AW_id (AXI4_AW #(wd_id_in, wd_addr, wd_user) aw_in,
			  Bit #(wd_id_out)                      awid_out);
   let aw_out = AXI4_AW {awid:     awid_out,
			 awaddr:   aw_in.awaddr,
			 awlen:    aw_in.awlen,
			 awsize:   aw_in.awsize,
			 awburst:  aw_in.awburst,
			 awlock:   aw_in.awlock,
			 awcache:  aw_in.awcache,
			 awprot:   aw_in.awprot,
			 awqos:    aw_in.awqos,
			 awregion: aw_in.awregion,
			 awuser:   aw_in.awuser};
   return aw_out;
endfunction

function AXI4_B #(wd_id_out, wd_user)
         fn_change_B_id (AXI4_B #(wd_id_in, wd_user) b_in,
			 Bit #(wd_id_out)            bid_out);
   let b_out = AXI4_B {bid:   bid_out,
		       bresp: b_in.bresp,
		       buser: b_in.buser};
   return b_out;
endfunction

function AXI4_AR #(wd_id_out, wd_addr, wd_user)
         fn_change_AR_id (AXI4_AR #(wd_id_in, wd_addr, wd_user) ar_in,
			  Bit #(wd_id_out)                      arid_out);
   let ar_out = AXI4_AR {arid:     arid_out,
			 araddr:   ar_in.araddr,
			 arlen:    ar_in.arlen,
			 arsize:   ar_in.arsize,
			 arburst:  ar_in.arburst,
			 arlock:   ar_in.arlock,
			 arcache:  ar_in.arcache,
			 arprot:   ar_in.arprot,
			 arqos:    ar_in.arqos,
			 arregion: ar_in.arregion,
			 aruser:   ar_in.aruser};
   return ar_out;
endfunction

function AXI4_R #(wd_id_out, wd_data, wd_user)
         fn_change_R_id (AXI4_R #(wd_id_in, wd_data, wd_user) r_in,
			 Bit #(wd_id_out)                     rid_out);
   let r_out = AXI4_R {rid:   rid_out,
		       rdata: r_in.rdata,
		       rresp: r_in.rresp,
		       rlast: r_in.rlast,
		       ruser: r_in.ruser};
   return r_out;
endfunction

// ================================================================
// The following are specialized 'fshow' functions for AXI4 bus
// payloads: the most common fields, and more compact.

function Fmt fshow_AXI4_Size (AXI4_Size  size);
   Fmt result = ?;
   if      (size == axsize_1)   result = $format ("sz1");
   else if (size == axsize_2)   result = $format ("sz2");
   else if (size == axsize_4)   result = $format ("sz4");
   else if (size == axsize_8)   result = $format ("sz8");
   else if (size == axsize_16)  result = $format ("sz16");
   else if (size == axsize_32)  result = $format ("sz32");
   else if (size == axsize_64)  result = $format ("sz64");
   else if (size == axsize_128) result = $format ("sz128");
   return result;
endfunction

function Fmt fshow_AXI4_Burst (AXI4_Burst  burst);
   Fmt result = ?;
   if      (burst == axburst_fixed)  result = $format ("fixed");
   else if (burst == axburst_incr)   result = $format ("incr");
   else if (burst == axburst_wrap)   result = $format ("wrap");
   else                              result = $format ("burst:%0d", burst);
   return result;
endfunction

function Fmt fshow_AXI4_Resp (AXI4_Resp  resp);
   Fmt result = ?;
   if      (resp == axi4_resp_okay)    result = $format ("okay");
   else if (resp == axi4_resp_exokay)  result = $format ("exokay");
   else if (resp == axi4_resp_slverr)  result = $format ("slverr");
   else if (resp == axi4_resp_decerr)  result = $format ("decerr");
   return result;
endfunction

// ----------------

function Fmt fshow_AW (AXI4_AW #(wd_id, wd_addr, wd_user) x);
   Fmt result = ($format ("AW{id:%0h addr:%0h", x.awid, x.awaddr)
		 + $format (" len:%0d", x.awlen)
		 + $format (" ")
		 + fshow_AXI4_Size (x.awsize)
		 + $format (" ")
		 + fshow_AXI4_Burst (x.awburst)
		 + $format (" user:%0h ..}", x.awuser));
   return result;
endfunction

function Fmt fshow_W (AXI4_W #(wd_data, wd_user) x);
   let result = ($format ("W{data:%0h strb:%0h", x.wdata, x.wstrb)
		 + (x.wlast ? $format (" last") : $format (""))
		 + $format (" user:%0h ..}", x.wuser));
   return result;
endfunction

function Fmt fshow_B (AXI4_B #(wd_id, wd_user) x);
   Fmt result = ($format ("B{id:%0h resp:", x.bid)
		 + fshow_AXI4_Resp (x.bresp)
		 + $format (" user:%0h ..}", x.buser));
   return result;
endfunction

function Fmt fshow_AR (AXI4_AR #(wd_id, wd_addr, wd_user) x);
   Fmt result = ($format ("AR{id:%0h addr:%0h", x.arid, x.araddr)
		 + $format (" len:%0d", x.arlen)
		 + $format (" ")
		 + fshow_AXI4_Size (x.arsize)
		 + $format (" ")
		 + fshow_AXI4_Burst (x.arburst)
		 + $format (" user:%0h ..}", x.aruser));
   return result;
endfunction

function Fmt fshow_R (AXI4_R #(wd_id, wd_data, wd_user) x);
   Fmt result = ($format ("R{id%0h resp:", x.rid)
		 + fshow_AXI4_Resp (x.rresp)
		 + $format (" data:%0h", x.rdata)
		 + (x.rlast ? $format (" last") : $format (""))
		 + $format (" user:%0h ..}", x.ruser));
   return result;
endfunction

// ****************************************************************
// ****************************************************************
// Section: Higher-level FIFO-like interfaces and transactors
// ****************************************************************
// ****************************************************************

// ================================================================
// AXI4 interfaces with BSV FIFO sub-interfaces for each channel
// (instead of RTL ready/valid signaling)

// ----------------
// M interface with FIFOs

interface AXI4_M_IFC  #(numeric type wd_id,
			numeric type wd_addr,
			numeric type wd_data,
			numeric type wd_user);

   interface FIFOF_O #(AXI4_AW #(wd_id, wd_addr, wd_user))  o_AW;
   interface FIFOF_O #(AXI4_W  #(wd_data, wd_user))         o_W;
   interface FIFOF_I #(AXI4_B  #(wd_id, wd_user))           i_B;

   interface FIFOF_O #(AXI4_AR #(wd_id, wd_addr, wd_user))  o_AR;
   interface FIFOF_I #(AXI4_R  #(wd_id, wd_data, wd_user))  i_R;
endinterface

// ----------------
// S interface with FIFOs

interface AXI4_S_IFC  #(numeric type wd_id,
			numeric type wd_addr,
			numeric type wd_data,
			numeric type wd_user);

   interface FIFOF_I #(AXI4_AW #(wd_id, wd_addr, wd_user))  i_AW;
   interface FIFOF_I #(AXI4_W  #(wd_data, wd_user))         i_W;
   interface FIFOF_O #(AXI4_B  #(wd_id, wd_user))           o_B;

   interface FIFOF_I #(AXI4_AR #(wd_id, wd_addr, wd_user))  i_AR;
   interface FIFOF_O #(AXI4_R  #(wd_id, wd_data, wd_user))  o_R;
endinterface

// ----------------
// Connecting AXI4_M_IFC and AXI4_S_IFC

instance Connectable #(AXI4_M_IFC #(wd_id, wd_addr, wd_data, wd_user),
		       AXI4_S_IFC #(wd_id, wd_addr, wd_data, wd_user));

   module mkConnection #(AXI4_M_IFC #(wd_id, wd_addr, wd_data, wd_user) m,
			 AXI4_S_IFC #(wd_id, wd_addr, wd_data, wd_user) s)  (Empty);
      mkConnection (m.o_AW, s.i_AW);
      mkConnection (m.o_W,  s.i_W);
      mkConnection (m.i_B,  s.o_B);
      mkConnection (m.o_AR, s.i_AR);
      mkConnection (m.i_R,  s.o_R);
   endmodule
endinstance

// ================================================================
// Interface of an AXI4 buffer with FIFO-like interfaces on both sides

interface AXI4_Buffer_IFC  #(numeric type wd_id,
			     numeric type wd_addr,
			     numeric type wd_data,
			     numeric type wd_user);
   // Facing upstream
   interface AXI4_S_IFC #(wd_id, wd_addr, wd_data, wd_user) ifc_S;
   // Facing downstream
   interface AXI4_M_IFC #(wd_id, wd_addr, wd_data, wd_user) ifc_M;
endinterface

// ----------------------------------------------------------------
// The following two modules differ only in using mkFIFOF or
// mkM_EdgeFIFOF internally.
// Note: we can't write a single module parameterized by the internal
// FIFOs because mkFIFOF is instantiated at different types.

module mkAXI4_Buffer (AXI4_Buffer_IFC #(wd_id, wd_addr, wd_data, wd_user));

   FIFOF #(AXI4_AW #(wd_id, wd_addr, wd_user))  f_AW <- mkFIFOF;
   FIFOF #(AXI4_W  #(wd_data, wd_user))         f_W  <- mkFIFOF;
   FIFOF #(AXI4_B  #(wd_id, wd_user))           f_B  <- mkFIFOF;

   FIFOF #(AXI4_AR #(wd_id, wd_addr, wd_user))  f_AR <- mkFIFOF;
   FIFOF #(AXI4_R  #(wd_id, wd_data, wd_user))  f_R  <- mkFIFOF;

   interface AXI4_M_IFC ifc_M;
      interface o_AW = to_FIFOF_O (f_AW);
      interface o_W  = to_FIFOF_O (f_W);
      interface i_B  = to_FIFOF_I (f_B);

      interface o_AR = to_FIFOF_O (f_AR);
      interface i_R  = to_FIFOF_I (f_R);
   endinterface

   interface AXI4_S_IFC ifc_S;
      interface i_AW = to_FIFOF_I (f_AW);
      interface i_W  = to_FIFOF_I (f_W);
      interface o_B  = to_FIFOF_O (f_B);

      interface i_AR = to_FIFOF_I (f_AR);
      interface o_R  = to_FIFOF_O (f_R);
   endinterface
endmodule

module mkAXI4_Buffer_2 (AXI4_Buffer_IFC #(wd_id, wd_addr, wd_data, wd_user));

   FIFOF #(AXI4_AW #(wd_id, wd_addr, wd_user))  f_AW <- mkM_EdgeFIFOF;
   FIFOF #(AXI4_W  #(wd_data, wd_user))         f_W  <- mkM_EdgeFIFOF;
   FIFOF #(AXI4_B  #(wd_id, wd_user))           f_B  <- mkS_EdgeFIFOF;

   FIFOF #(AXI4_AR #(wd_id, wd_addr, wd_user))  f_AR <- mkM_EdgeFIFOF;
   FIFOF #(AXI4_R  #(wd_id, wd_data, wd_user))  f_R  <- mkS_EdgeFIFOF;

   interface AXI4_M_IFC ifc_M;
      interface o_AW = to_FIFOF_O (f_AW);
      interface o_W  = to_FIFOF_O (f_W);
      interface i_B  = to_FIFOF_I (f_B);

      interface o_AR = to_FIFOF_O (f_AR);
      interface i_R  = to_FIFOF_I (f_R);
   endinterface

   interface AXI4_S_IFC ifc_S;
      interface i_AW = to_FIFOF_I (f_AW);
      interface i_W  = to_FIFOF_I (f_W);
      interface o_B  = to_FIFOF_O (f_B);

      interface i_AR = to_FIFOF_I (f_AR);
      interface o_R  = to_FIFOF_O (f_R);
   endinterface
endmodule

// ****************************************************************

endpackage
