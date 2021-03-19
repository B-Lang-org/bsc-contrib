// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package TLMReduce;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import SpecialFIFOs::*;
import FIFO::*;
import GetPut::*;
import TLMDefines::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
/// Convert a stream of (arbitrary) TLM ops into a stream with only single
/// reads and single writes.
////////////////////////////////////////////////////////////////////////////////

module mkTLMReducer (TLMTransformIFC#(`TLM_TYPES))
   provisos(Bits#(TLMRequest#(`TLM_TYPES), s0),
	    Bits#(TLMResponse#(`TLM_TYPES), s1),
   	    Bits#(RequestDescriptor#(`TLM_TYPES), s2));

   Reg#(RequestDescriptor#(`TLM_TYPES)) desc_reg <- mkReg(?);
   Reg#(TLMUInt#(`TLM_TYPES))           count    <- mkReg(0);

   FIFO#(TLMResponse#(`TLM_TYPES))       fifo_in_tx  <- mkBypassFIFO;
   FIFO#(TLMRequest#(`TLM_TYPES))        fifo_in_rx  <- mkBypassFIFO;
   FIFO#(TLMRequest#(`TLM_TYPES))        fifo_out_tx <- mkBypassFIFO;
   FIFO#(TLMResponse#(`TLM_TYPES))       fifo_out_rx <- mkBypassFIFO;

   rule read_op_first (fifo_in_rx.first matches tagged Descriptor .d
		       &&& d.command matches READ
		       &&& (count == 0));
      let desc_current = d;
      desc_current.burst_length = 1;
      fifo_out_tx.enq(tagged Descriptor desc_current);
      desc_reg <= incrTLMAddr(desc_current);

      let remaining = d.burst_length - 1;
      count <= remaining;
      if (remaining == 0) fifo_in_rx.deq;
   endrule

   rule read_op_rest (fifo_in_rx.first matches tagged Descriptor .d
		      &&& d.command matches READ
		      &&& (count > 0));
      fifo_out_tx.enq(tagged Descriptor desc_reg);
      desc_reg <= incrTLMAddr(desc_reg);

      let remaining = count - 1;
      count <= remaining;
      if (remaining == 0) fifo_in_rx.deq;
   endrule

   rule write_op_first (fifo_in_rx.first matches tagged Descriptor .d
			&&& d.command matches WRITE);
      let desc_current = d;
      desc_current.burst_length = 1;
      fifo_out_tx.enq(tagged Descriptor desc_current);
      desc_reg <= incrTLMAddr(desc_current);

      fifo_in_rx.deq;
   endrule

   rule write_op_rest (fifo_in_rx.first matches tagged Data .d);
      let desc_current = desc_reg;
      desc_current.data = d.data;
      fifo_out_tx.enq(tagged Descriptor desc_current);
      desc_reg <= incrTLMAddr(desc_reg);

      fifo_in_rx.deq;
   endrule

   // for now just pass on responses
   rule pass_on_responses;
      let response = fifo_out_rx.first;
      fifo_in_tx.enq(response);
      fifo_out_rx.deq;
   endrule

   interface TLMRecvIFC in;
      interface Get tx = toGet(fifo_in_tx);
      interface Put rx = toPut(fifo_in_rx);
   endinterface

   interface TLMSendIFC out;
      interface Get tx = toGet(fifo_out_tx);
      interface Put rx = toPut(fifo_out_rx);
   endinterface

endmodule


endpackage
