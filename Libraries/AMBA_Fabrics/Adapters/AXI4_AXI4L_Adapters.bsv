// Copyright (c) 2019-2024 Bluespec, Inc.  All Rights Reserved
//
// SPDX-License-Identifier: BSD-3-Clause

package AXI4_AXI4L_Adapters;

// ================================================================
// Adapters for interconnecting AXI4 and AXI4_Lite.

// Ref: ARM document:
//    AMBA AXI and ACE Protocol Specification
//    AXI3, AXI4, and AXI4-Lite
//    ACE and ACE-Lite
//    ARM IHI 0022E (ID022613)
//    Issue E, 22 Feb 2013

// See export list below

// ================================================================
// Exports

export

fn_AXI4L_M_IFC_to_AXI4_RTL_M_IFC;

// ================================================================
// BSV library imports

import FIFOF       :: *;
import Connectable :: *;

// ----------------
// Bluespec misc. libs

import Semi_FIFOF :: *;
import EdgeFIFOFs :: *;

// ================================================================
// Project imports

import AXI4L_Types  :: *;
import AXI4_Types   :: *;
import AXI4_BSV_RTL :: *;

// ================================================================
// Compute the encoding of AWSIZE/ARSIZE

function Bit #(3) wd_data_to_axsize (Integer wd_data_i);
   Bit #(3) axsize = (  (wd_data_i == 32)
		      ? 3'b_010
		      : (  (wd_data_i == 64)
			 ? 3'b_011
			 : 3'b_000));
   return axsize;
endfunction

// ================================================================

function AXI4_RTL_M_IFC #(wd_id, wd_addr, wd_data, wd_user)
         fn_AXI4L_M_IFC_to_AXI4_RTL_M_IFC
         (AXI4L_M_IFC #(wd_addr, wd_data, wd_user)  axi4L);

   return
   interface AXI4_RTL_M_IFC;

      // ----------------
      // Wr Addr channel
      // output buses
      method Bool           m_awvalid = axi4L.m_awvalid;

      method Bit #(wd_id)   m_awid     = 0;
      method Bit #(wd_addr) m_awaddr   = axi4L.m_awaddr;
      method Bit #(8)       m_awlen    = 0;                       // burst length = awlen+1
      method Bit #(3)       m_awsize   = wd_data_to_axsize (valueOf (wd_data));
      method Bit #(2)       m_awburst  = 2'b_00;                  // FIXED
      method Bit #(1)       m_awlock   = 0;                       // NORMAL
      method Bit #(4)       m_awcache  = 4'b_0000;                // Device Non-Bufferable
      method Bit #(3)       m_awprot   = axi4L.m_awprot;
      method Bit #(4)       m_awqos    = 4'b_0000;
      method Bit #(4)       m_awregion = 4'b_0000;
      method Bit #(wd_user) m_awuser   = 0;

      // input buses
      method Action m_awready (Bool awready) = axi4L.m_awready (awready);

      // ----------------
      // Wr Data channel
      // output buses
      method Bool                      m_wvalid = axi4L.m_wvalid;

      method Bit #(wd_data)            m_wdata  = axi4L.m_wdata;
      method Bit #(TDiv #(wd_data, 8)) m_wstrb  = axi4L.m_wstrb;
      method Bool                      m_wlast  = True;
      method Bit #(wd_user)            m_wuser  = 0;

      // input buses
      method Action m_wready (Bool wready) = axi4L.m_wready (wready);

      // ----------------
      // Wr Response channel
      // input buses
      method Action m_bvalid (Bool           bvalid,
			      Bit #(wd_id)   bid,
			      Bit #(2)       bresp,
			      Bit #(wd_user) buser) = axi4L.m_bvalid (bvalid,
								      bresp,
								      0);

      // output buses
      method Bool m_bready = axi4L.m_bready;

      // ----------------
      // Rd Addr channel
      // output buses
      method Bool            m_arvalid = axi4L.m_arvalid;

      method Bit #(wd_id)    m_arid     = 0;
      method Bit #(wd_addr)  m_araddr   = axi4L.m_araddr;
      method Bit #(8)        m_arlen    = 0;                       // burst length = awlen+1
      method Bit #(3)        m_arsize   = wd_data_to_axsize (valueOf (wd_data));
      method Bit #(2)        m_arburst  = 2'b_00;                  // FIXED
      method Bit #(1)        m_arlock   = 0;                       // NORMAL
      method Bit #(4)        m_arcache  = 4'b_0000;                // Device Non-Bufferable
      method Bit #(3)        m_arprot   = axi4L.m_arprot;
      method Bit #(4)        m_arqos    = 4'b_0000;
      method Bit #(4)        m_arregion = 4'b_0000;
      method Bit #(wd_user)  m_aruser   = axi4L.m_aruser;

      // input buses
      method Action m_arready (Bool arready) = axi4L.m_arready (arready);

      // ----------------
      // Rd Data channel
      // input buses
      method Action m_rvalid (Bool           rvalid,
			      Bit #(wd_id)   rid,
			      Bit #(wd_data) rdata,
			      Bit #(2)       rresp,
			      Bool           rlast,
			      Bit #(wd_user) ruser) = axi4L.m_rvalid (rvalid,
								      rresp,
								      rdata,
								      0);

      // output buses
      method Bool m_rready = axi4L.m_rready;

   endinterface;
endfunction

// ================================================================
// Transformer to get AXI4L S interface from an AXI4 S interface

function AXI4L_S_IFC #(wd_addr, wd_data, wd_user)
         fv_AXI4_RTL_S_IFC_to_AXI4L_S_IFC
         (AXI4_RTL_S_IFC #(wd_id, wd_addr, wd_data, wd_user)  axi4);

   return
   interface AXI4L_S_IFC;

      // ----------------
      // Wr Addr channel
      // input buses
      method Action m_awvalid (Bool           awvalid,    // in
			       Bit #(wd_addr) awaddr,     // in
			       Bit #(3)       awprot,     // in
			       Bit #(wd_user) awuser);    // in
	 axi4.m_awvalid (awvalid,
			 0,                     // awid
			 awaddr,
			 0,                     // awlen (= burst len 1)
			 wd_data_to_axsize (valueOf (wd_data)),
			 axburst_fixed,
			 axlock_normal,
			 awcache_dev_nonbuf,
			 awprot,
			 0,                     // qos
			 0,                     // region
			 awuser);
      endmethod

      // output buses
      method Bool m_awready = axi4.m_awready;

      // ----------------
      // Wr Data channel
      // input buses
      method Action m_wvalid (Bool                     wvalid,    // in
			      Bit #(wd_data)           wdata,     // in
			      Bit #(TDiv #(wd_data,8)) wstrb);    // in
	 axi4.m_wvalid(wvalid,
		       wdata,
		       wstrb,
		       True,    // wlast
		       0);      // wuser
      endmethod

      // output buses
      method Bool m_wready = axi4.m_wready;

      // ----------------
      // Wr Response channel
      // output buses
      method Bool           m_bvalid = axi4.m_bvalid;
      method Bit #(2)       m_bresp  = axi4.m_bresp;
      method Bit #(wd_user) m_buser  = axi4.m_buser;

      // input buses
      method Action m_bready  (Bool bready);    // in
	 axi4.m_bready (bready);
      endmethod

      // ----------------
      // Rd Addr channel
      // input buses
      method Action m_arvalid (Bool           arvalid,    // in
			       Bit #(wd_addr) araddr,     // in
			       Bit #(3)       arprot,     // in
			       Bit #(wd_user) aruser);    // in
	 axi4.m_arvalid (arvalid,
			 0,                     // arid
			 araddr,
			 0,                     // arlen (= burst len 1)
			 wd_data_to_axsize (valueOf (wd_data)),
			 axburst_fixed,
			 axlock_normal,
			 arcache_dev_nonbuf,
			 arprot,
			 0,                     // qos
			 0,                     // region
			 aruser);
      endmethod

      // output buses
      method Bool m_arready = axi4.m_arready;

      // ----------------
      // Rd Data channel
      // input buses
      method Bool           m_rvalid = axi4.m_rvalid;    // out
      method Bit #(2)       m_rresp  = axi4.m_rresp;     // out
      method Bit #(wd_data) m_rdata  = axi4.m_rdata;     // out
      method Bit #(wd_user) m_ruser  = axi4.m_ruser;     // out

      method Action m_rready  (Bool rready);    // in
	 axi4.m_rready (rready);
      endmethod
   endinterface;
endfunction

// ================================================================

endpackage
