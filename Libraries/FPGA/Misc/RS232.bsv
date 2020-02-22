////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : RS232.bsv
//  Description   : Simple UART BFM   RS232 <-> Bit#(8)
////////////////////////////////////////////////////////////////////////////////
package RS232;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import Clocks            ::*;
import GetPut            ::*;
import Connectable       ::*;
import FIFOLevel         ::*;
import Vector            ::*;
import BUtils            ::*;
import Counter           ::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////
export RS232             (..);
export UART              (..);
export BaudGenerator     (..);
export Parity            (..);
export StopBits          (..);
export InputFilter       (..);
export Synchronizer      (..);
export EdgeDetector      (..);
export InputMovingFilter (..);
export mkUART;
export mkBaudGenerator;
export mkInputFilter;
export mkSynchronizer;
export mkEdgeDetector;
export mkInputMovingFilter;

////////////////////////////////////////////////////////////////////////////////
/// Types
////////////////////////////////////////////////////////////////////////////////
typedef union tagged {
   void Start;
   void Center;
   void Wait;
   void Sample;
   void Parity;
   void StopFirst;
   void StopLast;
   } RecvState deriving (Bits, Eq);

typedef union tagged {
   void Idle;
   void Start;
   void Wait;
   void Shift;
   void Stop;
   void Stop5;
   void Stop2;
   void Parity;
   } XmitState deriving (Bits, Eq);

typedef enum {
   NONE,
   ODD,
   EVEN
   } Parity deriving (Bits, Eq);

typedef enum {
   STOP_1,
   STOP_1_5,
   STOP_2
   } StopBits deriving (Bits, Eq);

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
(* always_ready, always_enabled *)
interface RS232;
   // Inputs
   (* prefix = "" *)
   method    Action      sin((* port = "SIN" *)Bit#(1) x);
   // Outputs
   (* prefix = "", result = "SOUT" *)
   method    Bit#(1)     sout();
endinterface

interface BaudGenerator;
   method    Action    clock_enable();
   method    Action    clear();
   method    Bool      baud_tick_16x();
   method    Bool      baud_tick_2x();
endinterface

interface InputFilter#(numeric type size, type a);
   method    Action    clock_enable();
   method    a         _read();
endinterface

(* always_ready, always_enabled *)
interface EdgeDetector#(type a);
   method    Bool      rising();
   method    Bool      falling();
endinterface

(* always_ready, always_enabled *)
interface Synchronizer#(type a);
   method    Action    _write(a x);
   method    a         _read();
endinterface

interface InputMovingFilter#(numeric type width, numeric type threshold, type a);
   method    Action    sample();
   method    Action    clear();
   method    a         _read();
endinterface

interface UART#(numeric type depth);
   (* prefix = "" *)
   interface RS232           rs232;
   interface Get#(Bit#(8))   tx;
   interface Put#(Bit#(8))   rx;
endinterface


////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation of Baud Generator
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkBaudGenerator#(Bit#(16) divider)(BaudGenerator);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Counter#(16)                              rBaudCounter        <- mkCounter(0);
   PulseWire                                 pwBaudTick16x       <- mkPulseWire;

   Counter#(3)                               rBaudTickCounter    <- mkCounter(0);
   PulseWire                                 pwBaudTick2x        <- mkPulseWire;

   Wire#(Bit#(16))                           wBaudCount          <- mkWire;
   rule baud_count_wire;
      wBaudCount <= rBaudCounter.value;
   endrule
   Wire#(Bit#(3))                            wBaudTickCount      <- mkWire;
   rule baud_tick_count_wire;
      wBaudTickCount <= rBaudTickCounter.value;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   rule count_baudtick_16x(pwBaudTick16x);
      rBaudTickCounter.up;
   endrule

   rule assert_2x_baud_tick(rBaudTickCounter.value() == 0 && pwBaudTick16x);
      pwBaudTick2x.send;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   method Action clock_enable();
      if (rBaudCounter.value() + 1 >= divider) begin
         pwBaudTick16x.send;
         rBaudCounter.clear;
      end
      else begin
         rBaudCounter.up;
      end
   endmethod

   method Action clear();
      rBaudCounter.clear;
   endmethod

   method Bool baud_tick_16x();
      return pwBaudTick16x;
   endmethod

   method Bool baud_tick_2x();
      return pwBaudTick2x;
   endmethod

endmodule: mkBaudGenerator

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation of Input Filter
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkInputFilter#(a initval, a din)(InputFilter#(size, a))
   provisos( Bits#(a, sa)
           , Eq#(a)
           , Add#(0, sa, 1)
           , Log#(size, logsize)
           , Add#(logsize, 1, csize)
           );

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Counter#(csize)                           counter             <- mkCounter(0);
   Reg#(a)                                   rOut                <- mkReg(initval);

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   method Action clock_enable();
      if (din == unpack(1) && counter.value() != fromInteger(valueof(size)))
         counter.up;
      else if (din == unpack(0) && counter.value() != 0)
         counter.down;

      if (counter.value() == fromInteger(valueof(size)))
         rOut <= unpack(1);
      else if (counter.value() == 0)
         rOut <= unpack(0);
   endmethod

   method a _read;
      return rOut;
   endmethod

endmodule


////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkEdgeDetector#(a initval, a din)(EdgeDetector#(a))
   provisos( Bits#(a, sa)
           , Eq#(a)
           , Add#(0, sa, 1)
           );

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Reg#(a)                                   rDinD1              <- mkReg(initval);

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* fire_when_enabled *)
   (* no_implicit_conditions *)
   rule pipeline;
      rDinD1 <= din;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   method Bool rising();
      return (din == unpack(1) && rDinD1 == unpack(0));
   endmethod

   method Bool falling();
      return (din == unpack(0) && rDinD1 == unpack(1));
   endmethod

