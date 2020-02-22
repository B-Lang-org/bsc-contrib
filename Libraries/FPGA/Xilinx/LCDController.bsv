// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package LCDController;

// This is an LCD controller for the 16x2 LCD module that comes with
// Xilinx evaluation boards.  They are Displaytech S162D LCDs and they
// use the Samsung KS0070B display driver chip in a 4-bit bus
// configuration.

import Clocks      :: *;
import Vector      :: *;
import StmtFSM     :: *;
import DummyDriver :: *;

// This is the interface that goes out of the FPGA to the display
// controller
interface LCD;
   (* always_ready *)
   method Bit#(4) db;   // 4-bit tristate bus
   (* always_ready *)
   method Bit#(1) e();  // enable
   (* always_ready *)
   method Bit#(1) rs(); // register select
   (* always_ready *)
   method Bit#(1) rw(); // read-not-write
endinterface: LCD

// This is the full LCD controller interface
interface LCDController;
   // Set the top line of the LCD text
   (* always_ready *)
   method Action setLine1(Vector#(16,Bit#(8)) text);
   // Set the bottom line of the LCD text
   (* always_ready *)
   method Action setLine2(Vector#(16,Bit#(8)) text);
   // The interface for connecting to the FPGA pins
   (* prefix = "" *)
   interface LCD ifc;
endinterface

(* synthesize *)
module mkLCDController(LCDController);

   // Buffer of display contents
   Reg#(Vector#(16,Bit#(8))) line1       <- mkRegU();
   Reg#(Bool)                line1_dirty <- mkReg(False);
   Reg#(Vector#(16,Bit#(8))) line2       <- mkRegU();
   Reg#(Bool)                line2_dirty <- mkReg(False);

   // The KS0070B controller interface has specific setup and hold
   // time constraints that we must match.  This implementation
   // assumes that the default module clock is no faster than 100 MHz!

   function UInt#(sz) count_of(Integer n);
      return fromInteger(n/10);
   endfunction

   // Values in ns, based on Displaytech documentation
   Integer rw_rs_setup       = 40;
   Integer e_pulse_width     = 220;
   Integer e_cycle_time      = 500;
   Integer data_hold_time    = 30;  // 20
   Integer data_setup_time   = 150; // 80

   // Counter to pace waveform transitions
   Reg#(UInt#(8)) counter    <- mkReg(0);
   Bool rise_e      = counter == count_of(rw_rs_setup);
   Bool fall_e      = counter == count_of(rw_rs_setup + e_pulse_width);
   Bool finished    = counter == count_of(rw_rs_setup + e_cycle_time);

   Reg#(Bool) active <- mkReg(False);

   // Bus drivers
   CrossingReg#(Bit#(1))  rs_reg   <- mkNullCrossingReg(noClock, 0);
   CrossingReg#(Bit#(1))  e_reg    <- mkNullCrossingReg(noClock, 0);
   CrossingReg#(Bit#(4))  data_reg <- mkNullCrossingReg(noClock, 0);

   (* fire_when_enabled, no_implicit_conditions *)
   rule manage_bus if (active);
      if (rise_e)
         e_reg <= 1;
      else if (fall_e)
         e_reg <= 0;
      if (finished)
         active <= False;
      else
         counter <= counter + 1;
   endrule

   // Perform a write of one nibble

   function Stmt do_half_write(Bit#(1) rs, Bit#(4) x);
      return seq
                 await(!active);
                 action
                    rs_reg   <= rs;
                    data_reg <= x;
                    active   <= True;
                    counter  <= 0;
                 endaction
                 await(!active);
             endseq;
   endfunction

   // We need to be able to ensure minimum delays between
   // operations

   Reg#(UInt#(24)) countdown <- mkReg(0);
   Bool time_is_up = (countdown == 0);

   rule decr if (!time_is_up);
      countdown <= countdown - 1;
   endrule

   function Stmt wait_time(Integer t);
      return seq
                 countdown <= count_of(t);
                 await(time_is_up);
             endseq;
   endfunction

   // To perform a full write, we write both nibbles
   // with an appropriate delay between them

   Integer cmd_delay  = 5000000; // 5 ms
   Integer data_delay = 200000;  // 200 us

   Reg#(Bit#(1)) rs_val   <- mkRegU();
   Reg#(Bit#(8)) data_val <- mkRegU();

   FSM do_write_fsm <- mkFSM(seq
                                do_half_write(rs_val, truncate(data_val >> 4));  // upper
                                wait_time(rs_val == 1 ? data_delay : cmd_delay);
                                do_half_write(rs_val, truncate(data_val));       // lower
                                wait_time(rs_val == 1 ? data_delay : cmd_delay);
                             endseq);

   function Stmt do_write(Bit#(1) rs, Bit#(8) x);
      return seq
                 action
                    rs_val   <= rs;
                    data_val <= x;
                 endaction
                 do_write_fsm.start();
                 await(do_write_fsm.done());
             endseq;
   endfunction

   // There is some initialization to do after reset, and it requires
   // some fixed, long delays

   Integer initial_wait_time = 30000000; // 30 ms
   Integer lcd_setup_time1   = 5000000;  // 5 ms
   Integer lcd_setup_time2   = 200000;   // 200 us

   Reg#(Bool)     initialized <- mkReg(False);
   Reg#(UInt#(4)) row         <- mkRegU();

   Stmt initialization_sequence = seq
                                      // LCD controller setup
                                      wait_time(initial_wait_time);
                                      do_half_write(0, 4'b0011); // LCD 4-bit setup
                                      wait_time(lcd_setup_time1);
                                      do_half_write(0, 4'b0011); // LCD 4-bit setup
                                      wait_time(lcd_setup_time2);
                                      do_half_write(0, 4'b0011); // LCD 4-bit setup
                                      wait_time(lcd_setup_time2);
                                      do_half_write(0, 4'b0010); // LCD 4-bit setup
                                      wait_time(lcd_setup_time1);
                                      // function set
                                      do_write(0, 8'b0010_1000); // 4-bit mode, 2-line, 5x7
                                      // display / cursor setup
                                      do_write(0, 8'b0000_1000); // no shift, no cursor
                                      // clear display
                                      do_write(0, 8'b0000_0001);
                                      // entry mode set
                                      do_write(0, 8'b0000_0110); // increment, no shift
                                      // turn on display
                                      do_write(0, 8'b0000_1100); // no cursor or blinking
                                      // program custom characters
                                      do_write(0, 8'b0100_0000); // set CG RAM addr = 0
                                      // one column set
                                      for (row <= 0; row < 8; row <= row + 1)
                                         do_write(1, 8'b0001_0000);
                                      // two columns set
                                      for (row <= 0; row < 8; row <= row + 1)
                                         do_write(1, 8'b0001_1000);
                                      // three columns set
                                      for (row <= 0; row < 8; row <= row + 1)
                                         do_write(1, 8'b0001_1100);
                                      // four columns set
                                      for (row <= 0; row < 8; row <= row + 1)
                                         do_write(1, 8'b0001_1110);
                                      // all five columns set
                                      for (row <= 0; row < 8; row <= row + 1)
                                         do_write(1, 8'b0001_1111);
                                      // Bluespec logo
                                      // tail part
                                      do_write(1, 8'b0000_1101);
                                      do_write(1, 8'b0001_1011);
                                      do_write(1, 8'b0000_0111);
                                      do_write(1, 8'b0001_1010);
                                      do_write(1, 8'b0001_0101);
                                      do_write(1, 8'b0000_1111);
                                      do_write(1, 8'b0001_0110);
                                      do_write(1, 8'b0000_1011);
                                      // upper wafer
                                      do_write(1, 8'b0001_1000);
                                      do_write(1, 8'b0000_1100);
                                      do_write(1, 8'b0001_1110);
                                      do_write(1, 8'b0001_0110);
                                      do_write(1, 8'b0000_1110);
                                      do_write(1, 8'b0001_1011);
                                      do_write(1, 8'b0001_0111);
                                      do_write(1, 8'b0000_1101);
                                      // lower wafer
                                      do_write(1, 8'b0001_0111);
                                      do_write(1, 8'b0001_1111);
                                      do_write(1, 8'b0000_1011);
                                      do_write(1, 8'b0001_1110);
                                      do_write(1, 8'b0001_0110);
                                      do_write(1, 8'b0000_1110);
                                      do_write(1, 8'b0001_0100);
                                      do_write(1, 8'b0001_1000);
                                      // record that initialization finished
                                      initialized <= True;
                                  endseq;

   FSM init_fsm <- mkFSMWithPred(initialization_sequence,!initialized);

   rule do_init if (!initialized);
      init_fsm.start();
   endrule

   // Line display

   Reg#(UInt#(2)) active_line <- mkReg(0);
   Reg#(UInt#(5)) idx         <- mkRegU();

   Stmt write_line1 = seq
                          // set address to start of line 1
                          do_write(0, {1'b1,7'h00});
                          // write each character
                          for (idx <= 0; idx < 16; idx <= idx + 1) seq
                             do_write(1, line1[idx]);
                          endseq
                          action
                             line1_dirty <= False;
                             active_line <= 0;
                          endaction
                      endseq;

   FSM line1_fsm <- mkFSMWithPred(write_line1, initialized && (active_line == 1));

   rule display_line1 if (initialized && line1_dirty && (active_line == 0));
      active_line <= 1;
      line1_fsm.start();
   endrule

   Stmt write_line2 = seq
                          // set address to start of line 2
                          do_write(0, {1'b1,7'h40});
                          // write each character
                          for (idx <= 0; idx < 16; idx <= idx + 1) seq
                             do_write(1, line2[idx]);
                          endseq
                          action
                             line2_dirty <= False;
                             active_line <= 0;
                          endaction
                      endseq;

   FSM line2_fsm <- mkFSMWithPred(write_line2, initialized && (active_line == 2));

   rule display_line2 if (initialized && !line1_dirty && line2_dirty && (active_line == 0));
      active_line <= 2;
      line2_fsm.start();
   endrule

   // interface

   method Action setLine1(Vector#(16,Bit#(8)) text);
      line1       <= text;
      line1_dirty <= True;
   endmethod

   method Action setLine2(Vector#(16,Bit#(8)) text);
      line2       <= text;
      line2_dirty <= True;
   endmethod

   interface LCD ifc;
      method db = data_reg.crossed();
      method e  = e_reg.crossed();
      method rs = rs_reg.crossed();
      method rw = 1'b0;  // we only do writes
   endinterface

endmodule

// Utility for generating padding for the LCD
function Vector#(n,Bit#(8)) lcdPad();
   return replicate(8'h20);
endfunction

// Utility for generating LCD text from a String
function Vector#(16,Bit#(8)) lcdLine(String s);
   Integer n = primStringToInteger(s);
   Integer l = stringLength(s) - 1;
   Vector#(16,Bit#(8)) text;
   for (Integer i = 0; i < 16; i = i + 1) begin
      Bit#(8) ch = fromInteger(n % 256);
      n = n / 256;
      if (ch == 0)
         text[i] = 8'h20; // blank space
      else
         text[l-i] = ch;
   end
   return text;
endfunction

// Utility for generating an amplitude/progress meter
// based on a value from 0 to 63
function Vector#(13,Bit#(8)) lcdBar(UInt#(6) x);
   Vector#(13,Bit#(8)) text;
   Bit#(8) ch;
   for (Integer i = 0; i < 12; i = i + 1) begin
      if      (x <= fromInteger(5*i))     ch = 8'h20;
      else if (x == fromInteger(5*i + 1)) ch = 8'h00;
      else if (x == fromInteger(5*i + 2)) ch = 8'h01;
      else if (x == fromInteger(5*i + 3)) ch = 8'h02;
      else if (x == fromInteger(5*i + 4)) ch = 8'h03;
      else                                ch = 8'h04;
      text[i] = ch;
   end
   if      (x <= 60) ch = 8'h20;
   else if (x == 61) ch = 8'h00;
   else if (x == 62) ch = 8'h01;
   else              ch = 8'h02;
   text[12] = ch;
   return text;
endfunction

// Utility for generating the Bluespec logo
function Vector#(2,Bit#(8)) lcdLogoTop();
   return cons(8'h05, cons(8'h06, nil));
endfunction

function Vector#(2,Bit#(8)) lcdLogoBottom();
   return cons(8'h05, cons(8'h07, nil));
endfunction


// A DummyDriver instance for when you don't want to
// use the LCD display

instance DummyDriver#(LCD);
   module mkStub(LCD);
      method db = 4'b0000;
      method e  = 1'b0;
      method rs = 1'b0;
      method rw = 1'b1;
   endmodule
endinstance

endpackage: LCDController
