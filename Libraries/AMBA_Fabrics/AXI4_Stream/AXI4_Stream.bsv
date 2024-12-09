// Copyright (c) 2019 Bluespec, Inc.  All Rights Reserved
//
// SPDX-License-Identifier: BSD-3-Clause

package AXI4_Stream;

// ================================================================
// BSV library imports

import FIFOF       :: *;
import Connectable :: *;

// ----------------
// Bluespec misc. libs

import Semi_FIFOF :: *;
import EdgeFIFOFs :: *;
import AXI4_Types :: *;

// ================================================================
// These are the signal-level interfaces for an AXI4 stream M.
// The (*..*) attributes ensure that when bsc compiles this to Verilog,
// we get exactly the signals specified in the ARM spec.

interface AXI4_Stream_M_IFC #(numeric type wd_id,
			      numeric type wd_dest,
			      numeric type wd_data,
			      numeric type wd_user);

   (* always_ready, result="tvalid" *)  method Bool                      m_tvalid;    // out
   (* always_ready, result="tid" *)     method Bit #(wd_id)              m_tid;       // out
   (* always_ready, result="tdata" *)   method Bit #(wd_data)            m_tdata;     // out
   (* always_ready, result="tstrb" *)   method Bit #(TDiv #(wd_data, 8)) m_tstrb;     // out
   (* always_ready, result="tkeep" *)   method Bit #(TDiv #(wd_data, 8)) m_tkeep;     // out
   (* always_ready, result="tlast" *)   method Bool                      m_tlast;     // out
   (* always_ready, result="tdest" *)   method Bit #(wd_dest)            m_tdest;     // out
   (* always_ready, result="tuser" *)   method Bit #(wd_user)            m_tuser;     // out

   (* always_ready, always_enabled, prefix = "" *)
   method Action m_tready ((* port="tready" *)  Bool tready);                         // in

endinterface: AXI4_Stream_M_IFC

// ================================================================
// These are the signal-level interfaces for an AXI4 stream S
// The (*..*) attributes ensure that when bsc compiles this to Verilog,
// we get exactly the signals specified in the ARM spec.

