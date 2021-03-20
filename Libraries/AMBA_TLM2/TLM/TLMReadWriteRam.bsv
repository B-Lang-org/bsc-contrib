// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package TLMReadWriteRam;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import FShow::*;
import GetPut::*;
import Probe::*;
import RegFile::*;
import TLMDefines::*;
import TLMUtils::*;
import BUtils::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkTLMReadWriteRam#(parameter Bit#(4) id, Bool verbose) (TLMReadWriteRecvIFC#(`TLM_TYPES))
   provisos(Bits#(TLMRequest#(`TLM_TYPES),  s0),
	    Bits#(TLMResponse#(`TLM_TYPES), s1),
	    FShow#(TLMRequest#(`TLM_TYPES)),
	    FShow#(TLMResponse#(`TLM_TYPES)));

   Wire#(TLMRequest#(`TLM_TYPES))  read_in_wire   <- mkWire;
   Wire#(TLMResponse#(`TLM_TYPES)) read_out_wire  <- mkWire;
   Wire#(TLMRequest#(`TLM_TYPES))  write_in_wire  <- mkWire;
   Wire#(TLMResponse#(`TLM_TYPES)) write_out_wire <- mkWire;

   RegFile#(Bit#(8), Bit#(data_size)) ram <- mkRegFileLoad("ram_init.text", 0, 255);

   rule read_op (read_in_wire matches tagged Descriptor .d
		 &&& d.command == READ
		 &&& d.burst_length == 1);

      TLMResponse#(`TLM_TYPES) response = createBasicTLMResponse();
      Bit#(10) addr = zExtend(d.addr);
      Bit#(8) mem_addr = grab_left(addr);
      TLMData#(`TLM_TYPES) data = ram.sub(mem_addr);
      response.data = maskTLMData(d.byte_enable, data);
      response.status = SUCCESS;
      response.transaction_id = d.transaction_id;
      response.command = READ;

      read_out_wire <= response;

      if (verbose) $display("(%0d) TM (%0d) %0d Read  Op %h %h", $time, id, d.transaction_id, d.addr, response.data);

   endrule

   rule write_op (write_in_wire matches tagged Descriptor .d
		  &&& d.command == WRITE
		  &&& d.burst_length == 1);

      Bit#(10) addr = zExtend(d.addr);
      Bit#(8) mem_addr = grab_left(addr);
      TLMData#(`TLM_TYPES) data_orig = ram.sub(mem_addr);
      TLMData#(`TLM_TYPES) data_new  = overwriteTLMData(d.byte_enable, data_orig, d.data);
      ram.upd(mem_addr, data_new);

      TLMResponse#(`TLM_TYPES) response = createBasicTLMResponse();
      response.status = SUCCESS;
      response.transaction_id = d.transaction_id;
      response.command = WRITE;

      write_out_wire <= response;

      if (verbose) $display("(%0d) TM (%0d) %0d Write Op %h %h", $time, id, d.transaction_id, d.addr, d.data);

   endrule

   rule read_error_op (read_in_wire matches tagged Descriptor .d
		       &&& (d.burst_length > 1));
      $display("(%0d) ERROR: TLMReadWriteRAM (%0d) (cannot handle ops with burst length > 1).", $time, id);
   endrule

   rule write_error_op (write_in_wire matches tagged Descriptor .d
			&&& (d.burst_length > 1));
      $display("(%0d) ERROR: TLMReadWriteRAM (%0d) (cannot handle ops with burst length > 1).", $time, id);
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
