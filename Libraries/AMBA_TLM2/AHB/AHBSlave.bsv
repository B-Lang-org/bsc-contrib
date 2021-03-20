// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AHBSlave;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import AHBDefines::*;
import BUtils::*;
import DReg::*;
import DefaultValue::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import SpecialFIFOs::*;
import TLM2::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AHBSlaveIFC#(`TLM_PRM_DCL);
   interface AHBSlave#(`TLM_PRM)              bus;
   interface Put#(AHBResponse#(`TLM_PRM))     response;
   interface ReadOnly#(AHBRequest#(`TLM_PRM)) request;
endinterface

module mkAHBSlaveIFC#(Bool selected) (AHBSlaveIFC#(`TLM_PRM));

   Wire#(AHBData#(`TLM_PRM)) wdata_wire    <- mkBypassWire;
   Wire#(AHBWrite)           write_wire    <- mkBypassWire;
   Wire#(AHBSize)            size_wire     <- mkBypassWire;
   Wire#(AHBBurst)           burst_wire    <- mkBypassWire;
   Wire#(AHBTransfer)        transfer_wire <- mkBypassWire;
   Wire#(AHBProt)            prot_wire     <- mkBypassWire;
   Wire#(AHBAddr#(`TLM_PRM)) addr_wire     <- mkBypassWire;

   let dflt = AHBResponse {status:  OKAY,
				    data:    'h123,
				    command: tagged Invalid};

   Wire#(AHBResponse#(`TLM_PRM)) response_wire <- mkDWire(dflt);
   Wire#(Bool)                     ready     <- mkDWire(False);

   interface Put response;
      method Action put (AHBResponse#(`TLM_PRM) value);
	 response_wire <= value;
	 ready         <= True;
      endmethod
   endinterface

   interface ReadOnly request;
      method AHBRequest#(`TLM_PRM) _read;
	 let ctrl = AHBCtrl {command:    write_wire,
			     size:     size_wire,
			     burst:    burst_wire,
			     transfer: transfer_wire,
			     prot:     prot_wire,
			     addr:     addr_wire};
	 let value = AHBRequest {ctrl: ctrl, data: wdata_wire};
	 return value;
      endmethod
   endinterface

   interface AHBSlave bus;
      // Outputs
      method hRDATA = response_wire.data;
      method hRESP  = response_wire.status;
      method hREADY = ready;

      // Inputs
      method hADDR  = addr_wire._write;
      method hWDATA = wdata_wire._write;
      method hWRITE = write_wire._write;
      method hBURST = burst_wire._write;
      method hTRANS = transfer_wire._write;
      method hSIZE  = size_wire._write;
      method hPROT  = prot_wire._write;
   endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAHBSlaveStd#(function Bool addr_match(AHBAddr#(`TLM_PRM_STD) addr))
			 (AHBSlaveXActor#(`TLM_RR_STD, `TLM_PRM_STD));
   let _ifc <- mkAHBSlaveSynthStd;

   interface TLMSendIFC       tlm  = _ifc.tlm;
   interface AHBFabricSlave   fabric;
      interface AHBSlave         bus      = _ifc.fabric.bus;
      interface AHBSlaveSelector selector;
	 method addrMatch = addr_match;
	 method select    = _ifc.fabric.selector.select;
      endinterface
   endinterface

endmodule

module mkAHBSlave#(function Bool addr_match(AHBAddr#(`TLM_PRM) addr)) (AHBSlaveXActor#(`TLM_RR, `TLM_PRM))
   provisos(TLMRequestTC#(req_t, `TLM_PRM),
	    TLMResponseTC#(resp_t, `TLM_PRM),
	    DefaultValue#(RequestDescriptor#(`TLM_PRM)),
	    Bits#(req_t, s0),
	    Bits#(resp_t, s1),
	    AHBConvert#(AHBProt, cstm_type));

   let _ifc <- mkAHBSlaveSynth;

   interface TLMSendIFC     tlm = _ifc.tlm;
   interface AHBFabricSlave fabric;
      interface AHBSlave         bus      = _ifc.fabric.bus;
      interface AHBSlaveSelector selector;
	 method addrMatch = addr_match;
	 method select    = _ifc.fabric.selector.select;
      endinterface
   endinterface
endmodule

(* synthesize *)
module mkAHBSlaveSynthStd (AHBSlaveXActor#(`TLM_RR_STD, `TLM_PRM_STD));
   let _ifc <- mkAHBSlaveSynth;
   return _ifc;
endmodule

module mkAHBSlaveSynth (AHBSlaveXActor#(`TLM_RR, `TLM_PRM))
   provisos(TLMRequestTC#(req_t, `TLM_PRM),
	    TLMResponseTC#(resp_t, `TLM_PRM),
	    DefaultValue#(RequestDescriptor#(`TLM_PRM)),
	    Bits#(req_t, s0),
	    Bits#(resp_t, s1),
	    AHBConvert#(AHBProt, cstm_type));

   FIFOF#(resp_t)                   fifo_rx     <- mkBypassFIFOF;
   FIFOF#(req_t)                    fifo_tx     <- mkBypassFIFOF;

   Reg#(Maybe#(AHBCtrl#(`TLM_PRM))) ctrl_reg    <- mkReg(Invalid);

   Reg#(Bool)                       first       <- mkDReg(False);
   Reg#(Bool)                       start       <- mkReg(True);

   Wire#(Bool)                      select_wire <- mkBypassWire;

   FIFOF#(Bit#(0))                  fifo_op     <- mkBypassFIFOF;

   let ifc <- mkAHBSlaveIFC(select_wire);

   let request = ifc.request;

   (* preempts = "not_selected, grab_ctrl" *)
   rule not_selected (!select_wire);
      // dummy rule
   endrule

   rule grab_response (ctrl_reg matches tagged Valid .ctrl_prev &&&
		       ((ctrl_prev.transfer == SEQ) || (ctrl_prev.transfer == NONSEQ)));
      let response = toTLMResponse(fifo_rx.first);
      fifo_rx.deq;
      let ahb_response = AHBResponse {status:  OKAY,
				      data:    response.data,
				      command: tagged Invalid};
      ifc.response.put(ahb_response);
      let ctrl = request.ctrl;
      ctrl_reg <= (select_wire) ? tagged Valid ctrl : tagged Invalid;
      fifo_op.deq;
   endrule

   rule send_request (ctrl_reg matches tagged Valid .ctrl_prev &&&
		      ((ctrl_prev.transfer == SEQ) || (ctrl_prev.transfer == NONSEQ)));
      let ctrl = request.ctrl;
      let desc = fromAHBCtrl(ctrl_prev);
      desc.data = request.data;
      desc.burst_mode   = INCR;
      desc.burst_length = 1;
      fifo_tx.enq(fromTLMRequest(tagged Descriptor desc));
      fifo_op.enq(0);
   endrule

   rule default_response (ctrl_reg matches tagged Valid .ctrl_prev &&&
			  ((ctrl_prev.transfer == IDLE) || (ctrl_prev.transfer == BUSY)));
      let ahb_response = AHBResponse {status:  OKAY,
				      data:    'h123,
				      command: tagged Invalid};
      ifc.response.put(ahb_response);
      let ctrl = request.ctrl;
      ctrl_reg <= (select_wire) ? tagged Valid ctrl : tagged Invalid;
   endrule

   rule grab_ctrl (ctrl_reg matches tagged Invalid);
      ctrl_reg <= tagged Valid request.ctrl;
   endrule

   interface TLMSendIFC tlm;
      interface Get tx = toGet(fifo_tx);
      interface Put rx = toPut(fifo_rx);
   endinterface

   interface AHBFabricSlave fabric;
      interface AHBSlave bus = ifc.bus;
      interface AHBSlaveSelector selector;
	 method Bool   addrMatch(AHBAddr#(`TLM_PRM) value) = True;
	 method select = select_wire._write;
      endinterface
   endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAHBSlaveDummy (AHBFabricSlave#(`TLM_PRM));

   Wire#(AHBTransfer) transfer_wire <- mkBypassWire;
   Reg#(AHBTransfer)  transfer_reg  <- mkReg(?);

   Wire#(Bool)        select_wire   <- mkBypassWire;
   Reg#(Bool)         select_reg    <- mkReg(False);

   Wire#(Bool)        ready_wire   <- mkBypassWire;

   let ready = (transfer_reg == IDLE) || (transfer_reg == BUSY) || !select_reg;

   rule every;
      ready_wire <= ready;
   endrule

   rule updatex (ready);
      select_reg <= select_wire;
   endrule

   rule update;
      transfer_reg <= transfer_wire;
   endrule

   function Action noop (a ignore);
      return noAction;
   endfunction

   interface AHBSlave bus;

      // Outputs
      method hRDATA = 'h567;
      method hRESP  = OKAY;

      method hREADY = ready;

      // Inputs
      method hADDR  = noop;
      method hWDATA = noop;
      method hWRITE = noop;
      method hBURST = noop;
      method Action hTRANS (value);
	 transfer_wire <= value;
      endmethod
      method hSIZE  = noop;
      method hPROT  = noop;
   endinterface

   interface AHBSlaveSelector selector;
      method Bool   addrMatch(AHBAddr#(`TLM_PRM) value) = False;
      method Action select (value);
	 select_wire <= value;
      endmethod
   endinterface


endmodule

endpackage
