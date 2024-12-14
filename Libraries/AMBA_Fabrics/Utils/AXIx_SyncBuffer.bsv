// Copyright (c) 2021-2024 Bluespec, Inc. All Rights Reserved

// SPDX-License-Identifier: BSD-3-Clause

package AXIx_SyncBuffer;

// ================================================================
// This package can be used for both AXI4 and AXI4L.
// This package defines a clock-domain-crossing buffer for an AXI bus

// The interfaces are FIFOF-like (not RTL-level AMBA signals).
// The module merely contains 5 standard SyncFIFOs for each of the 5
// AXI4 or AXI4 Lite channels.

// ================================================================
// Bluespec library imports

import Clocks      :: *;
import Connectable :: *;

// ----------------
// Bluespec misc. libs

import GetPut_Aux :: *;
import Semi_FIFOF :: *;

// ================================================================
// Project imports

// -- none

// ================================================================
// The AXIx_SyncBuffer interface.
// Note: AXIx (not AXI4 or AXI4L) because it can be used for both

interface AXIx_SyncBuffer_IFC #(type aw, type w, type b, type ar, type r);
   interface AXIx_S_IFC #(aw, w, b, ar, r) from_M;
   interface AXIx_M_IFC #(aw, w, b, ar, r) to_S;
endinterface

// ----------------
// The interface for the SyncBuffer

interface AXIx_M_IFC #(type aw, type w, type b, type ar, type r);
   interface FIFOF_O #(aw)  o_aw;
   interface FIFOF_O #(w)   o_w;
   interface FIFOF_I #(b)   i_b;
   interface FIFOF_O #(ar)  o_ar;
   interface FIFOF_I #(r)   i_r;
endinterface

interface AXIx_S_IFC #(type aw, type w, type b, type ar, type r);
   interface FIFOF_I #(aw)  i_aw;
   interface FIFOF_I #(w)   i_w;
   interface FIFOF_O #(b)   o_b;
   interface FIFOF_I #(ar)  i_ar;
   interface FIFOF_O #(r)   o_r;
endinterface

instance Connectable #(AXIx_M_IFC #(aw, w, b, ar, r),
		       AXIx_S_IFC #(aw, w, b, ar, r));

   module mkConnection #(AXIx_M_IFC #(aw, w, b, ar, r) m,
			 AXIx_S_IFC #(aw, w, b, ar, r) s)  (Empty);
      mkConnection (m.o_aw, s.i_aw);
      mkConnection (m.o_w,  s.i_w);
      mkConnection (m.i_b,  s.o_b);
      mkConnection (m.o_ar, s.i_ar);
      mkConnection (m.i_r,  s.o_r);
   endmodule
endinstance

// ================================================================
// The SyncBuffer module
// Implements an AXIx (AXI4 or AXI4 Lite) clock-crossing

module mkAXIx_SyncBuffer #(Integer depth,
			  Clock sClkIn, Reset sRstIn,
			  Clock dClkIn, Reset dRstIn)
                        (AXIx_SyncBuffer_IFC #(aw, w, b, ar, r))
   provisos (Bits #(aw, _size_aw_t),
	     Bits #(w,  _size_w_t),
	     Bits #(b,  _size_b_t),
	     Bits #(ar, _size_ar_t),
	     Bits #(r,  _size_r_t));

   SyncFIFOIfc #(aw) f_aw <- mkSyncFIFO (depth, sClkIn, sRstIn, dClkIn); // enq|=>|deq
   SyncFIFOIfc #(w)  f_w  <- mkSyncFIFO (depth, sClkIn, sRstIn, dClkIn); // enq|=>|deq
   SyncFIFOIfc #(b)  f_b  <- mkSyncFIFO (depth, dClkIn, dRstIn, sClkIn); // deq|<=|enq

   SyncFIFOIfc #(ar) f_ar <- mkSyncFIFO (depth, sClkIn, sRstIn, dClkIn); // enq|=>|deq
   SyncFIFOIfc #(r)  f_r  <- mkSyncFIFO (depth, dClkIn, dRstIn, sClkIn); // deq|<=|enq

   // ----------------------------------------------------------------
   // Help functions

   function FIFOF_I #(t) syncFIFO_to_FIFOF_I (SyncFIFOIfc #(t) sf);
      return interface FIFOF_I;
		method Action enq (t x) = sf.enq (x);
		method Bool notFull     = sf.notFull;
	     endinterface;
   endfunction

   function FIFOF_O #(t) syncFIFO_to_FIFOF_O (SyncFIFOIfc #(t) sf);
      return interface FIFOF_O;
		method t      first    = sf.first;
		method Action deq      = sf.deq;
		method Bool   notEmpty = sf.notEmpty;
	     endinterface;
   endfunction

   // ----------------------------------------------------------------
   // INTERFACE

   interface from_M = interface AXIx_S_IFC;
			 interface FIFOF_I i_aw = syncFIFO_to_FIFOF_I (f_aw);
			 interface FIFOF_I i_w  = syncFIFO_to_FIFOF_I (f_w);
			 interface FIFOF_O o_b  = syncFIFO_to_FIFOF_O (f_b);
			 interface FIFOF_I i_ar = syncFIFO_to_FIFOF_I (f_ar);
			 interface FIFOF_O o_r  = syncFIFO_to_FIFOF_O (f_r);
		      endinterface;

   interface to_S   = interface AXIx_M_IFC;
			 interface FIFOF_O o_aw = syncFIFO_to_FIFOF_O (f_aw);
			 interface FIFOF_O o_w  = syncFIFO_to_FIFOF_O (f_w);
			 interface FIFOF_I i_b  = syncFIFO_to_FIFOF_I (f_b);
			 interface FIFOF_O o_ar = syncFIFO_to_FIFOF_O (f_ar);
			 interface FIFOF_I i_r  = syncFIFO_to_FIFOF_I (f_r);
		      endinterface;
endmodule

// ================================================================

endpackage
