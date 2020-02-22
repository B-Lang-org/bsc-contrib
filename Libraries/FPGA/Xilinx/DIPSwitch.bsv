// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package DIPSwitch;


// This is a simple controller for using the DIP switches on
// Xilinx evaluation boards.

import Clocks :: *;

// This is the interface for the FPGA boundary
interface DIP#(numeric type n);
   (* always_ready, always_enabled *)
   method Action switch(Bit#(n) setting);
endinterface

// This is the full DIP switch interface
interface DIPSwitch#(numeric type n);
   // Returns True for one cycle when the DIP switch settings change
   (* always_ready *)
   method Bool changed();
   // The current DIP switch settings
   (* always_ready *)
   method Bit#(n) _read();
   // The interface for connecting to the FPGA pins for the DIP switch
   (* prefix = "" *)
   interface DIP#(n) ifc;
endinterface

// This creates a controller for a single bank of n DIP switches
module mkDIPSwitch#(Clock fpga_clk)(DIPSwitch#(n));

   Clock clk <- exposeCurrentClock();
   CrossingReg#(Bit#(n)) value <- mkNullCrossingReg(clk, 0, clocked_by fpga_clk, reset_by noReset);

   Reg#(Bit#(n))  prev_value <- mkReg(0);
   Reg#(UInt#(2)) init       <- mkReg(3);

   rule do_init if (init != 0);
      init <= init - 1;
   endrule

   rule history;
      prev_value <= value.crossed();
   endrule

   method Bool changed();
      return (init == 1) || (prev_value != value.crossed());
   endmethod

   method Bit#(n) _read = value.crossed();

   interface DIP ifc;
      method Action switch(Bit#(n) setting);
         value <= setting;
      endmethod
   endinterface

endmodule

endpackage: DIPSwitch
