// Copyright (c) 2022 Bluespec, Inc. All Rights Reserved
//
// SPDX-License-Identifier: BSD-3-Clause

package AXI4L_ClockCrossing;

import Clocks ::*;
import Connectable ::*;
import Semi_FIFOF ::*;
import GetPut ::*;

import AXI4L_Types ::*;
import AXI4L_Xactors ::*;

// ================================================================

interface AXI4L_ClockCrossing_IFC #(
  numeric type addr_,
  numeric type data_,
  numeric type user_);
   interface AXI4L_S_IFC  #(addr_, data_, user_) from_M;
   interface AXI4L_M_IFC #(addr_, data_, user_) to_S;
endinterface

// ================================================================

module mkAXI4L_ClockCrossing #(Clock clock_M,
			      Reset reset_M,
			      Clock clock_S,
			      Reset reset_S)
		       (AXI4L_ClockCrossing_IFC #(addr_, data_, user_));

   SyncFIFOIfc #(AXI4L_Wr_Addr #(addr_, user_))
   f_aw <- mkSyncFIFO (4, clock_M, reset_M,  clock_S);

   SyncFIFOIfc #(AXI4L_Wr_Data #(data_))
   f_w  <- mkSyncFIFO (4, clock_M, reset_M,  clock_S);

   SyncFIFOIfc #(AXI4L_Wr_Resp #(user_))
   f_b  <- mkSyncFIFO (4,  clock_S,  reset_S, clock_M);

   SyncFIFOIfc #(AXI4L_Rd_Addr #(addr_, user_))
   f_ar <- mkSyncFIFO (4, clock_M, reset_M,  clock_S);

   SyncFIFOIfc #(AXI4L_Rd_Data #(data_, user_))
   f_r  <- mkSyncFIFO (4,  clock_S,  reset_S, clock_M);

   AXI4L_S_IFC  #(addr_, data_, user_)
   s_xactor <- mkAXI4L_Xactor_S_3 (f_aw, f_w, f_b, f_ar, f_r,
				   clocked_by clock_M,
				   reset_by reset_M);

   AXI4L_M_IFC #(addr_, data_, user_)
   m_xactor <- mkAXI4L_Xactor_M_3 (f_aw, f_w, f_b, f_ar, f_r,
				   clocked_by clock_S,
				   reset_by reset_S);

   interface AXI4L_S_IFC  from_M = s_xactor;
   interface AXI4L_M_IFC  to_S   = m_xactor;
endmodule

module mkAXI4L_ClockCrossingToCC #(Clock clock_M, Reset reset_M)
			   (AXI4L_ClockCrossing_IFC #(addr_, data_, user_));
   let clock_S <- exposeCurrentClock;
   let reset_S <- exposeCurrentReset;
   let crossing <- mkAXI4L_ClockCrossing (clock_M, reset_M, clock_S, reset_S);

   return crossing;
endmodule

endpackage
