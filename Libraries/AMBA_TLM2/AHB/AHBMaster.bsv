// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AHBMaster;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import AHBArbiter::*;
import AHBDefines::*;
import BUtils::*;
import DefaultValue::*;
import DReg::*;
import FIFO::*;
import FIFOF::*;
import FIFOLevel::*;
import GetPut::*;
import SpecialFIFOs::*;
import TLM2::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface GetPut#(type p, type g);
   method ActionValue#(g) getput(p value);
endinterface

interface AHBMasterIFC#(`TLM_PRM_DCL);
   interface AHBMaster#(`TLM_PRM)                                   bus;
   interface GetPut#(AHBRequest#(`TLM_PRM), AHBResponse#(`TLM_PRM)) obj;
endinterface

module mkAHBMasterIFC (AHBMasterIFC#(`TLM_PRM));

   Reg#(AHBRequest#(`TLM_PRM))   request_reg  <- mkReg(unpack(0));
   Wire#(AHBResponse#(`TLM_PRM)) response     <- mkWire;

   let request = request_reg;

   Wire#(AHBResp)              response_wire <- mkBypassWire;
   Wire#(AHBData#(`TLM_PRM)) rdata_wire    <- mkBypassWire;
   Wire#(Bool)                 ready_wire    <- mkBypassWire;

   Wire#(AHBWrite)             command_wire  <- mkWire;

   FIFOF#(Maybe#(AHBWrite))    fifo_op       <- mkDFIFOF(Invalid);

   rule every (ready_wire);
      let command = fifo_op.first;
      fifo_op.deq;
      let value = AHBResponse {data:    rdata_wire,
			       status:  response_wire,
			       command: command};
      response <= value;
   endrule

   rule do_enq;
      fifo_op.enq(tagged Valid command_wire);
   endrule

   rule pre_enq ((request.ctrl.transfer != IDLE) &&
		 (request.ctrl.transfer != BUSY) &&
		 ready_wire);
      command_wire <= request.ctrl.command;
   endrule

   interface GetPut obj;
      method ActionValue#(AHBResponse#(`TLM_PRM)) getput (AHBRequest#(`TLM_PRM) value) if (ready_wire);
	 request_reg <= value;
	 return(response);
      endmethod
   endinterface

   interface AHBMaster bus;
      // Outputs
      method hADDR  = request.ctrl.addr;
      method hWDATA = request.data;
      method hWRITE = request.ctrl.command;
      method hTRANS = request.ctrl.transfer;
      method hBURST = request.ctrl.burst;
      method hSIZE  = request.ctrl.size;
      method hPROT  = request.ctrl.prot;

      // Inputs
      method hRDATA = rdata_wire._write;
      method hREADY = ready_wire._write;
      method hRESP  = response_wire._write;
   endinterface


endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

(* synthesize *)
module mkAHBMasterStd (AHBMasterXActor#(`TLM_RR_STD, `TLM_PRM_STD));
   let _ifc <- mkAHBMaster;
   return _ifc;
endmodule

module mkAHBMaster (AHBMasterXActor#(`TLM_RR, `TLM_PRM))
   provisos(TLMRequestTC#(req_t, `TLM_PRM),
	    TLMResponseTC#(resp_t, `TLM_PRM),
	    DefaultValue#(TLMResponse#(`TLM_PRM)),
	    Bits#(req_t, s0),
	    Bits#(resp_t, s1),
	    Bits#(RequestDescriptor#(`TLM_PRM), s2),
	    AHBConvert#(AHBProt, cstm_type),
	    AHBConvert#(AHBResp, cstm_type)
	    );

   Wire#(AHBResponse#(`TLM_PRM))              response_wire <- mkWire;

   FIFOF#(req_t)                              fifo_rx    <- mkBypassFIFOF;
   FIFOLevelIfc#(resp_t, 5)                   fifo_tx    <- mkBypassFIFOLevel;

   Reg#(Bool)                                 req_wire   <- mkDWire(False);
   Reg#(Bool)                                 req_reg    <- mkReg(False);

   Reg#(Maybe#(RequestDescriptor#(`TLM_PRM))) descriptor <- mkReg(Invalid);
   Reg#(TLMUInt#(`TLM_PRM))                   count      <- mkReg(0);
   Wire#(Bool)                                lock_wire  <- mkDWire(False);
   Wire#(Bool)                                grant_wire <- mkBypassWire;
   Reg#(Bool)                                 grant_reg  <- mkReg(False);
   Wire#(Bool)                                stall_wire <- mkDWire(False);
   Reg#(Maybe#(AHBData#(`TLM_PRM)))           data_reg   <- mkReg(Invalid);

   let ifc <- mkAHBMasterIFC;

   rule update_grant;
      grant_reg <= grant_wire;
   endrule

   rule send_request (fifo_rx.notEmpty && !grant_reg && !(count == 0 && stall_wire));
      req_wire <= True;
   endrule

   let rx_first = toTLMRequest(fifo_rx.first);

   (* preempts = "(start_op, write_op, read_op), (idle_op, stall_op)" *)
   rule start_op (rx_first matches tagged Descriptor .d &&&
		  count == 0 &&&
		  !stall_wire &&&
		  grant_wire);
      let next = incrTLMAddr(d);
      descriptor <= tagged Valid next;
      let remaining = d.burst_length - 1;
      count <= remaining;
      let ctrl = getAHBCtrl(d);
      ctrl.transfer = NONSEQ;
      let data = ?;
      if (data_reg matches tagged Valid .d) data = d;
      data_reg <= tagged Valid getAHBData(d);
      let ahb_request = AHBRequest { ctrl: ctrl, data: data};
      let response <- ifc.obj.getput(ahb_request);
      response_wire <= response;
      fifo_rx.deq;
      if (assertLock(d)) lock_wire <= True;
      req_reg <= (ctrl.burst == INCR) && (remaining > 0);
   endrule

   rule write_op (rx_first matches tagged Data .d &&&
		  descriptor matches tagged Valid .des &&&
		  des.command == WRITE &&&
		  count > 0 &&&
		  !stall_wire &&&
		  grant_wire);
      let remaining = count - 1;
      count <= remaining;
      let next = incrTLMAddr(des);
      descriptor <= tagged Valid next;
      let ctrl = getAHBCtrl(des);
      ctrl.transfer = (getAHBBurst(des) == SINGLE) ? NONSEQ : SEQ;
      let data = ?;
      if (data_reg matches tagged Valid .d) data = d;
      data_reg <= tagged Valid d.data;
      let ahb_request = AHBRequest { ctrl: ctrl, data: data};
      let response <- ifc.obj.getput(ahb_request);
      response_wire <= response;
      fifo_rx.deq;
      if (ctrl.transfer == NONSEQ) lock_wire <= True;
      req_reg <= (ctrl.burst == INCR) && (remaining > 0);
   endrule

   rule read_op (descriptor matches tagged Valid .des &&&
		 des.command == READ &&&
		 count > 0 &&&
		 !stall_wire &&&
		 grant_wire);
      let remaining = count - 1;
      count <= remaining;
      let next = incrTLMAddr(des);
      descriptor <= tagged Valid next;
      let ctrl = getAHBCtrl(des);
      ctrl.transfer = (getAHBBurst(des) == SINGLE) ? NONSEQ : SEQ;
      let data = ?;
      if (data_reg matches tagged Valid .d) data = d;
      data_reg <= tagged Valid 0;
      let ahb_request = AHBRequest { ctrl: ctrl, data: data};
      let response <- ifc.obj.getput(ahb_request);
      response_wire <= response;
      if (ctrl.transfer == NONSEQ) lock_wire <= True;
      req_reg <= (ctrl.burst == INCR) && (remaining > 0);
   endrule

   rule idle_op (data_reg matches tagged Valid .x);
      let ctrl = unpack(0);
      if (descriptor matches tagged Valid .des) ctrl = getAHBCtrl(des);
      if (descriptor matches tagged Valid .des &&& (getAHBBurst(des) == SINGLE))
	 ctrl.transfer = IDLE;
      else
	 ctrl.transfer = (count == 0) ? IDLE : BUSY;
      let data = ?;
      if (data_reg matches tagged Valid .d) data = d;
      data_reg <= tagged Invalid;
      let response <- ifc.obj.getput(AHBRequest { ctrl: ctrl, data: data});
      response_wire <= response;
      req_reg <= (ctrl.transfer == IDLE) ? False : req_reg;
   endrule

   rule stall_op (data_reg matches tagged Invalid);
      let ctrl = unpack(0);
      if (descriptor matches tagged Valid .des) ctrl = getAHBCtrl(des);
      if (descriptor matches tagged Valid .des &&& (getAHBBurst(des) == SINGLE))
	 ctrl.transfer = IDLE;
      else
	 ctrl.transfer = (count == 0) ? IDLE : BUSY;
      let response <- ifc.obj.getput(AHBRequest { ctrl: ctrl, data: ?});
      response_wire <= response;
      req_reg <= (ctrl.transfer == IDLE) ? False : req_reg;
   endrule

   rule grab_valid_response (response_wire.command matches tagged Valid .c);
      let value = response_wire;
      TLMResponse#(`TLM_PRM) response = defaultValue;
      response.data    = value.data;
      response.status  = fromAHBResp(value.status);
      response.command = fromAHBWrite(c);
      response.custom  = fromAHB(value.status);
      fifo_tx.enq(fromTLMResponse(response));
   endrule

   rule grab_invalid_response (response_wire.command matches tagged Invalid);
      dummyAction;
   endrule


   rule stall (fifo_tx.isGreaterThan(1) && (count != 1));
      stall_wire <= True;
   endrule

   interface TLMRecvIFC tlm;
      interface Get tx = toGet(fifo_tx);
      interface Put rx = toPut(fifo_rx);
   endinterface

   interface AHBFabricMaster fabric;
      interface AHBMaster bus = ifc.bus;
      interface AHBMasterArbiter arbiter;
	 method hBUSREQ = (req_wire || req_reg);
	 method hLOCK   = lock_wire;
	 method hGRANT  = grant_wire._write;
      endinterface
   endinterface


endmodule

function Bool assertLock (RequestDescriptor#(`TLM_PRM) desc);
   let burst = getAHBBurst(desc);
   let length = desc.burst_length;
   return (burst == SINGLE) && (length != 1);
endfunction

endpackage
