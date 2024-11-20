// Copyright (c) 2020 Bluespec, Inc. All Rights Reserved
//
// SPDX-License-Identifier: BSD-3-Clause

package AXI4_ClockCrossing;

import Clocks ::*;
import AXI4_Types ::*;
import AXI4_Extra_Xactors ::*;
import Connectable ::*;
import Semi_FIFOF ::*;
import GetPut ::*;

// ================================================================

interface AXI4_ClockCrossing_IFC #(numeric type id_,
				   numeric type addr_,
				   numeric type data_,
				   numeric type user_);
   interface AXI4_S_IFC  #(id_, addr_, data_, user_) from_M;
   interface AXI4_M_IFC #(id_, addr_, data_, user_) to_S;
endinterface

// ================================================================

module mkAXI4_ClockCrossing #(Clock clock_M,
			      Reset reset_M,
			      Clock clock_S,
			      Reset reset_S)
		            (AXI4_ClockCrossing_IFC #(id_, addr_, data_, user_));

   SyncFIFOIfc #(AXI4_Wr_Addr #(id_, addr_, user_))
   f_aw <- mkSyncFIFO (4, clock_M, reset_M,  clock_S);

   SyncFIFOIfc #(AXI4_Wr_Data #(data_, user_))
   f_w  <- mkSyncFIFO (4, clock_M, reset_M,  clock_S);

   SyncFIFOIfc #(AXI4_Wr_Resp #(id_, user_))
   f_b  <- mkSyncFIFO (4,  clock_S,  reset_S, clock_M);

   SyncFIFOIfc #(AXI4_Rd_Addr #(id_, addr_, user_))
   f_ar <- mkSyncFIFO (4, clock_M, reset_M,  clock_S);

   SyncFIFOIfc #(AXI4_Rd_Data #(id_, data_, user_))
   f_r  <- mkSyncFIFO (4,  clock_S,  reset_S, clock_M);

   AXI4_S_IFC  #(id_, addr_, data_, user_)
   s_xactor <- mkAXI4_S_Xactor_3 (f_aw, f_w, f_b, f_ar, f_r,
				  clocked_by clock_M,
				  reset_by reset_M);

   AXI4_M_IFC #(id_, addr_, data_, user_)
   m_xactor <- mkAXI4_M_Xactor_3 (f_aw, f_w, f_b, f_ar, f_r,
				  clocked_by clock_S,
				  reset_by reset_S);

   interface AXI4_S_IFC  from_M =  s_xactor;
      interface AXI4_M_IFC  to_S   = m_xactor;
endmodule

// ----------------------------------------------------------------
// Same as above, with S-side using current-clock

module mkAXI4_ClockCrossingToCC #(Clock clock_M, Reset reset_M)
                                (AXI4_ClockCrossing_IFC #(id_, addr_, data_, user_));
   let clock_S  <- exposeCurrentClock;
   let reset_S  <- exposeCurrentReset;
   let crossing <- mkAXI4_ClockCrossing (clock_M, reset_M, clock_S, reset_S);

   return crossing;
endmodule

endpackage
