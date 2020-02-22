// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package PTMClocks;

import Clocks::*;

// ======================================================

(* always_ready, always_enabled *)
interface OutputBit;
   method Bit#(1) out;
endinterface

import "BVI" ASSIGN1 =
module packClock#(Clock clk)(OutputBit);

   default_clock no_clock;
   default_reset no_reset;

   input_clock clk(IN) = clk;

   method OUT out;

   schedule (out) CF (out);

endmodule

// ======================================================

interface EnabledClock;
   interface Clock clock_out;
endinterface

import "BVI" ClockGater =
module mkClockGater (Bool en, EnabledClock ifcout) ;
   default_clock xclk(CLK, (*unused*)CLKGATE) ;
   no_reset;
   port COND = en;
   output_clock clock_out(CLK_OUT, CLK_GATE_OUT);
endmodule

// ======================================================

interface EdgeDetector;
   method Bool b;
endinterface

module mkEdgeDetector#(Clock xtor_clk)(EdgeDetector);
   let clk <- exposeCurrentClock;

   let packedXtorClk <- packClock(xtor_clk);
   Bool x_clk = unpack(packedXtorClk.out);

   Reg#(Bool) r1 <- mkRegU;
   Reg#(Bool) r2 <- mkRegU;
   Reg#(Bool) r3 <- mkRegU;
   Reg#(Bool) r4 <- mkRegU;

   (*no_implicit_conditions, fire_when_enabled*)
   rule setR1;
      r1 <= x_clk;
   endrule
   (*no_implicit_conditions, fire_when_enabled*)
   rule setR2;
      r2 <= (x_clk && !r1);
      r3 <= r2;
      r4 <= r3;
   endrule

   method b = r4;
endmodule

module mkEdgeDetectorSim#(Clock xtor_clk)(EdgeDetector);
   let clk <- exposeCurrentClock;

   let packedXtorClk <- packClock(xtor_clk);
   Bool x_clk = unpack(packedXtorClk.out);

   Reg#(Bool) r1 <- mkRegU;
   Reg#(UInt#(4)) r2 <- mkReg(0);
   Reg#(UInt#(4)) r3 <- mkReg(0);
   Reg#(Bool) r4 <- mkRegU;

   (*no_implicit_conditions, fire_when_enabled*)
   rule every;
      r1 <= x_clk;
      if (x_clk && !r1) begin
	 r2 <= 0;
      end
      else begin
	 let n = r2 + 1;
	 r2 <= n;
	 r3 <= max(r3, n);
	 r4 <= (r2 == r3-2);
      end
   endrule

   //warningM("Sim version of Edge Detector");
   method b = r4;
endmodule

endpackage
