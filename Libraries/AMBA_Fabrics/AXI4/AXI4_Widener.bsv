// Copyright (c) 2020-2023 Bluespec, Inc. All Rights Reserved
// Copyright (c) 2024 Rishiyur S. Nikhil.

// SPDX-License-Identifier: BSD-3-Clause

package AXI4_Widener;

// ****************************************************************
// This package defines an AXI4-S-to-AXI4-M 'data widener' module.
// The module arguments are an M interface from upstream and an S
// interface to downstream.
// The interfaces facing S and M differ in data-bus width
// The S-side data bus is wider than the M-side by some multiple.

// The primary function here is data-bus re-alignment due to widening.

// NOTE: Does not support bursts yet (which would need reshaping the
// data beats, strobes, burst length, etc.)
// Use AXI4_Deburster in front, if needed.

// ****************************************************************

export mkAXI4_Widener;

// ****************************************************************
// Bluespec library imports

import Vector       :: *;
import FIFOF        :: *;
import SpecialFIFOs :: *;
import ConfigReg    :: *;

// ----------------
// Bluespec misc. libs

import Cur_Cycle  :: *;
import GetPut_Aux :: *;
import Semi_FIFOF :: *;

// ----------------
// Project imports

import AXI4_Types   :: *;

// ****************************************************************
// Simulation verbosity during simulation on stdout for this package (edit as desired)
//   0: quiet
//   1: display rules

Integer verbosity = 0;

// ****************************************************************
// The Widener module

