// Copyright (c) 2022-2024 Bluespec, Inc. All Rights Reserved
// Author: Rishiyur S. Nikhil
// (adapted and renamed from original code from Joe Stoy)

// SPDX-License-Identifier: BSD-3-Clause

package AXI4_Clock_Crossers;

// ================================================================
// This package defines clock-domain-crossing modules for AXI4 M and S
// interfaces:

//   Clock -> Clock -> AXI4_RTL_M_IFC -> Module #(AXI4_RTL_M_IFC)
export mkAXI4_M_Clock_Crosser;

//   Clock -> Clock -> AXI4_RTL_S_IFC -> Module #(AXI4_RTL_S_IFC)
export mkAXI4_S_Clock_Crosser;

export AXI4_SyncBuffer_IFC (..);

//   Clock1 -> Clock2 -> Module #(AXI4_Clock_Crossing_IFC)
export mkAXI4_SyncBuffer;

//   Clock1 ->           Module #(AXI4_Clock_Crossing_IFC)
export mkAXI4_SyncBufferToCC;

// ================================================================
// Bluespec library imports

import Clocks      :: *;
import Connectable :: *;

// ----------------
// Bluespec misc. libs

import Cur_Cycle  :: *;
import GetPut_Aux :: *;
import Semi_FIFOF :: *;

// ================================================================
// Project imports

import AXI4_Types      :: *;
import AXI4_BSV_RTL    :: *;
import AXIx_SyncBuffer :: *;

// ================================================================
// Function to transform an AXI4_S_IFC with a clock crosser
// Clock1 -> Clock2 -> AXI4_S_IFC (on clock2) -> Module #(AXI4_S_IFC (on clock 1))
// Clock1 is the upstream clock
// Clock2 is the downstream clock

