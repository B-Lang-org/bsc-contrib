// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package TLMCBusAdapter;

import CBus::*;
import GetPut::*;
import TLMDefines::*;
import BUtils::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typedef CBus#(caddr_size, data_size) TLMCBus#(`TLM_TYPE_PRMS, numeric type caddr_size);
typedef ModWithCBus#(caddr_size, data_size, i) ModWithTLMCBus#(`TLM_TYPE_PRMS, numeric type caddr_size, type i);

module mkTLMCBusAdapter#(function Bit#(caddr_size) mapTLMAddr(Bit#(addr_size) addr),
			 TLMCBus#(`TLM_TYPES, caddr_size) cfg) (TLMRecvIFC#(`TLM_TYPES))
   provisos(Bits#(TLMRequest#(`TLM_TYPES),  s0),
	    Bits#(TLMResponse#(`TLM_TYPES), s1),
	    Add#(ignore, caddr_size, addr_size));

   Wire#(TLMRequest#(`TLM_TYPES))  tlm_in_wire   <- mkWire;
   Wire#(TLMResponse#(`TLM_TYPES)) tlm_out_wire  <- mkWire;

   rule read_op (tlm_in_wire matches tagged Descriptor .d
		 &&& d.command matches READ
		 &&& d.burst_length matches 1);

      TLMResponse#(`TLM_TYPES) response = unpack(0);
      Bit#(caddr_size) addr = mapTLMAddr(d.addr);
      let data <- cfg.read(addr);
      response.data = data;
      response.status = SUCCESS;
      response.command = READ;
      response.transaction_id = d.transaction_id;

      tlm_out_wire <= response;

   endrule

   rule write_op (tlm_in_wire matches tagged Descriptor .d
		  &&& d.command matches WRITE
		  &&& d.burst_length matches 1);
      TLMResponse#(`TLM_TYPES) response = unpack(0);
      Bit#(caddr_size) addr = mapTLMAddr(d.addr);
      cfg.write(addr, d.data);
      response.status = SUCCESS;
      response.command = WRITE;
      response.transaction_id = d.transaction_id;

      tlm_out_wire <= response;

   endrule

   rule error_op (tlm_in_wire matches tagged Descriptor .d
		  &&& (d.burst_length > 1));
      $display("(%5d) ERROR: TLMCbusAdapter (cant handle ops with burst length > 1).", $time);
   endrule

   interface Get tx;
      method get;
	 actionvalue
            return tlm_out_wire;
	 endactionvalue
      endmethod
   endinterface
   interface Put rx;
      method Action put (x);
	 tlm_in_wire <= x;
      endmethod
   endinterface

endmodule

module mkTLMCBusAdapterToReadWrite#(function Bit#(caddr_size) mapTLMAddr(Bit#(addr_size) addr),
				    TLMCBus#(`TLM_TYPES, caddr_size) cfg)
				   (TLMReadWriteRecvIFC#(`TLM_TYPES))
   provisos(Bits#(TLMRequest#(`TLM_TYPES),  s0),
	    Bits#(TLMResponse#(`TLM_TYPES), s1),
	    Add#(ignore, caddr_size, addr_size));

   Wire#(TLMRequest#(`TLM_TYPES))  read_in_wire   <- mkWire;
   Wire#(TLMResponse#(`TLM_TYPES)) read_out_wire  <- mkWire;
   Wire#(TLMRequest#(`TLM_TYPES))  write_in_wire  <- mkWire;
   Wire#(TLMResponse#(`TLM_TYPES)) write_out_wire <- mkWire;

   rule read_op (read_in_wire matches tagged Descriptor .d
		 &&& d.command matches READ
		 &&& d.burst_length matches 1);

      TLMResponse#(`TLM_TYPES) response = unpack(0);
      Bit#(caddr_size) addr = mapTLMAddr(d.addr);
      let data <- cfg.read(addr);
      response.data = data;
      response.status = SUCCESS;
      response.command = READ;
      response.transaction_id = d.transaction_id;

      read_out_wire <= response;

   endrule

   rule write_op (write_in_wire matches tagged Descriptor .d
		  &&& d.command matches WRITE
		  &&& d.burst_length matches 1);
      TLMResponse#(`TLM_TYPES) response = unpack(0);
      Bit#(caddr_size) addr = mapTLMAddr(d.addr);
      cfg.write(addr, d.data);
      response.status = SUCCESS;
      response.command = WRITE;
      response.transaction_id = d.transaction_id;

      write_out_wire <= response;

//      $display("[%0d] CBUS WRITE (%0d) %h %h",
//	 $time, d.transaction_id, d.addr, d.data);

   endrule

   rule read_error_op (read_in_wire matches tagged Descriptor .d
		       &&& (d.burst_length > 1));
      $display("[%0d] ERROR: TLMCbusAdapter (cant handle ops with burst length > 1).", $time);
   endrule

   rule write_error_op (read_in_wire matches tagged Descriptor .d
			&&& (d.burst_length > 1));
      $display("[%0d] ERROR: TLMCbusAdapter (cant handle ops with burst length > 1).", $time);
   endrule

   interface TLMRecvIFC read;
      interface Get tx;
	 method get;
	    actionvalue
               return read_out_wire;
	    endactionvalue
	 endmethod
      endinterface
      interface Put rx;
	 method Action put (x);
	    read_in_wire <= x;
	 endmethod
      endinterface
   endinterface

   interface TLMRecvIFC write;
      interface Get tx;
	 method get;
	    actionvalue
               return write_out_wire;
	    endactionvalue
	 endmethod
      endinterface
      interface Put rx;
	 method Action put (x);
	    write_in_wire <= x;
	 endmethod
      endinterface
   endinterface

endmodule

endpackage