endmodule: mkEdgeDetector

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////
function Bool getRising(EdgeDetector#(a) ifc);
   return ifc.rising;
endfunction

function Bool getFalling(EdgeDetector#(a) ifc);
   return ifc.falling;
endfunction

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation of Synchronizer
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkSynchronizer#(a initval)(Synchronizer#(a))
   provisos( Bits#(a, sa)
           , Add#(0, sa, 1)
           );

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Reg#(a)                                   d1                  <- mkReg(initval);
   Reg#(a)                                   d2                  <- mkReg(initval);

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   method Action _write(x);
      d1 <= x;
      d2 <= d1;
   endmethod

   method a _read();
      return d2;
   endmethod

endmodule: mkSynchronizer

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation of Input Filter
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkInputMovingFilter#(a din)(InputMovingFilter#(width, threshold, a))
   provisos( Bits#(a, sa)
           , Eq#(a)
           , Add#(0, sa, 1)
           );

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Counter#(width)                           counter             <- mkCounter(0);
   Reg#(a)                                   rOut                <- mkReg(unpack(0));
   PulseWire                                 pwSample            <- mkPulseWire;

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* preempts = "threshold_compare, take_sample" *)
   rule threshold_compare(counter.value() >= fromInteger(valueof(threshold)));
      rOut <= unpack(1);
   endrule

   rule take_sample(pwSample && din == unpack(1));
      counter.up;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   method Action sample();
      pwSample.send;
   endmethod

   method Action clear();
      counter.clear();
      rOut <= unpack(0);
   endmethod

   method a _read;
      return rOut;
   endmethod

endmodule


////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation of UART
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkUART( Bit#(4) charsize
             , Parity paritysel
             , StopBits stopbits
             , Bit#(16) divider
             , UART#(d) ifc)
   provisos(Add#(2, _1, d));

   Integer fifodepth = valueof(d);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   let                                       baudGen               <- mkBaudGenerator( divider );

   ////////////////////////////////////////////////////////////////////////////////
   /// Receive UART
   ////////////////////////////////////////////////////////////////////////////////
   FIFOLevelIfc#(Bit#(8), d)                 fifoRecv              <- mkGFIFOLevel(True, False, True);

   Vector#(8, Reg#(Bit#(1)))                 vrRecvBuffer          <- replicateM(mkRegU);

   Reg#(Bit#(1))                             rRecvData             <- mkReg(1);

   Reg#(RecvState)                           rRecvState            <- mkRegA(Start);
   Reg#(Bit#(4))                             rRecvCellCount        <- mkRegA(0);
   Reg#(Bit#(4))                             rRecvBitCount         <- mkRegA(0);
   Reg#(Bit#(1))                             rRecvParity           <- mkRegA(0);

   PulseWire                                 pwRecvShiftBuffer     <- mkPulseWire;
   PulseWire                                 pwRecvCellCountReset  <- mkPulseWire;
   PulseWire                                 pwRecvResetBitCount   <- mkPulseWire;
   PulseWire                                 pwRecvEnableBitCount  <- mkPulseWire;

   ////////////////////////////////////////////////////////////////////////////////
   /// Transmit UART
   ////////////////////////////////////////////////////////////////////////////////
   FIFOLevelIfc#(Bit#(8), d)                 fifoXmit              <- mkGFIFOLevel(False, False, True);

   Vector#(8, Reg#(Bit#(1)))                 vrXmitBuffer          <- replicateM(mkRegU);

   Reg#(XmitState)                           rXmitState            <- mkRegA(Idle);
   Reg#(Bit#(4))                             rXmitCellCount        <- mkRegA(0);
   Reg#(Bit#(4))                             rXmitBitCount         <- mkRegA(0);
   Reg#(Bit#(1))                             rXmitDataOut          <- mkRegA(1);
   Reg#(Bit#(1))                             rXmitParity           <- mkRegA(0);

   PulseWire                                 pwXmitCellCountReset  <- mkPulseWire;
   PulseWire                                 pwXmitResetBitCount   <- mkPulseWire;
   PulseWire                                 pwXmitEnableBitCount  <- mkPulseWire;
   PulseWire                                 pwXmitLoadBuffer      <- mkPulseWire;
   PulseWire                                 pwXmitShiftBuffer     <- mkPulseWire;

   ////////////////////////////////////////////////////////////////////////////////
   /// Definitions
   ////////////////////////////////////////////////////////////////////////////////
   let tick               = baudGen.baud_tick_16x;

   ////////////////////////////////////////////////////////////////////////////////
   /// Baud Clock Enable
   ////////////////////////////////////////////////////////////////////////////////
   (* no_implicit_conditions, fire_when_enabled *)
   rule baud_generator_clock_enable;
      baudGen.clock_enable;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Receive Rules
   ////////////////////////////////////////////////////////////////////////////////
   rule receive_bit_cell_time_counter(tick);
      if (pwRecvCellCountReset)
         rRecvCellCount <= 0;
      else
         rRecvCellCount <= rRecvCellCount + 1;
   endrule

   rule receive_buffer_shift(pwRecvShiftBuffer);
      let v = shiftInAtN(readVReg(vrRecvBuffer), rRecvData);
      writeVReg(vrRecvBuffer, v);
   endrule

   rule receive_bit_counter;
      if (pwRecvResetBitCount)
         rRecvBitCount <= 0;
      else if (pwRecvEnableBitCount)
         rRecvBitCount <= rRecvBitCount + 1;
   endrule

   rule receive_wait_for_start_bit(rRecvState == Start && tick);
      pwRecvCellCountReset.send();
      if (rRecvData == 1'b0) begin
         rRecvState <= Center;
      end
      else begin
         rRecvState <= Start;
         pwRecvResetBitCount.send();
      end
   endrule

   rule receive_find_center_of_bit_cell(rRecvState == Center && tick);
      if (rRecvCellCount == 4'h4) begin
         pwRecvCellCountReset.send();
         if (rRecvData == 1'b0)
            rRecvState <= Wait;
         else
            rRecvState <= Start;
      end
      else begin
         rRecvState <= Center;
      end
   endrule

   rule receive_wait_bit_cell_time_for_sample(rRecvState == Wait && rRecvCellCount == 4'hF && tick);
      pwRecvCellCountReset.send;

      if (rRecvBitCount == charsize) begin
         if (paritysel != NONE)
            rRecvState <= Parity;
         else if (stopbits != STOP_1)
            rRecvState <= StopFirst;
         else
            rRecvState <= StopLast;
      end
      else if (rRecvBitCount == charsize + 1) begin
         if (paritysel == NONE || stopbits == STOP_1)
            rRecvState <= StopLast;
         else
            rRecvState <= StopFirst;
      end
      else if (rRecvBitCount == charsize + 2) begin
         rRecvState <= StopLast;
      end
      else begin
         rRecvState <= Sample;
      end
   endrule

   rule receive_sample_pin(rRecvState == Sample && tick);
      pwRecvShiftBuffer.send;
      pwRecvEnableBitCount.send;
      pwRecvCellCountReset.send;
      rRecvState <= Wait;
   endrule

   rule receive_parity_bit(rRecvState == Parity && tick);
      rRecvParity <= rRecvData;
      pwRecvEnableBitCount.send;
      pwRecvCellCountReset.send;
      rRecvState <= Wait;
   endrule

   rule receive_stop_first_bit(rRecvState == StopFirst && tick);
      pwRecvEnableBitCount.send;
      pwRecvCellCountReset.send;
      if (rRecvData == 1)
         rRecvState <= Wait;
      else
         rRecvState <= Start;
   endrule

   rule receive_stop_last_bit(rRecvState == StopLast && tick);
      Vector#(8, Bit#(1)) data = take(readVReg(vrRecvBuffer));
      Bit#(8)          bitdata = pack(data) >> (8 - charsize);

      fifoRecv.enq(bitdata);
      rRecvState <= Start;
      pwRecvCellCountReset.send;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Transmit Rules
   ////////////////////////////////////////////////////////////////////////////////
   rule transmit_bit_cell_time_counter(tick);
      if (pwXmitCellCountReset)
         rXmitCellCount <= 0;
      else
         rXmitCellCount <= rXmitCellCount + 1;
   endrule

   rule transmit_bit_counter;
      if (pwXmitResetBitCount)
         rXmitBitCount <= 0;
      else if (pwXmitEnableBitCount)
         rXmitBitCount <= rXmitBitCount + 1;
   endrule

   rule transmit_buffer_load(pwXmitLoadBuffer);
      Bit#(8) data = pack(fifoXmit.first);
      fifoXmit.deq;

      writeVReg(vrXmitBuffer, unpack(data));
      rXmitParity <= parity(data);
   endrule

   rule transmit_buffer_shift(!pwXmitLoadBuffer && pwXmitShiftBuffer);
      let v = shiftInAtN(readVReg(vrXmitBuffer), 1);
      writeVReg(vrXmitBuffer, v);
   endrule

   rule transmit_wait_for_start_command(rXmitState == Idle && tick);
      rXmitDataOut <= 1'b1;
      pwXmitResetBitCount.send;
      if (fifoXmit.notEmpty) begin
         pwXmitCellCountReset.send;
         pwXmitLoadBuffer.send;
         rXmitState <= Start;
      end
      else begin
         rXmitState <= Idle;
      end
   endrule

   rule transmit_send_start_bit(rXmitState == Start && tick);
      rXmitDataOut <= 1'b0;
      if (rXmitCellCount == 4'hF) begin
         rXmitState <= Wait;
         pwXmitCellCountReset.send;
      end
      else begin
         rXmitState <= Start;
      end
   endrule

   rule transmit_wait_1_bit_cell_time(rXmitState == Wait && tick);
      rXmitDataOut <= head(readVReg(vrXmitBuffer));
      if (rXmitCellCount == 4'hF) begin
         pwXmitCellCountReset.send;
         if (rXmitBitCount == (charsize - 1) && (paritysel == NONE)) begin
            rXmitState <= Stop;
         end
         else if (rXmitBitCount == (charsize - 1) && (paritysel != NONE)) begin
            rXmitState <= Parity;
         end
         else begin
            rXmitState <= Shift;
            pwXmitEnableBitCount.send;
         end
      end
      else begin
         rXmitState <= Wait;
      end
   endrule

   rule transmit_shift_next_bit(rXmitState == Shift && tick);
      rXmitDataOut <= head(readVReg(vrXmitBuffer));
      rXmitState  <= Wait;
      pwXmitShiftBuffer.send;
   endrule

   rule transmit_send_parity_bit(rXmitState == Parity && tick);
      case(paritysel) matches
         ODD:        rXmitDataOut <= rXmitParity;
         EVEN:       rXmitDataOut <= ~rXmitParity;
         default:    rXmitDataOut <= 1'b0;
      endcase

      if (rXmitCellCount == 4'hF) begin
         rXmitState   <= Stop;
         pwXmitCellCountReset.send;
      end
      else begin
         rXmitState   <= Parity;
      end
   endrule

   rule transmit_send_stop_bit(rXmitState == Stop && tick);
      rXmitDataOut <= 1'b1;
      if (rXmitCellCount == 4'hF && (stopbits == STOP_1)) begin
         rXmitState <= Idle;
         pwXmitCellCountReset.send;
      end
      else if (rXmitCellCount == 4'hF && (stopbits == STOP_2)) begin
         rXmitState <= Stop2;
         pwXmitCellCountReset.send;
      end
      else if (rXmitCellCount == 4'hF && (stopbits == STOP_1_5)) begin
         rXmitState <= Stop5;
         pwXmitCellCountReset.send;
      end
      else begin
         rXmitState <= Stop;
      end
   endrule

   rule transmit_send_stop_bit1_5(rXmitState == Stop5 && tick);
      rXmitDataOut <= 1'b1;
      if (rXmitCellCount == 4'h7) begin
         rXmitState <= Idle;
         pwXmitCellCountReset.send;
      end
      else begin
         rXmitState <= Stop5;
      end
   endrule

   rule transmit_send_stop_bit2(rXmitState == Stop2 && tick);
      rXmitDataOut <= 1'b1;
      if (rXmitCellCount == 4'hF) begin
         rXmitState <= Idle;
         pwXmitCellCountReset.send;
      end
      else begin
         rXmitState <= Stop2;
      end
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface RS232 rs232;
      method sout    = rXmitDataOut;
      method sin     = rRecvData._write;
   endinterface

   interface Get tx;
      method ActionValue#(Bit#(8)) get;
         let data = pack(fifoRecv.first);
         fifoRecv.deq;
         return data;
      endmethod
   endinterface

   interface Put rx;
      method Action put(x);
         fifoXmit.enq(x);
      endmethod
   endinterface

endmodule


endpackage: RS232