interface AXI4_Stream_S_IFC #(numeric type wd_id,
			      numeric type wd_dest,
			      numeric type wd_data,
			      numeric type wd_user);
   (* always_ready, always_enabled, prefix = "" *)
   method Action m_tvalid ((* port="tvalid" *) Bool                      tvalid,    // in
			   (* port="tid" *)    Bit #(wd_id)              tid,       // in
			   (* port="tdata" *)  Bit #(wd_data)            tdata,     // in
			   (* port="tstrb" *)  Bit #(TDiv #(wd_data,8))  tstrb,     // in
			   (* port="tkeep" *)  Bit #(TDiv #(wd_data,8))  tkeep,     // in
			   (* port="tlast" *)  Bool                      tlast,     // in
			   (* port="tdest" *)  Bit #(wd_dest)            tdest,     // in
			   (* port="tuser" *)  Bit #(wd_user)            tuser);    // in
   (* always_ready, result="tready" *)
   method Bool m_tready;                                                           // out
endinterface: AXI4_Stream_S_IFC

// ================================================================
// Connecting signal-level interfaces

instance Connectable #(AXI4_Stream_M_IFC #(wd_id, wd_dest, wd_data, wd_user),
		       AXI4_Stream_S_IFC  #(wd_id, wd_dest, wd_data, wd_user));

   module mkConnection #(AXI4_Stream_M_IFC #(wd_id, wd_dest, wd_data, wd_user) axim,
			 AXI4_Stream_S_IFC  #(wd_id, wd_dest, wd_data, wd_user) axis)
		       (Empty);

      (* fire_when_enabled, no_implicit_conditions *)
      rule rl_data_channel;
	 axis.m_tvalid (axim.m_tvalid,
			axim.m_tid,
			axim.m_tdata,
			axim.m_tstrb,
			axim.m_tkeep,
			axim.m_tlast,
			axim.m_tdest,
			axim.m_tuser);
	 axim.m_tready (axis.m_tready);
      endrule
   endmodule
endinstance

instance Connectable #(AXI4_Stream_S_IFC  #(wd_id, wd_dest, wd_data, wd_user),
		       AXI4_Stream_M_IFC #(wd_id, wd_dest, wd_data, wd_user));
   module mkConnection #(AXI4_Stream_S_IFC  #(wd_id, wd_dest, wd_data, wd_user) axis,
			 AXI4_Stream_M_IFC #(wd_id, wd_dest, wd_data, wd_user) axim)
			 		       (Empty);
      mkConnection(axim, axis);
   endmodule
endinstance

// ================================================================
// AXI4 dummy M: never produces requests

AXI4_Stream_M_IFC #(wd_id, wd_dest, wd_data, wd_user) axi4_stream_dummy_M
  = interface AXI4_Stream_M_IFC
       method m_tvalid = False;     // out
       method m_tid    = ?;         // out
       method m_tdata  = ?;         // out
       method m_tstrb  = ?;         // out
       method m_tkeep  = ?;         // out
       method m_tlast  = ?;         // out
       method m_tdest  = ?;         // out
       method m_tuser  = ?;         // out

       method Action m_tready (wready) = noAction;        // in
    endinterface;

// ================================================================
// AXI4 dummy S: always accepts requests

AXI4_Stream_S_IFC #(wd_id, wd_dest, wd_data, wd_user) axi4_stream_dummy_S
   = interface AXI4_Stream_S_IFC
	method Action m_tvalid (wvalid,
				wid,
				wdata,
				wstrb,
				wkeep,
				wlast,
				wdest,
				wuser);
	   noAction;
	endmethod
	method Bool m_tready = True;
     endinterface;

// ****************************************************************
// ****************************************************************
// Section: Higher-level FIFO-like interfaces and transactors
// ****************************************************************
// ****************************************************************

// ================================================================
// Help function: fn_crg_and_rg_to_FIFOF_I
// In the modules below, we use a crg_full and a rg_data to represent a fifo.
// These functions convert these to FIFOF_I and FIFOF_O interfaces.

function FIFOF_I #(t) fn_crg_and_rg_to_FIFOF_I (Reg #(Bool) rg_full, Reg #(t) rg_data);
   return interface FIFOF_I;
	     method Action enq (t x) if (! rg_full);
		rg_full <= True;
		rg_data <= x;
	     endmethod
	     method Bool notFull;
		return (! rg_full);
	     endmethod
	  endinterface;
endfunction

function FIFOF_O #(t) fn_crg_and_rg_to_FIFOF_O (Reg #(Bool) rg_full, Reg #(t) rg_data);
   return interface FIFOF_O;
	     method t first () if (rg_full);
		return rg_data;
	     endmethod
	     method Action deq () if (rg_full);
		rg_full <= False;
	     endmethod
	     method notEmpty;
		return rg_full;
	     endmethod
	  endinterface;
endfunction

// ================================================================
// Higher-level types for payloads (rather than just bits)

typedef struct {
   Bit #(wd_id)               tid;
   Bit #(wd_data)             tdata;
   Bit #(TDiv #(wd_data, 8))  tstrb;
   Bit #(TDiv #(wd_data, 8))  tkeep;
   Bool                       tlast;
   Bit #(wd_dest)             tdest;
   Bit #(wd_user)             tuser;
   } AXI4_Stream #(numeric type wd_id,
		   numeric type wd_dest,
		   numeric type wd_data,
		   numeric type wd_user)
deriving (Bits, FShow);

// ================================================================
// M transactor interface

interface AXI4_Stream_M_Xactor_IFC #(numeric type wd_id,
				     numeric type wd_dest,
				     numeric type wd_data,
				     numeric type wd_user);
   method Action reset;
   // AXI side
   interface AXI4_Stream_M_IFC #(wd_id, wd_dest, wd_data, wd_user)  axi_side;
   // FIFOF side
   interface FIFOF_I #(AXI4_Stream #(wd_id, wd_dest, wd_data, wd_user))  i_stream;
