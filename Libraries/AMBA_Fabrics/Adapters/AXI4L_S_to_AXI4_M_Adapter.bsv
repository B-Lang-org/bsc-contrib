// Copyright (c) 2021 Bluespec, Inc. All Rights Reserved
//
// SPDX-License-Identifier: BSD-3-Clause

// Author: Rishiyur S. Nikhil

package AXI4L_S_to_AXI4_M_Adapter;

// ================================================================
// This package defines an adapter module that does two things:
// - AXI4L S to AXI4 M adaptation
// - widening (AXI4L_S fields are narrower than AXI4_M)

// ================================================================
// Bluespec library imports

import Vector       :: *;
import FIFOF        :: *;
import SpecialFIFOs :: *;

// ----------------
// Bluespec misc. libs

import Cur_Cycle  :: *;
import GetPut_Aux :: *;

// ================================================================
// Project imports

import Semi_FIFOF   :: *;
import AXI4L_Types  :: *;
import AXI4_Types   :: *;
import AXI4_BSV_RTL :: *;

// ================================================================
// The interface for the adapter module
//
//  -----------+                        +-------
//             |   +----------------+   |
//         4L_M|---|4L_S Adapter 4_M|---|4_S
//  (AXI4_Lite)|   +----------------+   |(AXI4)
//  -----------+                        +-------
//
// AXI4 data can be wider than AXI4L data (by an 'expansion' multiple)

interface AXI4L_S_to_AXI4_M_Adapter_IFC #(numeric type wd_addr_AXI4L_S,
					  numeric type wd_data_AXI4L_S,
					  numeric type wd_user_AXI4L_S,

					  numeric type wd_id_AXI4_M,
					  numeric type wd_addr_AXI4_M,
					  numeric type wd_data_AXI4_M,
					  numeric type wd_user_AXI4_M);
   // AXI4L S side
   interface AXI4L_S_IFC #(wd_addr_AXI4L_S,
			   wd_data_AXI4L_S,
			   wd_user_AXI4L_S) ifc_AXI4L_S;

   // AXI4 M side
   interface AXI4_RTL_M_IFC #(wd_id_AXI4_M,
			      wd_addr_AXI4_M,
			      wd_data_AXI4_M,
			      wd_user_AXI4_M) ifc_AXI4_M;
endinterface

// ================================================================
// The adapter module

