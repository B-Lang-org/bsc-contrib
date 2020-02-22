// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package TLM2Reduce;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import SpecialFIFOs::*;
import FIFO::*;
import GetPut::*;
import TLM2Defines::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
/// Convert a stream of (arbitrary) TLM ops into a stream with only single
/// reads and single writes.
////////////////////////////////////////////////////////////////////////////////

module mkTLMReducer (TLMTransformIFC#(req_t, resp_t))
   provisos(TLMRequestTC#(req_t, `TLM_PRM),
	    TLMResponseTC#(resp_t, `TLM_PRM),
	    Bits#(req_t, s0),
	    Bits#(resp_t, s1),
   	    Bits#(RequestDescriptor#(`TLM_PRM), s2));

   Reg#(RequestDescriptor#(`TLM_PRM)) desc_reg <- mkReg(?);
   Reg#(TLMUInt#(`TLM_PRM))           count    <- mkReg(0);

   FIFO#(resp_t)       fifo_in_tx  <- mkBypassFIFO;
   FIFO#(req_t)        fifo_in_rx  <- mkBypassFIFO;
   FIFO#(req_t)        fifo_out_tx <- mkBypassFIFO;
   FIFO#(resp_t)       fifo_out_rx <- mkBypassFIFO;

   let rx_in = toTLMRequest(fifo_in_rx.first);

   rule read_op_first (rx_in matches tagged Descriptor .d
		       &&& d.command matches READ
		       &&& (count == 0));
      let desc_current = d;
      desc_current.burst_length = 1;
      fifo_out_tx.enq(fromTLMRequest(tagged Descriptor desc_current));
      desc_reg <= incrTLMAddr(d);

      let remaining = d.burst_length - 1;
      count <= remaining;
      if (remaining == 0) fifo_in_rx.deq;
   endrule

   rule read_op_rest (rx_in matches tagged Descriptor .d
		      &&& d.command matches READ
		      &&& (count > 0));
      let desc_current = desc_reg;
      desc_current.burst_length = 1;
      fifo_out_tx.enq(fromTLMRequest(tagged Descriptor desc_current));
      desc_reg <= incrTLMAddr(desc_reg);

      let remaining = count - 1;
      count <= remaining;
      if (remaining == 0) fifo_in_rx.deq;
   endrule

   rule write_op_first (rx_in matches tagged Descriptor .d
			&&& d.command matches WRITE);
      let desc_current = d;
      desc_current.burst_length = 1;
      fifo_out_tx.enq(fromTLMRequest(tagged Descriptor desc_current));
      desc_reg <= incrTLMAddr(d);

      fifo_in_rx.deq;
   endrule

   rule write_op_rest (rx_in matches tagged Data .d);
      let desc_current = desc_reg;
      desc_current.burst_length = 1;
      desc_current.data = d.data;
      fifo_out_tx.enq(fromTLMRequest(tagged Descriptor desc_current));
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