endinterface: AXI4_Stream_M_Xactor_IFC

// ----------------------------------------------------------------
// M transactor
// This version uses FIFOFs for total decoupling.

module mkAXI4_Stream_M_Xactor (AXI4_Stream_M_Xactor_IFC #(wd_id, wd_dest, wd_data, wd_user));

   Bool unguarded = True;
   Bool guarded   = False;

   // Guarded on BSV side, unguarded on AXI side
   FIFOF #(AXI4_Stream #(wd_id, wd_dest, wd_data, wd_user))
   f_data <- mkGFIFOF (guarded, unguarded);


   // ----------------------------------------------------------------
   // INTERFACE

   method Action reset;
      f_data.clear;
   endmethod

   // AXI side
   interface axi_side = interface AXI4_Stream_M_IFC;
			   method m_tvalid = f_data.notEmpty;
			   method m_tid    = f_data.first.tid;
			   method m_tdata  = f_data.first.tdata;
			   method m_tstrb  = f_data.first.tstrb;
			   method m_tkeep  = f_data.first.tkeep;
			   method m_tlast  = f_data.first.tlast;
			   method m_tdest  = f_data.first.tdest;
			   method m_tuser  = f_data.first.tuser;
			   method Action m_tready (Bool tready);
			      if (f_data.notEmpty && tready) f_data.deq;
			   endmethod
			endinterface;

   // FIFOF side
   interface i_stream = to_FIFOF_I (f_data);
endmodule: mkAXI4_Stream_M_Xactor

// ================================================================
// S transactor interface

interface AXI4_Stream_S_Xactor_IFC #(numeric type wd_id,
				     numeric type wd_dest,
				     numeric type wd_data,
				     numeric type wd_user);
   method Action reset;
   // AXI side
   interface AXI4_Stream_S_IFC #(wd_id, wd_dest, wd_data, wd_user)  axi_side;
   // FIFOF side
   interface FIFOF_O #(AXI4_Stream #(wd_id, wd_dest, wd_data, wd_user)) o_stream;
endinterface: AXI4_Stream_S_Xactor_IFC

// ----------------------------------------------------------------
// S transactor
// This version uses FIFOFs for total decoupling.

module mkAXI4_Stream_S_Xactor (AXI4_Stream_S_Xactor_IFC #(wd_id, wd_dest, wd_data, wd_user));

   Bool unguarded = True;
   Bool guarded   = False;

   // Guarded on BSV side, unguarded on AXI side
   FIFOF #(AXI4_Stream #(wd_id, wd_dest, wd_data, wd_user))
   f_data <- mkGFIFOF (unguarded, guarded);

   // ----------------------------------------------------------------
   // INTERFACE

   method Action reset;
      f_data.clear;
   endmethod

   // AXI side
   interface axi_side = interface AXI4_Stream_S_IFC;
			   method Action m_tvalid (Bool                       tvalid,
						   Bit #(wd_id)               tid,
						   Bit #(wd_data)             tdata,
						   Bit #(TDiv #(wd_data, 8))  tstrb,
						   Bit #(TDiv #(wd_data, 8))  tkeep,
						   Bool                       tlast,
						   Bit #(wd_dest)             tdest,
						   Bit #(wd_user)             tuser);
			      if (tvalid && f_data.notFull)
				 f_data.enq (AXI4_Stream {tid:   tid,
							  tdata: tdata,
							  tstrb: tstrb,
							  tkeep: tkeep,
							  tlast: tlast,
							  tdest: tdest,
							  tuser: tuser});
			   endmethod

			   method Bool m_tready;
			      return f_data.notFull;
			   endmethod
			endinterface;

   // FIFOF side
   interface o_stream  = to_FIFOF_O (f_data);
endmodule: mkAXI4_Stream_S_Xactor

// ================================================================

endpackage
