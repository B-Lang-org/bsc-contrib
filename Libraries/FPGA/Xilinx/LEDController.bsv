// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package LEDController;

// This package contains some logic for doing useful things with LEDs
// beyond just connecting them to a signal.
//
// The LEDController supports setting the LED to an intermediate
// brightness level, blinking the LED at different speeds, and using
// the LED as an activity meter.

import Clocks :: *;
import Vector :: *;
import DummyDriver :: *;

export Time, Level, Lag;
export led_off, led_on_max;
export no_lag, max_lag;
export LED(..), LEDController(..), mkLEDController;
export combineLEDs, bitsToLED;

typedef UInt#(16) Time;   // Very roughly a count of ms
typedef UInt#(3)  Level;  // Brightness level
typedef UInt#(4)  Lag;    // How slowly brightness changes

// Constants for min and max brightness levels
Level led_off    = 0;
Level led_on_max = unpack('1);

// Constants for least and maximum lag amounts
Lag no_lag  = 0;
Lag max_lag = unpack('1);

// This is the interface that goes out of the FPGA to the LED
interface LED#(numeric type n);
   (* always_ready *)
   method Bit#(n) out;
endinterface

// This allows us to stub out the LED ports so they may exist
// in the netlist, but can be tied-off.
instance DummyDriver#(LED#(n));
   module mkStub(LED#(n) ifc);
      method Bit#(n) out = 0;
   endmodule
endinstance

// This is the main controller interface
interface LEDController;
   // Set the lag value, which controls how slowly brightness levels
   // change.  The fastest change occurs with no_lag and the
   // slowest change occurs with max_lag.
   (* always_ready *)
   method Action setLag(Lag l);
   // Blink the LED, alternating between lo_lvl brightness for lo_time
   // and then hi_lvl brightness for hi_time.  Setting lo_lvl ==
   // hi_lvl will give a steady brightness at the requested level.
   (* always_ready *)
   method Action setPeriod(Level lo_lvl, Time lo_time,
                           Level hi_lvl, Time hi_time);
   // Go into activity mode, where the LED goes to maximum brightness
   // for on_time after a bump() method call and then turns off if
   // no more bumps occur.
   (* always_ready *)
   method Action setActivity(Time on_time);
   // In activity mode, this method causes the LED to flash.
   (* always_ready *)
   method Action bump();
   // The interface for connecting to the FPGA pins
   (* prefix = "" *)
   interface LED#(1) ifc;
endinterface: LEDController

// Implementation of an LED controller

(* synthesize *)
(* execution_order = "setPeriod,setActivity" *)
module mkLEDController#(Bool invert)(LEDController);

   // The LED is controlled by a repeating bit pattern that attempts
   // to reproduce 8 evenly spaced (perceptually) LED intensities

   Reg#(Bit#(16)) pattern   <- mkReg('0);
   Wire#(Level)   new_level <- mkWire();

   function Bit#(16) pattern_for(Level lvl);
      Bit#(16) p = '0;
      case (lvl)
         0: p = 16'b0000_0000_0000_0000;
         1: p = 16'b0000_0001_0000_0001;
         2: p = 16'b0001_0001_0001_0001;
         3: p = 16'b0101_0101_0101_0101;
         4: p = 16'b0101_1011_0110_1101;
         5: p = 16'b1101_0101_1011_1011;
         6: p = 16'b1111_0111_1011_1110;
         7: p = 16'b1111_1111_1111_1111;
      endcase
      return p;
   endfunction

   rule new_pattern;
      pattern <= pattern_for(new_level);
   endrule

   (* preempts = "new_pattern, rotate_pattern" *)
   rule rotate_pattern;
      pattern <= {pattern[0],pattern[15:1]};
   endrule

   // We want to tick once every ms or so
   // (assumes a 50 to 100 MHz clock / 2^16)
   Reg#(UInt#(16)) counter <- mkReg(0);
   Bool tick = (counter == 0);

   (* fire_when_enabled, no_implicit_conditions *)
   rule incr_counter;
      counter <= counter + 1;
   endrule

   // There is always a current LED level and a target level
   Reg#(Level) current_level <- mkReg(0);
   Reg#(Level) target_level  <- mkReg(0);

   // On each tick, the current level moves closer to the target
   // at a speed determined by the lag (0 == fast, 15 == slow)
   Reg#(Lag)      lag         <- mkReg(3);
   Reg#(UInt#(8)) lag_counter <- mkReg(0);
   Reg#(Bool) update_req      <- mkReg(False);
   Bool do_level_update = tick && (update_req || lag_counter == 0);

   (* fire_when_enabled, no_implicit_conditions *)
   rule count_down_lag if (tick);
      if (lag_counter == 0)
         lag_counter <= extend(lag) * 16;
      else
         lag_counter <= lag_counter - 1;
   endrule

   function Level adjustment(Level diff);
      Level l = 0;
      case (diff)
         7: l = 3;
         6: l = 3;
         5: l = 2;
         4: l = 2;
         3: l = 1;
         2: l = 1;
         1: l = 1;
         0: l = 0;
      endcase
      return l;
   endfunction

   (* fire_when_enabled, no_implicit_conditions *)
   rule update_level if (do_level_update && (current_level != target_level));
      Level l;
      if (target_level > current_level)
         l = current_level + adjustment(target_level - current_level);
      else
         l = current_level - adjustment(current_level - target_level);
      current_level <= l;
      new_level <= l;
      update_req <= False;
   endrule

   // There are two modes -- a periodic mode and an activity mode
   Reg#(Bool) activity_mode <- mkReg(False);

   // In the periodic mode, alternate between levels at controlled
   // intervals
   Reg#(Level) lo     <- mkReg(0);
   Reg#(Level) hi     <- mkReg(0);
   Reg#(Time)  lo_for <- mkReg(500);
   Reg#(Time)  hi_for <- mkReg(500);

   Reg#(Time) countdown <- mkReg(0);

   (* no_implicit_conditions *)
   rule do_periodic if (!activity_mode && tick);
      if (countdown == 0) begin
         if (target_level == lo) begin
            target_level <= hi;
            countdown <= hi_for;
         end
         else begin
            target_level <= lo;
            countdown <= lo_for;
         end
      end
      else begin
         countdown <= countdown - 1;
      end
   endrule

   // In the activity mode, each bump sets the target level to
   // led_on_max and will keep it on for a controlled amount of time.
   Reg#(Time) activity_time <- mkReg(1);
   Reg#(Time) remaining     <- mkReg(0);

   (* no_implicit_conditions *)
   rule do_activity if (activity_mode && tick && (target_level != 0));
      if (remaining == 0)
         target_level <= 0;
      else
         remaining <= remaining - 1;
   endrule

   CrossingReg#(Bit#(1)) _out <- mkNullCrossingReg(noClock, 0);

   (* fire_when_enabled, no_implicit_conditions *)
   rule update_output;
      _out <= invert ? ~pattern[0] : pattern[0];
   endrule

   method Action setLag(Lag l);
      lag <= l;
   endmethod

   method Action setPeriod(Level lo_lvl, Time lo_time,
                           Level hi_lvl, Time hi_time);
      lo            <= lo_lvl;
      hi            <= hi_lvl;
      lo_for        <= lo_time;
      hi_for        <= hi_time;
      activity_mode <= False;
   endmethod

   method Action setActivity(Time on_time);
      activity_mode <= True;
      activity_time <= on_time;
   endmethod

   method Action bump();
      target_level <= led_on_max;
      remaining    <= activity_time;
      update_req   <= True;
   endmethod: bump

   interface LED ifc;
      method Bit#(1) out = _out.crossed();
   endinterface

endmodule

// A utility function to create a unified LED interface
function LED#(n) combineLEDs(Vector#(n,LEDController) ctrls);

   function Bit#(1) getLED(LEDController ctrl);
      return ctrl.ifc.out();
   endfunction: getLED

   return (interface LED#(n);
              method Bit#(n) out();
                 return pack(map(getLED,ctrls));
              endmethod
           endinterface);
endfunction: combineLEDs

// A utility function to create an LED interface from bits
function LED#(n) bitsToLED(Bit#(n) in);
   return (interface LED#(n);
              method Bit#(n) out();
                 return in;
              endmethod
           endinterface);
endfunction: bitsToLED

endpackage: LEDController
