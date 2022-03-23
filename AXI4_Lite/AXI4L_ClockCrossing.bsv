package AXI4L_ClockCrossing;

import Clocks ::*;
import AXI4_Lite_Types ::*;
import AXI4_Extra_Xactors ::*;
import Connectable ::*;
import Semi_FIFOF ::*;
import GetPut ::*;

// ================================================================

interface AXI4L_ClockCrossing_IFC #(
  numeric type addr_,
  numeric type data_,
  numeric type user_);
   interface AXI4_Lite_Slave_IFC  #(addr_, data_, user_) from_M;
   interface AXI4_Lite_Master_IFC #(addr_, data_, user_) to_S;
endinterface

// ================================================================

module mkAXI4L_ClockCrossing #(Clock master_clock,
			      Reset master_reset,
			      Clock slave_clock,
			      Reset slave_reset)
		       (AXI4L_ClockCrossing_IFC #(addr_, data_, user_));

   SyncFIFOIfc #(AXI4_Lite_Wr_Addr #(addr_, user_))  f_aw <- mkSyncFIFO (4, master_clock, master_reset,  slave_clock);
   SyncFIFOIfc #(AXI4_Lite_Wr_Data #(data_))       f_w  <- mkSyncFIFO (4, master_clock, master_reset,  slave_clock);
   SyncFIFOIfc #(AXI4_Lite_Wr_Resp #(user_))         f_b  <- mkSyncFIFO (4,  slave_clock,  slave_reset, master_clock);

   SyncFIFOIfc #(AXI4_Lite_Rd_Addr #(addr_, user_))  f_ar <- mkSyncFIFO (4, master_clock, master_reset,  slave_clock);
   SyncFIFOIfc #(AXI4_Lite_Rd_Data #(data_, user_))  f_r  <- mkSyncFIFO (4,  slave_clock,  slave_reset, master_clock);

   AXI4_Lite_Slave_IFC  #(addr_, data_, user_)  slave_xactor <- mkAXI4_Lite_Slave_Xactor_3 (f_aw, f_w, f_b, f_ar, f_r,
											      clocked_by master_clock,
											      reset_by master_reset);
   AXI4_Lite_Master_IFC #(addr_, data_, user_) master_xactor <- mkAXI4_Lite_Master_Xactor_3(f_aw, f_w, f_b, f_ar, f_r,
											      clocked_by slave_clock,
											      reset_by slave_reset);

   interface AXI4_Lite_Slave_IFC  from_M =  slave_xactor;
   interface AXI4_Lite_Master_IFC   to_S = master_xactor;
endmodule

module mkAXI4L_ClockCrossingToCC #(Clock master_clock, Reset master_reset)
			   (AXI4L_ClockCrossing_IFC #(addr_, data_, user_));
   let slave_clock <- exposeCurrentClock;
   let slave_reset <- exposeCurrentReset;
   let crossing <- mkAXI4L_ClockCrossing (master_clock, master_reset, slave_clock, slave_reset);

   return crossing;
endmodule

endpackage
