// Copyright (c) 2019-2025 Bluespec, Inc.  All Rights Reserved
// Copyright (c) 2024 Rishiyur S. Nikhil.

// SPDX-License-Identifier: BSD-3-Clause

package AXI4_BSV_RTL;

// ****************************************************************
// ****************************************************************

// This package provides facilities for AXI4 connections between BSV
// and RTL:

//   BSV: AW,W,B,AR,R are bit-vectors but always viewed as structs,
//            whose fields correspond to AXI4 sub-buses.
//            Some of those fields are always viewed as enums
//        Communication is via FIFOs.

//   RTL: AW,W,B,AR,R  are buses, with named sub-buses.
//        Communication is via handshake on two more wires per bus:
//            ready,valid

// Transactors ("xactors") are buffers to cross the BSV-RTL boundary
// The BSV side uses standard BSV FIFO interfaces.
// The RTL side uses standard AMBA signaling, allowing it to connect
//     to any AXI IP written in RTL or in BSV.
//
// Two kinds of transactors
// (in both cases "x_to_y" means to connect an M to an S
//
//              +----------------------------+
//              |       AXI4_BSV_to_RTL      |
//     BSV      |AXI4_S_IFC    AXI4_RTL_M_IFC|    RTL
//      M <---> |ifc_S                  rtl_M|<--> S
//              +----------------------------+
//
//              +----------------------------+
//              |       AXI4_RTL_to_BSV      |
//     RTL      |AXI4_RTL_S_IFC    AXI4_M_IFC|    BSV
//      M <---> |rtl_S                  ifc_M|<--> S
//              +----------------------------+
//
// ****************************************************************
// ****************************************************************
// BSV library imports

import FIFOF       :: *;
import Connectable :: *;

// ----------------
// Bluespec misc. libs

import Semi_FIFOF :: *;
import EdgeFIFOFs :: *;

// ----------------
// Project imports

import AXI4_Types :: *;

// ****************************************************************
// ****************************************************************
// Section: Interfaces with standard AMBA RTL-level signaling
// (ready/valid handshakes, standard AMBA signal names)

// ================================================================
// These are the signal-level interfaces for an AXI4 M.
// The (*..*) attributes ensure that when bsc compiles this to Verilog,
// we get exactly the signals specified in the ARM spec.