module mkAXI4_S_Clock_Crosser #(Integer depth,
				Clock clk1, Reset rst1,
				Clock clk2, Reset rst2,
				AXI4_S_IFC #(wd_id, wd_addr, wd_data, wd_user) ifc_S)
                              (AXI4_S_IFC #(wd_id, wd_addr, wd_data, wd_user));

   AXIx_SyncBuffer_IFC #(AXI4_AW #(wd_id, wd_addr, wd_user),
			 AXI4_W  #(wd_data, wd_user),
			 AXI4_B  #(wd_id, wd_user),
			 AXI4_AR #(wd_id, wd_addr, wd_user),
			 AXI4_R  #(wd_id, wd_data, wd_user))
   axi4_syncbuf <- mkAXIx_SyncBuffer (depth, clk1, rst1, clk2, rst2);

   // ----------------

   mkConnection (axi4_syncbuf.to_S.o_aw, ifc_S.i_AW);
   mkConnection (axi4_syncbuf.to_S.o_w,  ifc_S.i_W);
   mkConnection (axi4_syncbuf.to_S.i_b,  ifc_S.o_B);
   mkConnection (axi4_syncbuf.to_S.o_ar, ifc_S.i_AR);
   mkConnection (axi4_syncbuf.to_S.i_r,  ifc_S.o_R);

   // ----------------
   // INTERFACE

   interface i_AW = axi4_syncbuf.from_M.i_aw;
   interface i_W  = axi4_syncbuf.from_M.i_w;
   interface o_B  = axi4_syncbuf.from_M.o_b;
   interface i_AR = axi4_syncbuf.from_M.i_ar;
   interface o_R  = axi4_syncbuf.from_M.o_r;
endmodule

// ================================================================
// Function to transform an AXI4_M_IFC with a clock crosser
// Clock1 -> Clock2 -> AXI4_M_IFC (on clock1) -> Module #(AXI4_M_IFC (on clock 2))
// Clock1 is the upstream clock
// Clock2 is the downstream clock

module mkAXI4_M_Clock_Crosser #(Integer depth,
				Clock clk1, Reset rst1,
				Clock clk2, Reset rst2,
				AXI4_M_IFC #(wd_id, wd_addr, wd_data, wd_user) ifc_M)
                              (AXI4_M_IFC #(wd_id, wd_addr, wd_data, wd_user));

   // Syncbuffer between transactors
   AXIx_SyncBuffer_IFC #(AXI4_AW #(wd_id, wd_addr, wd_user),
			 AXI4_W  #(wd_data, wd_user),
			 AXI4_B  #(wd_id, wd_user),
			 AXI4_AR #(wd_id, wd_addr, wd_user),
			 AXI4_R  #(wd_id, wd_data, wd_user))

   axi4_syncbuf <- mkAXIx_SyncBuffer (depth, clk1, rst1, clk2, rst2);

   // ----------------

   mkConnection (ifc_M.o_AW, axi4_syncbuf.from_M.i_aw);
   mkConnection (ifc_M.o_W,  axi4_syncbuf.from_M.i_w);
   mkConnection (ifc_M.i_B,  axi4_syncbuf.from_M.o_b);
   mkConnection (ifc_M.o_AR, axi4_syncbuf.from_M.i_ar);
   mkConnection (ifc_M.i_R,  axi4_syncbuf.from_M.o_r);

   // ----------------
   // INTERFACE

   interface o_AW = axi4_syncbuf.to_S.o_aw;
   interface o_W  = axi4_syncbuf.to_S.o_w;
   interface i_B  = axi4_syncbuf.to_S.i_b;
   interface o_AR = axi4_syncbuf.to_S.o_ar;
   interface i_R  = axi4_syncbuf.to_S.i_r;
endmodule

// ================================================================
// Standalone clock-crosser with M and S interfaces
// Clock1 -> Clock2 -> Module #(AXI4_Clock_Crossing_IFC)

interface AXI4_SyncBuffer_IFC #(numeric type id_,
				numeric type addr_,
				numeric type data_,
				numeric type user_);
   interface AXI4_S_IFC #(id_, addr_, data_, user_) from_M;
   interface AXI4_M_IFC #(id_, addr_, data_, user_) to_S;
endinterface

// ----------------

module mkAXI4_SyncBuffer #(Integer depth,
			   Clock clock_M, Reset reset_M,
			   Clock clock_S, Reset reset_S)
                         (AXI4_SyncBuffer_IFC #(id_, addr_, data_, user_));

   let axi4_syncbuf <- mkAXIx_SyncBuffer (depth, clock_M, reset_M, clock_S, reset_S);

   // ----------------
   // INTERFACE

   interface AXI4_S_IFC from_M;
      interface i_AW = axi4_syncbuf.from_M.i_aw;
      interface i_W  = axi4_syncbuf.from_M.i_w;
      interface o_B  = axi4_syncbuf.from_M.o_b;
      interface i_AR = axi4_syncbuf.from_M.i_ar;
      interface o_R  = axi4_syncbuf.from_M.o_r;
   endinterface
   interface AXI4_M_IFC to_S;
      interface o_AW = axi4_syncbuf.to_S.o_aw;
      interface o_W  = axi4_syncbuf.to_S.o_w;
      interface i_B  = axi4_syncbuf.to_S.i_b;
      interface o_AR = axi4_syncbuf.to_S.o_ar;
      interface i_R  = axi4_syncbuf.to_S.i_r;
   endinterface
endmodule

// ----------------------------------------------------------------
// Same as above, with S-side using current-clock

module mkAXI4_SyncBufferToCC #(Integer depth,
			       Clock clock_M, Reset reset_M)
                             (AXI4_SyncBuffer_IFC #(id_, addr_, data_, user_));

   let clock_S <- exposeCurrentClock;
   let reset_S <- exposeCurrentReset;

   let crossing <- mkAXI4_SyncBuffer (depth,
				      clock_M, reset_M,
				      clock_S, reset_S);
   return crossing;
endmodule

// ================================================================

endpackage