module mkAXI4_Widener #(AXI4_M_IFC #(wd_id_t, wd_addr_t, m_wd_data_t, wd_user_t) ifc_M,
			AXI4_S_IFC #(wd_id_t, wd_addr_t, s_wd_data_t, wd_user_t) ifc_S)
		      (Empty)
   provisos (Mul #(8, m_wd_bytes_t, m_wd_data_t),
	     Div #(m_wd_data_t, 8, m_wd_bytes_t),
	     Mul #(8, s_wd_bytes_t, s_wd_data_t),
	     Div #(s_wd_data_t, 8, s_wd_bytes_t),
	     Add #(m_wd_data_t,  __a, s_wd_data_t),   // m_wd_data <= s_wd_data ("widening")
	     Add #(m_wd_bytes_t, __b, s_wd_bytes_t),  // m_wd_bytes <= s_wd_bytes ("widening")
	     Log #(m_wd_bytes_t, log2_m_wd_bytes_t),
	     Log #(s_wd_bytes_t, log2_s_wd_bytes_t),
	     NumAlias #(word_index_t, TSub #(s_wd_bytes_t, m_wd_bytes_t)));

   Integer log2_m_wd_bytes = valueOf (log2_m_wd_bytes_t);
   Integer log2_s_wd_bytes = valueOf (log2_s_wd_bytes_t);

   // size covers latency to mem read response
   FIFOF #(Bit #(wd_addr_t)) f_araddrs <- mkSizedFIFOF (8);

   // ----------------------------------------------------------------
   // BEHAVIOR

   // ----------------
   // Widen data and strobe from M to S

   function Tuple2 #(Bit #(s_wd_data_t),
		     Bit #(s_wd_bytes_t)) fv_align_to_wider (Bit #(wd_addr_t)     addr,
							     Bit #(m_wd_data_t)   m_data,
							     Bit #(m_wd_bytes_t)  m_strb);
      Bit #(word_index_t) shift_m_words  = addr [log2_s_wd_bytes - 1: log2_m_wd_bytes];
      Bit #(s_wd_data_t)  s_data         = zeroExtend (m_data);
      s_data = s_data << (shift_m_words * fromInteger (valueOf (m_wd_data_t)));

      Bit #(s_wd_bytes_t) s_strb = zeroExtend (m_strb);
      s_strb = s_strb << (shift_m_words * fromInteger (valueOf (m_wd_bytes_t)));
      return tuple2 (s_data, s_strb);
   endfunction

   // ----------------
   // Narrow data from S to M

   function Bit #(m_wd_data_t)
            fv_align_to_narrower (Bit #(wd_addr_t) addr, Bit #(s_wd_data_t) s_data);
      Bit #(word_index_t) shift_m_words = addr [log2_s_wd_bytes - 1: log2_m_wd_bytes];
      s_data = s_data >> (shift_m_words * fromInteger (valueOf (m_wd_data_t)));
      Bit #(m_wd_data_t) m_data  = truncate (s_data);
      return m_data;
   endfunction

   // ----------------
   // AW and W channels (write requests)

   rule rl_AW_W;
      AXI4_AW #(wd_id_t, wd_addr_t, wd_user_t) m_aw <- pop_o (ifc_M.o_AW);
      AXI4_W  #(m_wd_data_t, wd_user_t)        m_w  <- pop_o (ifc_M.o_W);

      let s_aw = m_aw;

      match { .s_wdata, .s_wstrb} = fv_align_to_wider (m_aw.awaddr, m_w.wdata, m_w.wstrb);
      AXI4_W #(s_wd_data_t, wd_user_t) s_w = AXI4_W {wdata: s_wdata,
						       wstrb: s_wstrb,
						       wlast: m_w.wlast,
						       wuser: m_w.wuser};
      // Send to S
      ifc_S.i_AW.enq (s_aw);
      ifc_S.i_W.enq  (s_w);

      // Debugging
      if (verbosity > 0) begin
	 $display ("%0d: AXI4_Widener.rl_AW_W: m -> s", cur_cycle);
	 $display ("    m_aw : ", fshow (m_aw));
	 $display ("    m_w:   ", fshow (m_w));
	 $display ("    s_w:   ", fshow (s_w));
      end
   endrule

   // ----------------
   // B channel (write responses): just pass through as-is.

   rule rl_B;
      AXI4_B #(wd_id_t, wd_user_t) s_b <- pop_o (ifc_S.o_B);
      let m_b = s_b;
      ifc_M.i_B.enq (m_b);

      if (verbosity > 1) begin
	 $display ("%0d: AXI4_Widener.rl_B: m <- s", cur_cycle);
	 $display ("    s_b: ", fshow (s_b));
	 $display ("    m_b: ", fshow (m_b));
      end
   endrule

   // ----------------
   // AR channel (read requests); just pass it through, as-is
   // but remember the addr in order to align the data response.

   rule rl_AR;
      AXI4_AR #(wd_id_t, wd_addr_t, wd_user_t) m_ar <- pop_o (ifc_M.o_AR);
      let s_ar = m_ar;
      ifc_S.i_AR.enq (s_ar);

      f_araddrs.enq (m_ar.araddr);

      // Debugging
      if (verbosity > 0) begin
	 $display ("%0d: AXI4_Widener.rl_AR: m -> s", cur_cycle);
	 $display ("    m_ar: ", fshow (m_ar));
	 $display ("    s_ar: ", fshow (s_ar));
      end
   endrule

   // ----------------
   // R channel (read responses)

   rule rl_R;
      AXI4_R #(wd_id_t, s_wd_data_t, wd_user_t) s_r <- pop_o (ifc_S.o_R);
      let araddr <- pop (f_araddrs);

      let m_rdata = fv_align_to_narrower (araddr, s_r.rdata);
      AXI4_R #(wd_id_t, m_wd_data_t, wd_user_t) m_r = AXI4_R {rid:   s_r.rid,
							      rdata: m_rdata,
							      rresp: s_r.rresp,
							      rlast: s_r.rlast,
							      ruser: s_r.ruser};
      ifc_M.i_R.enq (m_r);

      // Debugging
      if (verbosity > 0) begin
	 $display ("%0d: AXI4_Widener.rl_R: m <- s", cur_cycle);
	 $display ("    s_r: ", fshow (s_r));
	 $display ("    m_r: ", fshow (m_r));
      end
   endrule

   // ================================================================
   // INTERFACE

   // Empty
endmodule

// ****************************************************************

endpackage: AXI4_Widener