module mkAXI4L_S_to_AXI4_M_Adapter (AXI4L_S_to_AXI4_M_Adapter_IFC #(wd_addr_AXI4L_S,
								    wd_data_AXI4L_S,
								    wd_user_AXI4L_S,
								    wd_id_AXI4_M,
								    wd_addr_AXI4_M,
								    wd_data_AXI4_M,
								    wd_user_AXI4_M))
   // these provisos specify widening
   provisos (Add #(wd_addr_AXI4L_S,         __a, wd_addr_AXI4_M),      // addr widening
	     Mul #(wd_data_AXI4L_S, expansion_t, wd_data_AXI4_M),      // data widening
	     Add #(wd_user_AXI4L_S,         __u, wd_user_AXI4_M),      // user widening
	     Div #(wd_data_AXI4L_S,           8, wd_bytes_AXI4L_S),
	     Div #(wd_data_AXI4_M,            8, wd_bytes_AXI4_M),

	     Bits #(Vector #(expansion_t, Bit #(wd_data_AXI4L_S)),  wd_data_AXI4_M),
	     Bits #(Vector #(expansion_t, Bit #(wd_bytes_AXI4L_S)), wd_bytes_AXI4_M),

	     NumAlias #(TLog #(wd_bytes_AXI4L_S), addr_index_S_t),
	     NumAlias #(TLog #(wd_bytes_AXI4_M),  addr_index_M_t),
	     Add #(addr_index_S_t, index_width_t, addr_index_M_t)
	     );

   // 0 quiet; 1: rules
   Integer verbosity = 0;

   // AXI4L S transactor
   AXI4L_S_Xactor_IFC #(wd_addr_AXI4L_S,
			wd_data_AXI4L_S,
			wd_user_AXI4L_S) xactor_AXI4L_S <- mkAXI4L_S_Xactor;

   // AXI4 M transactor
   AXI4_BSV_to_RTL_IFC #(wd_id_AXI4_M,
			 wd_addr_AXI4_M,
			 wd_data_AXI4_M,
			 wd_user_AXI4_M) xactor_AXI4_M <- mkAXI4_BSV_to_RTL;

   // ================================================================
   // BEHAVIOR

   // ----------------------------------------------------------------
   // Write requests (Write Address and Write Data channels)

   rule rl_AW_W;
      let aw_AXI4L <- pop_o (xactor_AXI4L_S.o_wr_addr);
      let w_AXI4L  <- pop_o (xactor_AXI4L_S.o_wr_data);

      Bit #(wd_id_AXI4_M)   id_AXI4   = 1;
      Bit #(wd_addr_AXI4_M) addr_AXI4 = zeroExtend (aw_AXI4L.awaddr);
      Bit #(wd_user_AXI4_M) user_AXI4 = zeroExtend (aw_AXI4L.awuser);

      AXI4_AW #(wd_id_AXI4_M, wd_addr_AXI4_M, wd_user_AXI4_M)
          aw_AXI4 = AXI4_AW {awid:     id_AXI4,
			     awaddr:   addr_AXI4,
			     awlen:    0,    // AXI4 encoding for "1 beat"
			     awsize:   axsize_4,
			     awburst:  axburst_fixed,
			     awlock:   axlock_normal,
			     awcache:  awcache_dev_nonbuf,
			     awprot:   aw_AXI4L.awprot,
			     awqos:    0,
			     awregion: 0,
			     awuser:   user_AXI4};

      // Lane-align wdata for the wider AXI4

      Vector #(expansion_t, Bit #(wd_data_AXI4L_S))  v_data = unpack (0);
      Vector #(expansion_t, Bit #(wd_bytes_AXI4L_S)) v_strb = unpack (0);

      Integer hi = valueOf (addr_index_M_t) - 1;
      Integer lo = valueOf (addr_index_S_t);
      Bit #(index_width_t) index = aw_AXI4L.awaddr [hi:lo];
      v_data [index] = w_AXI4L.wdata;
      v_strb [index] = w_AXI4L.wstrb;

      AXI4_W #(wd_data_AXI4_M, wd_user_AXI4_M)
          w_AXI4 = AXI4_W {wdata: pack (v_data),
			   wstrb: pack (v_strb),
			   wlast: True,
			   wuser: user_AXI4};

      xactor_AXI4_M.ifc_S.i_AW.enq (aw_AXI4);
      xactor_AXI4_M.ifc_S.i_W.enq  (w_AXI4);

      // Debugging
      if (verbosity > 0) begin
	 $display ("%0d: rl_AW_W:", cur_cycle);
	 $display ("        ", fshow (aw_AXI4L));
	 $display ("    ==>   ", fshow (aw_AXI4));
	 $display ("        ", fshow (w_AXI4));
	 $display ("    ==>   ", fshow (w_AXI4));
      end
   endrule

   // ----------------------------------------------------------------
   // B channel (write responses)

   rule rl_B;
      let b_AXI4 <- pop_o (xactor_AXI4_M.ifc_S.o_B);

      Bit #(wd_user_AXI4L_S) user = truncate (b_AXI4.buser);

      AXI4L_Wr_Resp #(wd_user_AXI4L_S)
          b_AXI4L = AXI4L_Wr_Resp {bresp: unpack (b_AXI4.bresp),
				   buser: user};
      xactor_AXI4L_S.i_wr_resp.enq (b_AXI4L);

      // Debugging
      if (verbosity > 0) begin
	 $display ("%0d: rl_B:", cur_cycle);
	 $display ("        ", fshow (b_AXI4));
	 $display ("    ==>   ", fshow (b_AXI4L));
      end
   endrule

   // ----------------------------------------------------------------
   // Read requests (Read Addr channel)

   // This FIFOF remembers addrs so returned data can properly lane-aligned.
   // For full pipelining, needs to be deep enough to cover latency to target and back.
   FIFOF #(Bit #(wd_addr_AXI4L_S)) f_rd_addrs <- mkSizedFIFOF (32);

   // ----------------

   rule rl_AR;
      let ar_AXI4L <- pop_o (xactor_AXI4L_S.o_rd_addr);

      Bit #(wd_id_AXI4_M)   id_AXI4   = 1;
      Bit #(wd_addr_AXI4_M) addr_AXI4 = zeroExtend (ar_AXI4L.araddr);
      Bit #(wd_user_AXI4_M) user_AXI4 = zeroExtend (ar_AXI4L.aruser);

      AXI4_AR #(wd_id_AXI4_M, wd_addr_AXI4_M, wd_user_AXI4_M)
          ar_AXI4 = AXI4_AR {arid:     id_AXI4,
			     araddr:   addr_AXI4,
			     arlen:    0,    // AXI4 encoding for "1 beat"
			     arsize:   axsize_4,
			     arburst:  axburst_fixed,
			     arlock:   axlock_normal,
			     arcache:  arcache_dev_nonbuf,
			     arprot:   ar_AXI4L.arprot,
			     arqos:    0,
			     arregion: 0,
			     aruser:   user_AXI4};

      xactor_AXI4_M.ifc_S.i_AR.enq (ar_AXI4);

      // Remember addrs so returned data can properly lane-aligned
      f_rd_addrs.enq (ar_AXI4L.araddr);

      // Debugging
      if (verbosity > 0) begin
	 $display ("%0d: rl_AR:", cur_cycle);
	 $display ("         ", fshow (ar_AXI4L));
	 $display ("    ==>    ", fshow (ar_AXI4));
      end
   endrule

   // ----------------------------------------------------------------
   // Read responses (Read Data channel)

   rule rl_R;
      let r_AXI4 <- pop_o (xactor_AXI4_M.ifc_S.o_R);
      let addr_AXI4L   <- pop (f_rd_addrs);

      // Lane-align rdata for the narrower AXI4L

      Vector #(expansion_t, Bit #(wd_data_AXI4L_S))  v_data = unpack (r_AXI4.rdata);

      Integer hi = valueOf (addr_index_M_t) - 1;
      Integer lo = valueOf (addr_index_S_t);
      Bit #(index_width_t) index = addr_AXI4L [hi:lo];
      Bit #(wd_data_AXI4L_S) rdata_AXI4L = v_data [index];

      Bit #(wd_user_AXI4L_S) ruser_AXI4L = truncate (r_AXI4.ruser);

      AXI4L_Rd_Data #(wd_data_AXI4L_S, wd_user_AXI4L_S)
          r_AXI4L = AXI4L_Rd_Data {rresp: unpack (r_AXI4.rresp),
				   rdata: rdata_AXI4L,
				   ruser: ruser_AXI4L };

      xactor_AXI4L_S.i_rd_data.enq (r_AXI4L);

      // Debugging
      if (verbosity > 0) begin
	 $display ("%0d: rl_R:", cur_cycle);
	 $display ("          ", fshow (r_AXI4));
	 $display ("    ==>     ", fshow (r_AXI4L));
      end
   endrule

   // ----------------------------------------------------------------
   // INTERFACE

   interface ifc_AXI4L_S = xactor_AXI4L_S.axi_side;
   interface ifc_AXI4_M  = xactor_AXI4_M .rtl_M;
endmodule

// ================================================================

endpackage
