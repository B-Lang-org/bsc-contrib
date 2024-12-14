// Copyright (c) 2020 Bluespec, Inc. All Rights Reserved
// Copyright (c) 2024 Rishiyur S. Nikhil.
//
// SPDX-License-Identifier: BSD-3-Clause

package AXI4_Addr_Translator;

// ================================================================
// This package defines transformers for AXI4_M and AXI4_S interfaces
// that perform a simple 'address-translator' (add/subtract a fixed
// constant from address).
// Each transformer copies AW and AR, just adjusting the address,
// and just copies W, B and R.

// ================================================================
// Bluespec library imports

// none

// ----------------
// Bluespec misc. libs

import Semi_FIFOF :: *;

// ================================================================
// Project imports

import AXI4_Types   :: *;

// ================================================================
// M-to-M interface transformer with address translation.

function AXI4_M_IFC #(wd_id, wd_addr, wd_data, wd_user)
         fv_AXI4_M_Address_Translator (Bool                  add_not_sub,
				       Bit #(wd_addr)        addr_delta,
				       AXI4_M_IFC #(wd_id,
						    wd_addr,
						    wd_data,
						    wd_user) ifc_M);

   function Bit #(wd_addr) fv_addr_translate (Bit #(wd_addr)  addr);
      return (add_not_sub ? addr + addr_delta : addr - addr_delta);
   endfunction

   return interface AXI4_M_IFC
	     interface FIFOF_O o_AW;
		method first;
		   let aw_in = ifc_M.o_AW.first;
		   let aw_out = AXI4_AW {awid:     aw_in.awid,
					 awaddr:   fv_addr_translate (aw_in.awaddr),
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
		endmethod
		method deq = ifc_M.o_AW.deq;
		method notEmpty = ifc_M.o_AW.notEmpty;
	     endinterface

	     interface FIFOF_I o_W  = ifc_M.o_W;

	     interface FIFOF_I i_B  = ifc_M.i_B;

	     interface FIFOF_O o_AR;
		method first;
		   let ar_in = ifc_M.o_AR.first;
		   let ar_out = AXI4_AR {arid:     ar_in.arid,
					 araddr:   fv_addr_translate (ar_in.araddr),
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
		endmethod
		method deq = ifc_M.o_AR.deq;
		method notEmpty = ifc_M.o_AR.notEmpty;
	     endinterface

	     interface FIFOF_I i_R  = ifc_M.i_R;
	  endinterface;
endfunction

// ================================================================
// S-to-S interface transformer with address translation

function AXI4_S_IFC #(wd_id, wd_addr, wd_data, wd_user)
         fv_AXI4_S_Address_Translator (Bool                    add_not_sub,
				       Bit #(wd_addr)          addr_delta,
				       AXI4_S_IFC  #(wd_id,
						     wd_addr,
						     wd_data,
						     wd_user)  ifc_S);

   function Bit #(wd_addr) fv_addr_translate (Bit #(wd_addr)  addr);
      return (add_not_sub ? addr + addr_delta : addr - addr_delta);
   endfunction

   return interface AXI4_S_IFC
	     interface FIFOF_I i_AW;
		method Action enq (AXI4_AW #(wd_id, wd_addr, wd_user) aw_in);
		   action
		      let aw_out = AXI4_AW {awid:     aw_in.awid,
					    awaddr:   fv_addr_translate (aw_in.awaddr),
					    awlen:    aw_in.awlen,
					    awsize:   aw_in.awsize,
					    awburst:  aw_in.awburst,
					    awlock:   aw_in.awlock,
					    awcache:  aw_in.awcache,
					    awprot:   aw_in.awprot,
					    awqos:    aw_in.awqos,
					    awregion: aw_in.awregion,
					    awuser:   aw_in.awuser};
		      ifc_S.i_AW.enq (aw_out);
		   endaction
		endmethod
		method notFull = ifc_S.i_AW.notFull;
	     endinterface

	     interface FIFOF_I i_W = ifc_S.i_W;
	     interface FIFOF_O o_B = ifc_S.o_B;

	     interface FIFOF_I i_AR;
		method Action enq (AXI4_AR #(wd_id, wd_addr, wd_user) ar_in);
		   action
		      let ar_out = AXI4_AR {arid:     ar_in.arid,
					    araddr:   fv_addr_translate (ar_in.araddr),
					    arlen:    ar_in.arlen,
					    arsize:   ar_in.arsize,
					    arburst:  ar_in.arburst,
					    arlock:   ar_in.arlock,
					    arcache:  ar_in.arcache,
					    arprot:   ar_in.arprot,
					    arqos:    ar_in.arqos,
					    arregion: ar_in.arregion,
					    aruser:   ar_in.aruser};
		      ifc_S.i_AR.enq (ar_out);
		   endaction
		endmethod
		method notFull = ifc_S.i_AR.notFull;
	     endinterface

	     interface FIFOF_O o_R = ifc_S.o_R;
	  endinterface;
endfunction

// ================================================================

endpackage: AXI4_Addr_Translator