interface AXI4_RTL_M_IFC #(numeric type wd_id,
			   numeric type wd_addr,
			   numeric type wd_data,
			   numeric type wd_user);
   // ----------------
   // Wr Addr channel
   (* always_ready, result="awvalid" *)   method Bool           m_awvalid;     // out

   (* always_ready, result="awid" *)      method Bit #(wd_id)   m_awid;        // out
   (* always_ready, result="awaddr" *)    method Bit #(wd_addr) m_awaddr;      // out
   (* always_ready, result="awlen" *)     method Bit #(8)       m_awlen;       // out
   (* always_ready, result="awsize" *)    method AXI4_Size      m_awsize;      // out
   (* always_ready, result="awburst" *)   method Bit #(2)       m_awburst;     // out
   (* always_ready, result="awlock" *)    method Bit #(1)       m_awlock;      // out
   (* always_ready, result="awcache" *)   method Bit #(4)       m_awcache;     // out
   (* always_ready, result="awprot" *)    method Bit #(3)       m_awprot;      // out
   (* always_ready, result="awqos" *)     method Bit #(4)       m_awqos;       // out
   (* always_ready, result="awregion" *)  method Bit #(4)       m_awregion;    // out
   (* always_ready, result="awuser" *)    method Bit #(wd_user) m_awuser;      // out

   (* always_ready, always_enabled, prefix="" *)
   method Action m_awready ((* port="awready" *) Bool awready);                // in

   // ----------------
   // Wr Data channel
   (* always_ready, result="wvalid" *)  method Bool                      m_wvalid;    // out

   (* always_ready, result="wdata" *)   method Bit #(wd_data)            m_wdata;     // out
   (* always_ready, result="wstrb" *)   method Bit #(TDiv #(wd_data, 8)) m_wstrb;     // out
   (* always_ready, result="wlast" *)   method Bool                      m_wlast;     // out
   (* always_ready, result="wuser" *)   method Bit #(wd_user)            m_wuser;     // out

   (* always_ready, always_enabled, prefix = "" *)
   method Action m_wready ((* port="wready" *)  Bool wready);                         // in

   // ----------------
   // Wr Response channel
   (* always_ready, always_enabled, prefix = "" *)
   method Action m_bvalid ((* port="bvalid" *)  Bool           bvalid,    // in
			   (* port="bid"    *)  Bit #(wd_id)   bid,       // in
			   (* port="bresp"  *)  Bit #(2)       bresp,     // in
			   (* port="buser"  *)  Bit #(wd_user) buser);    // in

   (* always_ready, prefix = "", result="bready" *)
   method Bool m_bready;                                                  // out

   // ----------------
   // Rd Addr channel
   (* always_ready, result="arvalid" *)   method Bool            m_arvalid;     // out

   (* always_ready, result="arid" *)      method Bit #(wd_id)    m_arid;        // out
   (* always_ready, result="araddr" *)    method Bit #(wd_addr)  m_araddr;      // out
   (* always_ready, result="arlen" *)     method Bit #(8)        m_arlen;       // out
   (* always_ready, result="arsize" *)    method AXI4_Size       m_arsize;      // out
   (* always_ready, result="arburst" *)   method Bit #(2)        m_arburst;     // out
   (* always_ready, result="arlock" *)    method Bit #(1)        m_arlock;      // out
   (* always_ready, result="arcache" *)   method Bit #(4)        m_arcache;     // out
   (* always_ready, result="arprot" *)    method Bit #(3)        m_arprot;      // out
   (* always_ready, result="arqos" *)     method Bit #(4)        m_arqos;       // out
   (* always_ready, result="arregion" *)  method Bit #(4)        m_arregion;    // out
   (* always_ready, result="aruser" *)    method Bit #(wd_user)  m_aruser;      // out

   (* always_ready, always_enabled, prefix="" *)
   method Action m_arready ((* port="arready" *) Bool arready);    // in

   // ----------------
   // Rd Data channel
   (* always_ready, always_enabled, prefix = "" *)
   method Action m_rvalid ((* port="rvalid" *)  Bool           rvalid,    // in
			   (* port="rid"    *)  Bit #(wd_id)   rid,       // in
			   (* port="rdata"  *)  Bit #(wd_data) rdata,     // in
			   (* port="rresp"  *)  Bit #(2)       rresp,     // in
			   (* port="rlast"  *)  Bool           rlast,     // in
			   (* port="ruser"  *)  Bit #(wd_user) ruser);    // in

   (* always_ready, result="rready" *)
   method Bool m_rready;                                                  // out
endinterface: AXI4_RTL_M_IFC

// ================================================================
// These are the signal-level interfaces for an AXI4-Lite S.
// The (*..*) attributes ensure that when bsc compiles this to Verilog,
// we get exactly the signals specified in the ARM spec.

interface AXI4_RTL_S_IFC #(numeric type wd_id,
			   numeric type wd_addr,
			   numeric type wd_data,
			   numeric type wd_user);
   // Wr Addr channel
   (* always_ready, always_enabled, prefix = "" *)
   method Action m_awvalid ((* port="awvalid" *)   Bool            awvalid,     // in
			    (* port="awid" *)      Bit #(wd_id)    awid,        // in
			    (* port="awaddr" *)    Bit #(wd_addr)  awaddr,      // in
			    (* port="awlen" *)     Bit #(8)        awlen,       // in
			    (* port="awsize" *)    AXI4_Size       awsize,      // in
			    (* port="awburst" *)   Bit #(2)        awburst,     // in
			    (* port="awlock" *)    Bit #(1)        awlock,      // in
			    (* port="awcache" *)   Bit #(4)        awcache,     // in
			    (* port="awprot" *)    Bit #(3)        awprot,      // in
			    (* port="awqos" *)     Bit #(4)        awqos,       // in
			    (* port="awregion" *)  Bit #(4)        awregion,    // in
			    (* port="awuser" *)    Bit #(wd_user)  awuser);     // in
   (* always_ready, result="awready" *)
   method Bool m_awready;                                                       // out

   // Wr Data channel
   (* always_ready, always_enabled, prefix = "" *)
   method Action m_wvalid ((* port="wvalid" *) Bool                      wvalid,    // in
			   (* port="wdata" *)  Bit #(wd_data)            wdata,     // in
			   (* port="wstrb" *)  Bit #(TDiv #(wd_data,8))  wstrb,     // in
			   (* port="wlast" *)  Bool                      wlast,     // in
			   (* port="wuser" *)  Bit #(wd_user)            wuser);    // in
   (* always_ready, result="wready" *)
   method Bool m_wready;                                                           // out

   // Wr Response channel
   (* always_ready, result="bvalid" *)  method Bool            m_bvalid;    // out
   (* always_ready, result="bid" *)     method Bit #(wd_id)    m_bid;       // out
   (* always_ready, result="bresp" *)   method Bit #(2)        m_bresp;     // out
   (* always_ready, result="buser" *)   method Bit #(wd_user)  m_buser;     // out
   (* always_ready, always_enabled, prefix="" *)
   method Action m_bready  ((* port="bready" *)   Bool bready);            // in

   // Rd Addr channel
   (* always_ready, always_enabled, prefix = "" *)
   method Action m_arvalid ((* port="arvalid" *)   Bool            arvalid,     // in
			    (* port="arid" *)      Bit #(wd_id)    arid,        // in
			    (* port="araddr" *)    Bit #(wd_addr)  araddr,      // in
			    (* port="arlen" *)     Bit #(8)        arlen,       // in
			    (* port="arsize" *)    AXI4_Size       arsize,      // in
			    (* port="arburst" *)   Bit #(2)        arburst,     // in
			    (* port="arlock" *)    Bit #(1)        arlock,      // in
			    (* port="arcache" *)   Bit #(4)        arcache,     // in
			    (* port="arprot" *)    Bit #(3)        arprot,      // in
			    (* port="arqos" *)     Bit #(4)        arqos,       // in
			    (* port="arregion" *)  Bit #(4)        arregion,    // in
			    (* port="aruser" *)    Bit #(wd_user)  aruser);     // in
   (* always_ready, result="arready" *)
   method Bool m_arready;                                                       // out

   // Rd Data channel
   (* always_ready, result="rvalid" *)  method Bool            m_rvalid;    // out
   (* always_ready, result="rid" *)     method Bit #(wd_id)    m_rid;       // out
   (* always_ready, result="rdata" *)   method Bit #(wd_data)  m_rdata;     // out
   (* always_ready, result="rresp" *)   method Bit #(2)        m_rresp;     // out
   (* always_ready, result="rlast" *)   method Bool            m_rlast;     // out
   (* always_ready, result="ruser" *)   method Bit #(wd_user)  m_ruser;     // out
   (* always_ready, always_enabled, prefix="" *)
   method Action m_rready  ((* port="rready" *)   Bool rready);             // in
endinterface: AXI4_RTL_S_IFC

// ================================================================
// Connecting RTL-level interfaces

instance Connectable #(AXI4_RTL_M_IFC #(wd_id, wd_addr, wd_data, wd_user),
		       AXI4_RTL_S_IFC #(wd_id, wd_addr, wd_data, wd_user));

   module mkConnection #(AXI4_RTL_M_IFC #(wd_id, wd_addr, wd_data, wd_user) axim,
			 AXI4_RTL_S_IFC #(wd_id, wd_addr, wd_data, wd_user) axis)
		       (Empty);

      (* fire_when_enabled, no_implicit_conditions *)
      rule rl_AW_valid;
	 axis.m_awvalid (axim.m_awvalid,
			 axim.m_awid,
			 axim.m_awaddr,
			 axim.m_awlen,
			 axim.m_awsize,
			 axim.m_awburst,
			 axim.m_awlock,
			 axim.m_awcache,
			 axim.m_awprot,
			 axim.m_awqos,
			 axim.m_awregion,
			 axim.m_awuser);
      endrule

      (* fire_when_enabled, no_implicit_conditions *)
      rule rl_AW_ready;
	 axim.m_awready (axis.m_awready);
      endrule

      (* fire_when_enabled, no_implicit_conditions *)
      rule rl_W_valid;
	 axis.m_wvalid (axim.m_wvalid,
			axim.m_wdata,
			axim.m_wstrb,
			axim.m_wlast,
			axim.m_wuser);
      endrule

      (* fire_when_enabled, no_implicit_conditions *)
      rule rl_W_ready;
	 axim.m_wready (axis.m_wready);
      endrule

      (* fire_when_enabled, no_implicit_conditions *)
      rule rl_B_valid;
	 axim.m_bvalid (axis.m_bvalid,
			axis.m_bid,
			axis.m_bresp,
			axis.m_buser);
      endrule

      (* fire_when_enabled, no_implicit_conditions *)
      rule rl_B_ready;
	 axis.m_bready (axim.m_bready);
      endrule

      (* fire_when_enabled, no_implicit_conditions *)
      rule rl_AR_valid;
	 axis.m_arvalid (axim.m_arvalid,
			 axim.m_arid,
			 axim.m_araddr,
			 axim.m_arlen,
			 axim.m_arsize,
			 axim.m_arburst,
			 axim.m_arlock,
			 axim.m_arcache,
			 axim.m_arprot,
			 axim.m_arqos,
			 axim.m_arregion,
			 axim.m_aruser);
      endrule

      (* fire_when_enabled, no_implicit_conditions *)
      rule rl_AR_ready;
	 axim.m_arready (axis.m_arready);
      endrule

      (* fire_when_enabled, no_implicit_conditions *)
      rule rl_R_valid;
	 axim.m_rvalid (axis.m_rvalid,
			axis.m_rid,
			axis.m_rdata,
			axis.m_rresp,
			axis.m_rlast,
			axis.m_ruser);
      endrule

      (* fire_when_enabled, no_implicit_conditions *)
      rule rl_R_ready;
	 axis.m_rready (axim.m_rready);
      endrule
   endmodule
endinstance

// ================================================================
// AXI4 dummy M: never produces requests, never accepts responses

AXI4_RTL_M_IFC #(wd_id, wd_addr, wd_data, wd_user)
dummy_AXI4_RTL_M_ifc
= interface AXI4_RTL_M_IFC
     // Wr Addr channel
     method Bool            m_awvalid  = False;              // out
     method Bit #(wd_id)    m_awid     = ?;                  // out
     method Bit #(wd_addr)  m_awaddr   = ?;                  // out
     method Bit #(8)        m_awlen    = ?;                  // out
     method AXI4_Size       m_awsize   = ?;                  // out
     method Bit #(2)        m_awburst  = ?;                  // out
     method Bit #(1)        m_awlock   = ?;                  // out
     method Bit #(4)        m_awcache  = ?;                  // out
     method Bit #(3)        m_awprot   = ?;                  // out
     method Bit #(4)        m_awqos    = ?;                  // out
     method Bit #(4)        m_awregion = ?;                  // out
     method Bit #(wd_user)  m_awuser   = ?;                  // out
     method Action m_awready (Bool awready) = noAction;      // in

     // Wr Data channel
     method Bool                       m_wvalid = False;     // out
     method Bit #(wd_data)             m_wdata  = ?;         // out
     method Bit #(TDiv #(wd_data, 8))  m_wstrb  = ?;         // out
     method Bool                       m_wlast  = ?;         // out
     method Bit #(wd_user)             m_wuser  = ?;         // out

     method Action m_wready (Bool wready) = noAction;        // in

     // Wr Response channel
     method Action m_bvalid (Bool            bvalid,    // in
			     Bit #(wd_id)    bid,       // in
			     Bit #(2)        bresp,     // in
			     Bit #(wd_user)  buser);    // in
	noAction;
     endmethod
     method Bool m_bready = False;                     // out

     // Rd Addr channel
     method Bool            m_arvalid  = False;             // out
     method Bit #(wd_id)    m_arid     = ?;                 // out
     method Bit #(wd_addr)  m_araddr   = ?;                 // out
     method Bit #(8)        m_arlen    = ?;                 // out
     method AXI4_Size       m_arsize   = ?;                 // out
     method Bit #(2)        m_arburst  = ?;                 // out
     method Bit #(1)        m_arlock   = ?;                 // out
     method Bit #(4)        m_arcache  = ?;                 // out
     method Bit #(3)        m_arprot   = ?;                 // out
     method Bit #(4)        m_arqos    = ?;                 // out
     method Bit #(4)        m_arregion = ?;                 // out
     method Bit #(wd_user)  m_aruser   = ?;                 // out
     method Action m_arready (Bool arready) = noAction;     // in

     // Rd Data channel
     method Action m_rvalid (Bool            rvalid,    // in
			     Bit #(wd_id)    rid,       // in
			     Bit #(wd_data)  rdata,     // in
			     Bit #(2)        rresp,     // in
			     Bool            rlast,     // in
			     Bit #(wd_user)  ruser);    // in
	noAction;
     endmethod
     method Bool m_rready = False;                     // out
  endinterface;

// ================================================================
// AXI4 dummy S: never accepts requests, never produces responses

AXI4_RTL_S_IFC #(wd_id, wd_addr, wd_data, wd_user)
dummy_AXI4_RTL_S_ifc
= interface AXI4_RTL_S_IFC
     // Wr Addr channel
     method Action m_awvalid (Bool            awvalid,
			      Bit #(wd_id)    awid,
			      Bit #(wd_addr)  awaddr,
			      Bit #(8)        awlen,
			      AXI4_Size       awsize,
			      Bit #(2)        awburst,
			      Bit #(1)        awlock,
			      Bit #(4)        awcache,
			      Bit #(3)        awprot,
			      Bit #(4)        awqos,
			      Bit #(4)        awregion,
			      Bit #(wd_user)  awuser);
	noAction;
     endmethod

     method Bool m_awready;
	return False;
     endmethod

     // Wr Data channel
     method Action m_wvalid (Bool                       wvalid,
			     Bit #(wd_data)             wdata,
			     Bit #(TDiv #(wd_data, 8))  wstrb,
			     Bool                       wlast,
			     Bit #(wd_user)             wuser);
	noAction;
     endmethod

     method Bool m_wready;
	return False;
     endmethod

     // Wr Response channel
     method Bool m_bvalid;
	return False;
     endmethod

     method Bit #(wd_id) m_bid;
	return ?;
     endmethod

     method Bit #(2) m_bresp;
	return 0;
     endmethod

     method Bit #(wd_user) m_buser;
	return ?;
     endmethod

     method Action m_bready  (Bool bready);
	noAction;
     endmethod

     // Rd Addr channel
     method Action m_arvalid (Bool            arvalid,
			      Bit #(wd_id)    arid,
			      Bit #(wd_addr)  araddr,
			      Bit #(8)        arlen,
			      AXI4_Size       arsize,
			      Bit #(2)        arburst,
			      Bit #(1)        arlock,
			      Bit #(4)        arcache,
			      Bit #(3)        arprot,
			      Bit #(4)        arqos,
			      Bit #(4)        arregion,
			      Bit #(wd_user)  aruser);
	noAction;
     endmethod

     method Bool m_arready;
	return False;
     endmethod

     // Rd Data channel
     method Bool m_rvalid;
	return False;
     endmethod

     method Bit #(wd_id) m_rid;
	return 0;
     endmethod

     method Bit #(wd_data) m_rdata;
	return 0;
     endmethod

     method Bit #(2) m_rresp;
	return 0;
     endmethod

     method Bool  m_rlast;
	return True;
     endmethod

     method Bit #(wd_user) m_ruser;
	return ?;
     endmethod

     method Action m_rready  (Bool rready);
	noAction;
     endmethod
  endinterface;

// ****************************************************************

interface AXI4_BSV_to_RTL_IFC #(numeric type wd_id,
			      numeric type wd_addr,
			      numeric type wd_data,
			      numeric type wd_user);
   interface AXI4_S_IFC     #(wd_id, wd_addr, wd_data, wd_user)  ifc_S;
   interface AXI4_RTL_M_IFC #(wd_id, wd_addr, wd_data, wd_user)  rtl_M;
endinterface: AXI4_BSV_to_RTL_IFC

interface AXI4_RTL_to_BSV_IFC #(numeric type wd_id,
				  numeric type wd_addr,
				  numeric type wd_data,
				  numeric type wd_user);
   interface AXI4_RTL_S_IFC #(wd_id, wd_addr, wd_data, wd_user)  rtl_S;
   interface AXI4_M_IFC     #(wd_id, wd_addr, wd_data, wd_user)  ifc_M;
endinterface: AXI4_RTL_to_BSV_IFC

// ================================================================
// M transactor
// This version uses FIFOFs for total decoupling.

module mkAXI4_BSV_to_RTL (AXI4_BSV_to_RTL_IFC #(wd_id, wd_addr, wd_data, wd_user));

   Bool unguarded = True;
   Bool guarded   = False;

   // These FIFOs are guarded on BSV side, unguarded on AXI side
   FIFOF #(AXI4_AW #(wd_id, wd_addr, wd_user))  f_AW <- mkGFIFOF (guarded, unguarded);
   FIFOF #(AXI4_W  #(wd_data, wd_user))         f_W  <- mkGFIFOF (guarded, unguarded);
   FIFOF #(AXI4_B  #(wd_id, wd_user))           f_B  <- mkGFIFOF (unguarded, guarded);

   FIFOF #(AXI4_AR #(wd_id, wd_addr, wd_user))  f_AR <- mkGFIFOF (guarded, unguarded);
   FIFOF #(AXI4_R  #(wd_id, wd_data, wd_user))  f_R  <- mkGFIFOF (unguarded, guarded);

   // ----------------------------------------------------------------
   // INTERFACE

   // RTL side
   interface AXI4_RTL_M_IFC rtl_M;
      // Wr Addr channel
      method Bool            m_awvalid  = f_AW.notEmpty;
      method Bit #(wd_id)    m_awid     = f_AW.first.awid;
      method Bit #(wd_addr)  m_awaddr   = f_AW.first.awaddr;
      method Bit #(8)        m_awlen    = f_AW.first.awlen;
      method AXI4_Size       m_awsize   = f_AW.first.awsize;
      method Bit #(2)        m_awburst  = f_AW.first.awburst;
      method Bit #(1)        m_awlock   = f_AW.first.awlock;
      method Bit #(4)        m_awcache  = f_AW.first.awcache;
      method Bit #(3)        m_awprot   = f_AW.first.awprot;
      method Bit #(4)        m_awqos    = f_AW.first.awqos;
      method Bit #(4)        m_awregion = f_AW.first.awregion;
      method Bit #(wd_user)  m_awuser   = f_AW.first.awuser;
      method Action m_awready (Bool awready);
	 if (f_AW.notEmpty && awready) f_AW.deq;
      endmethod

	 // Wr Data channel
      method Bool                       m_wvalid = f_W.notEmpty;
      method Bit #(wd_data)             m_wdata  = f_W.first.wdata;
      method Bit #(TDiv #(wd_data, 8))  m_wstrb  = f_W.first.wstrb;
      method Bool                       m_wlast  = f_W.first.wlast;
      method Bit #(wd_user)             m_wuser  = f_W.first.wuser;
      method Action m_wready (Bool wready);
	 if (f_W.notEmpty && wready) f_W.deq;
      endmethod

	 // Wr Response channel
      method Action m_bvalid (Bool           bvalid,
			      Bit #(wd_id)   bid,
			      Bit #(2)       bresp,
			      Bit #(wd_user) buser);
	 if (bvalid && f_B.notFull)
	    f_B.enq (AXI4_B {bid:   bid,
			     bresp: bresp,
			     buser: buser});
      endmethod

      method Bool m_bready;
	 return f_B.notFull;
      endmethod

	 // Rd Addr channel
      method Bool            m_arvalid  = f_AR.notEmpty;
      method Bit #(wd_id)    m_arid     = f_AR.first.arid;
      method Bit #(wd_addr)  m_araddr   = f_AR.first.araddr;
      method Bit #(8)        m_arlen    = f_AR.first.arlen;
      method AXI4_Size       m_arsize   = f_AR.first.arsize;
      method Bit #(2)        m_arburst  = f_AR.first.arburst;
      method Bit #(1)        m_arlock   = f_AR.first.arlock;
      method Bit #(4)        m_arcache  = f_AR.first.arcache;
      method Bit #(3)        m_arprot   = f_AR.first.arprot;
      method Bit #(4)        m_arqos    = f_AR.first.arqos;
      method Bit #(4)        m_arregion = f_AR.first.arregion;
      method Bit #(wd_user)  m_aruser   = f_AR.first.aruser;

      method Action m_arready (Bool arready);
	 if (f_AR.notEmpty && arready) f_AR.deq;
      endmethod

	 // Rd Data channel
      method Action m_rvalid (Bool           rvalid,    // in
			      Bit #(wd_id)   rid,       // in
			      Bit #(wd_data) rdata,     // in
			      Bit #(2)       rresp,     // in
			      Bool           rlast,     // in
			      Bit #(wd_user) ruser);    // in
	 if (rvalid && f_R.notFull)
	    f_R.enq (AXI4_R {rid:   rid,
			     rdata: rdata,
			     rresp: rresp,
			     rlast: rlast,
			     ruser: ruser});
      endmethod

      method Bool m_rready;
	 return f_R.notFull;
      endmethod

   endinterface

   // BSV side
   interface AXI4_S_IFC ifc_S;
      interface i_AW = to_FIFOF_I (f_AW);
      interface i_W  = to_FIFOF_I (f_W);
      interface o_B  = to_FIFOF_O (f_B);

      interface i_AR = to_FIFOF_I (f_AR);
      interface o_R  = to_FIFOF_O (f_R);
   endinterface
endmodule: mkAXI4_BSV_to_RTL

// ================================================================
// This version uses FIFOFs for total decoupling.

module mkAXI4_RTL_to_BSV (AXI4_RTL_to_BSV_IFC #(wd_id, wd_addr, wd_data, wd_user));

   Bool unguarded = True;
   Bool guarded   = False;

   // These FIFOs are guarded on BSV side, unguarded on AXI side
   FIFOF #(AXI4_AW #(wd_id, wd_addr, wd_user))  f_AW <- mkGFIFOF (unguarded, guarded);
   FIFOF #(AXI4_W  #(wd_data, wd_user))         f_W  <- mkGFIFOF (unguarded, guarded);
   FIFOF #(AXI4_B  #(wd_id, wd_user))           f_B  <- mkGFIFOF (guarded, unguarded);

   FIFOF #(AXI4_AR #(wd_id, wd_addr, wd_user))  f_AR <- mkGFIFOF (unguarded, guarded);
   FIFOF #(AXI4_R  #(wd_id, wd_data, wd_user))  f_R  <- mkGFIFOF (guarded, unguarded);

   // ----------------------------------------------------------------
   // INTERFACE

   // AXI side
   interface  AXI4_RTL_S_IFC rtl_S;
      // Wr Addr channel
      method Action m_awvalid (Bool            awvalid,
			       Bit #(wd_id)    awid,
			       Bit #(wd_addr)  awaddr,
			       Bit #(8)        awlen,
			       AXI4_Size       awsize,
			       Bit #(2)        awburst,
			       Bit #(1)        awlock,
			       Bit #(4)        awcache,
			       Bit #(3)        awprot,
			       Bit #(4)        awqos,
			       Bit #(4)        awregion,
			       Bit #(wd_user)  awuser);
	 if (awvalid && f_AW.notFull)
	    f_AW.enq (AXI4_AW {awid:     awid,
			       awaddr:   awaddr,
			       awlen:    awlen,
			       awsize:   awsize,
			       awburst:  awburst,
			       awlock:   awlock,
			       awcache:  awcache,
			       awprot:   awprot,
			       awqos:    awqos,
			       awregion: awregion,
			       awuser:   awuser});
      endmethod

      method Bool m_awready;
	 return f_AW.notFull;
      endmethod

      // Wr Data channel
      method Action m_wvalid (Bool                       wvalid,
			      Bit #(wd_data)             wdata,
			      Bit #(TDiv #(wd_data, 8))  wstrb,
			      Bool                       wlast,
			      Bit #(wd_user)             wuser);
	 if (wvalid && f_W.notFull)
	    f_W.enq (AXI4_W {wdata: wdata,
			     wstrb: wstrb,
			     wlast: wlast,
			     wuser: wuser});
      endmethod

      method Bool m_wready;
	 return f_W.notFull;
      endmethod

      // Wr Response channel
      method Bool           m_bvalid = f_B.notEmpty;
      method Bit #(wd_id)   m_bid    = f_B.first.bid;
      method Bit #(2)       m_bresp  = f_B.first.bresp;
      method Bit #(wd_user) m_buser  = f_B.first.buser;
      method Action m_bready (Bool bready);
	 if (bready && f_B.notEmpty)
	    f_B.deq;
      endmethod

	 // Rd Addr channel
      method Action m_arvalid (Bool            arvalid,
			       Bit #(wd_id)    arid,
			       Bit #(wd_addr)  araddr,
			       Bit #(8)        arlen,
			       AXI4_Size       arsize,
			       Bit #(2)        arburst,
			       Bit #(1)        arlock,
			       Bit #(4)        arcache,
			       Bit #(3)        arprot,
			       Bit #(4)        arqos,
			       Bit #(4)        arregion,
			       Bit #(wd_user)  aruser);
	 if (arvalid && f_AR.notFull)
	    f_AR.enq (AXI4_AR {arid:     arid,
			       araddr:   araddr,
			       arlen:    arlen,
			       arsize:   arsize,
			       arburst:  arburst,
			       arlock:   arlock,
			       arcache:  arcache,
			       arprot:   arprot,
			       arqos:    arqos,
			       arregion: arregion,
			       aruser:   aruser});
      endmethod

      method Bool m_arready;
	 return f_AR.notFull;
      endmethod

	 // Rd Data channel
      method Bool           m_rvalid = f_R.notEmpty;
      method Bit #(wd_id)   m_rid    = f_R.first.rid;
      method Bit #(wd_data) m_rdata  = f_R.first.rdata;
      method Bit #(2)       m_rresp  = f_R.first.rresp;
      method Bool           m_rlast  = f_R.first.rlast;
      method Bit #(wd_user) m_ruser  = f_R.first.ruser;
      method Action m_rready (Bool rready);
	 if (rready && f_R.notEmpty)
	    f_R.deq;
      endmethod
   endinterface

   // BSV side
   interface AXI4_M_IFC ifc_M;
      interface o_AW = to_FIFOF_O (f_AW);
      interface o_W  = to_FIFOF_O (f_W);
      interface i_B  = to_FIFOF_I (f_B);

      interface o_AR = to_FIFOF_O (f_AR);
      interface i_R  = to_FIFOF_I (f_R);
   endinterface
endmodule: mkAXI4_RTL_to_BSV

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
// M transactor
// This version uses crgs and regs instead of FIFOFs.
// This uses 1/2 the resources, but introduces scheduling dependencies.

module mkAXI4_BSV_to_RTL_2 (AXI4_BSV_to_RTL_IFC #(wd_id, wd_addr, wd_data, wd_user));

   // Each crg_full, rg_data pair below represents a 1-element fifo.

   Array #(Reg #(Bool))                       crg_AW_full <- mkCReg (3, False);
   Reg #(AXI4_AW #(wd_id, wd_addr, wd_user))  rg_AW       <- mkRegU;

   Array #(Reg #(Bool))                       crg_W_full  <- mkCReg (3, False);
   Reg #(AXI4_W #(wd_data, wd_user))          rg_W        <- mkRegU;

   Array #(Reg #(Bool))                       crg_B_full  <- mkCReg (3, False);
   Reg #(AXI4_B #(wd_id, wd_user))            rg_B        <- mkRegU;

   Array #(Reg #(Bool))                       crg_AR_full <- mkCReg (3, False);
   Reg #(AXI4_AR #(wd_id, wd_addr, wd_user))  rg_AR       <- mkRegU;

   Array #(Reg #(Bool))                      crg_R_full   <- mkCReg (3, False);
   Reg #(AXI4_R #(wd_id, wd_data, wd_user))  rg_R         <- mkRegU;

   // The following CReg port indexes specify the relative scheduling of:
   //     {first,deq,notEmpty}    {enq,notFull}    clear

   // TODO: 'deq/enq/clear = 1/2/0' is unusual, but eliminates a
   // scheduling cycle in Piccolo's DCache.  Normally should be 0/1/2.

   Integer port_deq   = 1;
   Integer port_enq   = 2;
   Integer port_clear = 0;

   // ----------------------------------------------------------------
   // INTERFACE

   // RTL side
   interface AXI4_RTL_M_IFC rtl_M;
      // Wr Addr channel
      method Bool           m_awvalid  = crg_AW_full [port_deq];
      method Bit #(wd_id)   m_awid     = rg_AW.awid;
      method Bit #(wd_addr) m_awaddr   = rg_AW.awaddr;
      method Bit #(8)       m_awlen    = rg_AW.awlen;
      method AXI4_Size      m_awsize   = rg_AW.awsize;
      method Bit #(2)       m_awburst  = rg_AW.awburst;
      method Bit #(1)       m_awlock   = rg_AW.awlock;
      method Bit #(4)       m_awcache  = rg_AW.awcache;
      method Bit #(3)       m_awprot   = rg_AW.awprot;
      method Bit #(4)       m_awqos    = rg_AW.awqos;
      method Bit #(4)       m_awregion = rg_AW.awregion;
      method Bit #(wd_user) m_awuser   = rg_AW.awuser;
      method Action m_awready (Bool awready);
	 if (crg_AW_full [port_deq] && awready)
	    crg_AW_full [port_deq] <= False;    // deq
      endmethod

	 // Wr Data channel
      method Bool                       m_wvalid = crg_W_full [port_deq];
      method Bit #(wd_data)             m_wdata  = rg_W.wdata;
      method Bit #(TDiv #(wd_data, 8))  m_wstrb  = rg_W.wstrb;
      method Bool                       m_wlast  = rg_W.wlast;
      method Bit #(wd_user)             m_wuser  = rg_W.wuser;
      method Action m_wready (Bool wready);
	 if (crg_W_full [port_deq] && wready)
	    crg_W_full [port_deq] <= False;
      endmethod

	 // Wr Response channel
      method Action m_bvalid (Bool            bvalid,
			      Bit #(wd_id)    bid,
			      Bit #(2)        bresp,
			      Bit #(wd_user)  buser);
	 if (bvalid && (! (crg_B_full [port_enq]))) begin
	    crg_B_full [port_enq] <= True;
	    rg_B <= AXI4_B {bid:   bid,
			    bresp: bresp,
			    buser: buser};
	 end
      endmethod

      method Bool m_bready;
	 return (! (crg_B_full [port_enq]));
      endmethod

	 // Rd Addr channel
      method Bool            m_arvalid = crg_AR_full [port_deq];
      method Bit #(wd_id)    m_arid     = rg_AR.arid;
      method Bit #(wd_addr)  m_araddr   = rg_AR.araddr;
      method Bit #(8)        m_arlen    = rg_AR.arlen;
      method AXI4_Size       m_arsize   = rg_AR.arsize;
      method Bit #(2)        m_arburst  = rg_AR.arburst;
      method Bit #(1)        m_arlock   = rg_AR.arlock;
      method Bit #(4)        m_arcache  = rg_AR.arcache;
      method Bit #(3)        m_arprot   = rg_AR.arprot;
      method Bit #(4)        m_arqos    = rg_AR.arqos;
      method Bit #(4)        m_arregion = rg_AR.arregion;
      method Bit #(wd_user)  m_aruser   = rg_AR.aruser;
      method Action m_arready (Bool arready);
	 if (crg_AR_full [port_deq] && arready)
	    crg_AR_full [port_deq] <= False;    // deq
      endmethod

	 // Rd Data channel
      method Action m_rvalid (Bool            rvalid,
			      Bit #(wd_id)    rid,
			      Bit #(wd_data)  rdata,
			      Bit #(2)        rresp,
			      Bool            rlast,
			      Bit #(wd_user)  ruser);
	 if (rvalid && (! (crg_R_full [port_enq])))
	    crg_R_full [port_enq] <= True;
	 rg_R <= (AXI4_R {rid:   rid,
			  rdata: rdata,
			  rresp: rresp,
			  rlast: rlast,
			  ruser: ruser});
      endmethod

      method Bool m_rready;
	 return (! (crg_R_full [port_enq]));
      endmethod

   endinterface

   // BSV side
   interface AXI4_S_IFC ifc_S;
      interface i_AW = fn_crg_and_rg_to_FIFOF_I (crg_AW_full [port_enq], rg_AW);
      interface i_W  = fn_crg_and_rg_to_FIFOF_I (crg_W_full  [port_enq], rg_W);
      interface o_B  = fn_crg_and_rg_to_FIFOF_O (crg_B_full  [port_deq], rg_B);

      interface i_AR = fn_crg_and_rg_to_FIFOF_I (crg_AR_full [port_enq], rg_AR);
      interface o_R  = fn_crg_and_rg_to_FIFOF_O (crg_R_full  [port_deq], rg_R);
   endinterface
endmodule: mkAXI4_BSV_to_RTL_2

// ----------------------------------------------------------------
// S transactor
// This version uses crgs and regs instead of FIFOFs.
// This uses 1/2 the resources, but introduces scheduling dependencies.

module mkAXI4_RTL_to_BSV_2 (AXI4_RTL_to_BSV_IFC #(wd_id, wd_addr, wd_data, wd_user));

   // Each crg_full, rg_data pair below represents a 1-element fifo.

   // These FIFOs are guarded on BSV side, unguarded on AXI side
   Array #(Reg #(Bool))                       crg_AW_full <- mkCReg (3, False);
   Reg #(AXI4_AW #(wd_id, wd_addr, wd_user))  rg_AW       <- mkRegU;

   Array #(Reg #(Bool))                       crg_W_full  <- mkCReg (3, False);
   Reg #(AXI4_W #(wd_data, wd_user))          rg_W        <- mkRegU;

   Array #(Reg #(Bool))                       crg_B_full  <- mkCReg (3, False);
   Reg #(AXI4_B #(wd_id, wd_user))            rg_B        <- mkRegU;

   Array #(Reg #(Bool))                       crg_AR_full <- mkCReg (3, False);
   Reg #(AXI4_AR #(wd_id, wd_addr, wd_user))  rg_AR       <- mkRegU;

   Array #(Reg #(Bool))                      crg_R_full   <- mkCReg (3, False);
   Reg #(AXI4_R #(wd_id, wd_data, wd_user))  rg_R         <- mkRegU;

   // The following CReg port indexes specify the relative scheduling of:
   //     {first,deq,notEmpty}    {enq,notFull}    clear
   Integer port_deq   = 0;
   Integer port_enq   = 1;
   Integer port_clear = 2;

   // ----------------------------------------------------------------
   // INTERFACE

   // RTL side
   interface AXI4_RTL_S_IFC rtl_S;
      // Wr Addr channel
      method Action m_awvalid (Bool            awvalid,
			       Bit #(wd_id)    awid,
			       Bit #(wd_addr)  awaddr,
			       Bit #(8)        awlen,
			       AXI4_Size       awsize,
			       Bit #(2)        awburst,
			       Bit #(1)        awlock,
			       Bit #(4)        awcache,
			       Bit #(3)        awprot,
			       Bit #(4)        awqos,
			       Bit #(4)        awregion,
			       Bit #(wd_user)  awuser);

	 if (awvalid && (! crg_AW_full [port_enq])) begin
	    crg_AW_full [port_enq] <= True;    // enq
	    rg_AW <= AXI4_AW {awid:     awid,
			      awaddr:   awaddr,
			      awlen:    awlen,
			      awsize:   awsize,
			      awburst:  awburst,
			      awlock:   awlock,
			      awcache:  awcache,
			      awprot:   awprot,
			      awqos:    awqos,
			      awregion: awregion,
			      awuser:   awuser};
	 end
      endmethod

      method Bool m_awready;
	 return (! crg_AW_full [port_enq]);
      endmethod

      // Wr Data channel
      method Action m_wvalid (Bool                       wvalid,
			      Bit #(wd_data)             wdata,
			      Bit #(TDiv #(wd_data, 8))  wstrb,
			      Bool                       wlast,
			      Bit #(wd_user)             wuser);
	 if (wvalid && (! crg_W_full [port_enq])) begin
	    crg_W_full [port_enq] <= True;    // enq
	    rg_W <= AXI4_W {wdata: wdata,
			    wstrb: wstrb,
			    wlast: wlast,
			    wuser: wuser};
	 end
      endmethod

      method Bool m_wready;
	 return (! crg_W_full [port_enq]);
      endmethod

      // Wr Response channel
      method Bool           m_bvalid = crg_B_full [port_deq];
      method Bit #(wd_id)   m_bid    = rg_B.bid;
      method Bit #(2)       m_bresp  = rg_B.bresp;
      method Bit #(wd_user) m_buser  = rg_B.buser;
      method Action m_bready (Bool bready);
	 if (bready && crg_B_full [port_deq])
	    crg_B_full [port_deq] <= False;    // deq
      endmethod

	 // Rd Addr channel
      method Action m_arvalid (Bool            arvalid,
			       Bit #(wd_id)    arid,
			       Bit #(wd_addr)  araddr,
			       Bit #(8)        arlen,
			       AXI4_Size       arsize,
			       Bit #(2)        arburst,
			       Bit #(1)        arlock,
			       Bit #(4)        arcache,
			       Bit #(3)        arprot,
			       Bit #(4)        arqos,
			       Bit #(4)        arregion,
			       Bit #(wd_user)  aruser);
	 if (arvalid && (! crg_AR_full [port_enq])) begin
	    crg_AR_full [port_enq] <= True;    // enq
	    rg_AR <= AXI4_AR {arid:     arid,
			      araddr:   araddr,
			      arlen:    arlen,
			      arsize:   arsize,
			      arburst:  arburst,
			      arlock:   arlock,
			      arcache:  arcache,
			      arprot:   arprot,
			      arqos:    arqos,
			      arregion: arregion,
			      aruser:   aruser};
	 end
      endmethod

      method Bool m_arready;
	 return (! crg_AR_full [port_enq]);
      endmethod

	 // Rd Data channel
      method Bool           m_rvalid = crg_R_full [port_deq];
      method Bit #(wd_id)   m_rid    = rg_R.rid;
      method Bit #(wd_data) m_rdata  = rg_R.rdata;
      method Bit #(2)       m_rresp  = rg_R.rresp;
      method Bool           m_rlast  = rg_R.rlast;
      method Bit #(wd_user) m_ruser  = rg_R.ruser;
      method Action m_rready (Bool rready);
	 if (rready && crg_R_full [port_deq])
	    crg_R_full [port_deq] <= False;    // deq
      endmethod
   endinterface

   // BSV side
   interface AXI4_M_IFC ifc_M;
      interface o_AW = fn_crg_and_rg_to_FIFOF_O (crg_AW_full [port_deq], rg_AW);
      interface o_W  = fn_crg_and_rg_to_FIFOF_O (crg_W_full  [port_deq], rg_W);
      interface i_B  = fn_crg_and_rg_to_FIFOF_I (crg_B_full  [port_enq], rg_B);

      interface o_AR = fn_crg_and_rg_to_FIFOF_O (crg_AR_full [port_deq], rg_AR);
      interface i_R  = fn_crg_and_rg_to_FIFOF_I (crg_R_full  [port_enq], rg_R);
   endinterface
endmodule: mkAXI4_RTL_to_BSV_2

// ****************************************************************

endpackage
