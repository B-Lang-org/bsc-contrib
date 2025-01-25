// Copyright (c) 2025 Bluespec, Inc.
//
// SPDX-License-Identifier: BSD-3-Clause

package VectorFIFOF;

// This package implements a fifo like module with a parameterized
// depth and standard FIFOF interface.  The module also provides
// parallel access to all items in the fifo, for example, to allow
// searching for hazards before enqueueing new items.
//
// The enq, deq, and clear methods may be called in any order.  enq
// and deq may not occur in the same cycle if the fifo is empty or
// full.

import FIFOF ::*;
import RevertingVirtualReg ::*;
import Vector ::*;

interface VectorFIFOF#(numeric type depth, type t);
   interface FIFOF#(t) fifo;
   method Vector#(depth, Maybe#(t)) vector();
endinterface

module mkVectorFIFOF(VectorFIFOF#(depth, t))
   provisos(
      Bits#(t, tsz)
      );

   Vector#(depth, Reg#(t)) vr_data <- replicateM(mkRegU);
   Reg#(UInt#(TLog#(TAdd#(depth,1)))) r_count <- mkReg(0);

   RWire#(t) w_enq <- mkRWire;
   PulseWire pw_deq <- mkPulseWire;
   PulseWire pw_clear <- mkPulseWire;

   (* fire_when_enabled, no_implicit_conditions *)
   rule rl_magic;
      if (pw_clear)
	 r_count <= 0;
      else if (isValid(w_enq.wget) && !pw_deq)
	 r_count <= r_count + 1;
      else if (!isValid(w_enq.wget) && pw_deq)
	 r_count <= r_count - 1;

      Vector#(depth, t) newdata = readVReg(vr_data);

      if (pw_deq)
	 for (Integer i = 0; i < fromInteger(valueOf(depth)) - 1; i = i + 1)
	    newdata[i] = newdata[i + 1];

      if (w_enq.wget matches tagged Valid .x)
	 newdata[pw_deq ? r_count - 1 : r_count] = x;

      writeVReg(vr_data, newdata);
   endrule

   function Bool notFull;
      return r_count < fromInteger(valueOf(depth));
   endfunction

   function Bool notEmpty;
      return r_count != 0;
   endfunction

   function Maybe#(t) valid(Integer x, t a);
      if (fromInteger(x) < r_count)
	 return tagged Valid a;
      else
	 return tagged Invalid;
   endfunction

   Reg#(Bool) beforeEnq <- mkRevertingVirtualReg(True);
   Reg#(Bool) beforeDeq <- mkRevertingVirtualReg(True);
   Reg#(Bool) beforeClear <- mkRevertingVirtualReg(True);

   Bool beforeActions = beforeEnq && beforeDeq && beforeClear;

   interface FIFOF fifo;
      method Action enq(t x) if (notFull && beforeClear);
        w_enq.wset(x);
        beforeEnq <= False;
      endmethod
      method Action deq if (notEmpty && beforeClear);
        pw_deq.send;
        beforeDeq <= False;
      endmethod
      method t first if (beforeDeq && beforeClear && (r_count > 0)) = vr_data[0];
      method Action clear();
        pw_clear.send;
        beforeClear <= False;
      endmethod
      method Bool notFull() if (beforeActions) = notFull;
      method Bool notEmpty() if (beforeActions) = notEmpty;
   endinterface

   method vector() if (beforeActions) = zipWith(valid, genVector, readVReg(vr_data));

endmodule

endpackage
