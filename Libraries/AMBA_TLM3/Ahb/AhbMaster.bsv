// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AhbMaster;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import AhbArbiter::*;
import AhbDefines::*;
import BUtils::*;
import DefaultValue::*;
import DReg::*;
import FIFO::*;
import FIFOF::*;
import FIFOLevel::*;
import FShow::*;
import GetPut::*;
import SpecialFIFOs::*;
import TLM3::*;
import CBus::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface GetPut#(type p, type g);
   method ActionValue#(g) getput(p value);
endinterface

interface AhbMasterIFC#(`TLM_PRM_DCL);
   interface AhbMaster#(`TLM_PRM)                                   bus;
   interface ReadOnly#(AhbResp)                            resp_current;
   interface GetPut#(AhbRequest#(`TLM_PRM), AhbResponse#(`TLM_PRM)) obj;
endinterface


typedef enum {RUN, REDO_EBT, REDO_RETRY, WIND_DOWN} EBTMode deriving (Eq, Bits, Bounded);

module mkAhbMasterIFC#(Bool grant, EBTMode ebt_mode) (AhbMasterIFC#(`TLM_PRM));

   Reg#(AhbRequest#(`TLM_PRM))   request_reg  <- mkReg(unpack(0));
   Wire#(AhbResponse#(`TLM_PRM)) response     <- mkWire;

   let request = request_reg;

   Wire#(AhbResp)            response_wire <- mkBypassWire;
   Wire#(AhbData#(`TLM_PRM)) rdata_wire    <- mkBypassWire;
   Wire#(Bool)               ready_wire    <- mkBypassWire;

   Wire#(AhbWrite)         command_wire  <- mkWire;

   FIFOF#(Maybe#(AhbWrite)) fifo_op       <- mkDFIFOF(Invalid);


   rule every (ready_wire);
      let command = fifo_op.first;
      fifo_op.deq;
      let value = AhbResponse {data:    rdata_wire,
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

   rule detect_split_retry (!ready_wire && (response_wire == RETRY || response_wire == SPLIT));
      let r = request;
      let ctrl = r.ctrl;
      ctrl.transfer = IDLE;
      r.ctrl = ctrl;
      request_reg <= r;
   endrule

   interface ReadOnly resp_current;
      method _read = response_wire;
   endinterface

   interface GetPut obj;
      method ActionValue#(AhbResponse#(`TLM_PRM)) getput (AhbRequest#(`TLM_PRM) value) if (ready_wire);
	 let ctrl = value.ctrl;
	 let value2 = value;
	 ctrl.transfer = (!grant) ? IDLE : ctrl.transfer;
	 value2.ctrl = ctrl;
	 request_reg <= value2;
	 return(response);
      endmethod
   endinterface

   interface AhbMaster bus;
      // Outputs
      method haddr  = request.ctrl.addr;
      method hwdata = request.data;
      method hwrite = request.ctrl.command;
      method htrans = (ebt_mode != RUN && request.ctrl.transfer == BUSY) ? IDLE : request.ctrl.transfer;
      method hburst = request.ctrl.burst;
      method hsize  = request.ctrl.size;
      method hprot  = request.ctrl.prot;

      // Inputs
      method hrdata = rdata_wire._write;
      method hready = ready_wire._write;
      method hresp  = response_wire._write;
   endinterface


endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAhbMaster#(parameter UInt#(32) max_flight) (AhbMasterXActor#(`TLM_XTR))
   provisos(Bits#(req_t, s0),
	    Bits#(resp_t, s1),
	    TLMRequestTC#(req_t, `TLM_PRM),
	    TLMResponseTC#(resp_t, `TLM_PRM),
	    DefaultValue#(TLMResponse#(`TLM_PRM)));

//   let depth = max(3, max_flight);
   let depth = 3; // don't ever need more than this.

   Wire#(AhbResponse#(`TLM_PRM))      response_wire <- mkWire;

   FIFOF#(req_t)                      fifo_rx    <- mkBypassFIFOF;
   FIFOLevelIfc#(resp_t, 5)           fifo_tx    <- mkFIFOLevel;

   Reg#(Bool)                         req_wire   <- mkDWire(False);
   Reg#(Bool)                         req_reg    <- mkReg(False);

   Reg#(Maybe#(RequestDescriptor#(`TLM_PRM))) descriptor <- mkReg(Invalid);
   Reg#(TLMBLength#(`TLM_PRM))                count      <- mkReg(0);
   Reg#(Bool)                                 lock_reg   <- mkReg(False);


   Wire#(Bool)                                grant_wire <- mkBypassWire;
   Reg#(Bool)                                 grant_reg  <- mkReg(False);
   Wire#(Bool)                                stall_wire <- mkDWire(False);
   Reg#(Maybe#(AhbData#(`TLM_PRM)))           data_reg   <- mkReg(Invalid);
   Reg#(Maybe#(AhbData#(`TLM_PRM)))           data_prev  <- mkReg(Invalid);

   CFIFO#(UInt#(TAdd#(SizeOf#(TLMBLength#(`TLM_PRM)), 1))) length_fifo <- mkCFIFO(depth);
   FIFO#(TLMId#(`TLM_PRM))                           id_fifo           <- mkDepthParamFIFO(depth);
   Reg#(EBTMode)                                     ebt_mode          <- mkReg(RUN);

   let ifc <- mkAhbMasterIFC(grant_wire, ebt_mode);

   let rx_first = toTLMRequest(fifo_rx.first);

   rule update_grant;
      grant_reg <= grant_wire;
   endrule

   rule send_request (rx_first matches tagged Descriptor .d &&&
		      assertLock(d) == lock_reg &&&
		      !(count == 0 && stall_wire));
      req_wire <= True;
   endrule

   rule set_lock (rx_first matches tagged Descriptor .d &&&
	     assertLock(d) != lock_reg &&&
             count == 0);
      lock_reg <= assertLock(d);
   endrule

   Reg#(Bit#(3)) in_flight <- mkReg(0);
   PulseWire     do_incr <- mkPulseWire;
   PulseWire     do_decr <- mkPulseWire;

   Bit#(3) in_flight_current =
   case (tuple2(do_incr, do_decr)) matches
	 {False, False} : in_flight;
	 {False, True } : (in_flight - 1);
	 {True,  False} : (in_flight + 1);
	 {True,  True } : in_flight;
   endcase;


   Reg#(Maybe#(AhbRequest#(`TLM_PRM))) req_prev <- mkReg(tagged Invalid);

   Bool early_end = /*!grant_wire &&*/ count != 0 && ebt_mode == RUN;
   Bool can_run = in_flight == 0 && ebt_mode != REDO_RETRY && ebt_mode != REDO_EBT;

   PulseWire split_retry <- mkPulseWire;
   PulseWire last_pw     <- mkPulseWire;

   rule detect_ebt (early_end && !split_retry && !last_pw);
      ebt_mode <= (in_flight_current == 0) ? WIND_DOWN : REDO_EBT;
   endrule

   rule detect_split_retry (split_retry);
      ebt_mode <= REDO_RETRY;
   endrule

   rule ebt_finish (last_pw && !split_retry);
      ebt_mode <= RUN;
   endrule

   rule incr (do_incr && ! do_decr);
      in_flight <= in_flight + 1;
   endrule

   rule decr (!do_incr && do_decr);
      in_flight <= in_flight - 1;
   endrule

   (* preempts = "(redo_op, start_op, write_op, read_op), (idle_op, stall_op)" *)
   rule redo_op (req_prev matches tagged Valid .r &&&
		 !stall_wire &&&
		 grant_wire &&&
		 (ebt_mode == REDO_EBT || ebt_mode == REDO_RETRY));
      let ctrl = r.ctrl;
      let data = r.data;
      ctrl.burst = SINGLE;
      ctrl.transfer = NONSEQ;
      data_reg <= data_prev;
/* -----\/----- EXCLUDED -----\/-----
      let data = ?;
      if (data_reg matches tagged Valid .d) data = d;
      data_reg <= tagged Valid r.data;
 -----/\----- EXCLUDED -----/\----- */
      let ahb_request = AhbRequest { ctrl: ctrl, data: data};
//      req_prev <= tagged Valid ahb_request;
      let response <- ifc.obj.getput(ahb_request);
      ebt_mode <= WIND_DOWN;
      if (ebt_mode == REDO_RETRY) do_incr.send;
   endrule

//   (* preempts = "(start_op, write_op, read_op), (idle_op, stall_op)" *)
   rule start_op (rx_first matches tagged Descriptor .d &&&
		  (assertLock(d) == lock_reg) &&&
		  count == 0 &&&
		  !stall_wire &&&
		  can_run &&&
		  grant_wire);
      let next = incrTLMAddr(d);
      descriptor <= tagged Valid next;
      length_fifo.enq(extendNP(d.b_length) + 1);
      id_fifo.enq(d.transaction_id);
      let remaining = d.b_length;
      count <= remaining;
      let ctrl = getAhbCtrl(d);
      ctrl.transfer = NONSEQ;
      let data = ?;
      if (data_reg matches tagged Valid .d) data = d;
      data_reg <= tagged Valid getAhbData(d);
      let ahb_request = AhbRequest { ctrl: ctrl, data: data};
      req_prev <= tagged Valid ahb_request;
      data_prev <= data_reg;
      let response <- ifc.obj.getput(ahb_request);
      response_wire <= response;
      fifo_rx.deq;
      req_reg <= (ctrl.burst == INCR) && (remaining > 0);
      do_incr.send;
   endrule

   rule write_op (rx_first matches tagged Data .d &&&
		  descriptor matches tagged Valid .des &&&
		  des.command == WRITE &&&
		  count > 0 &&&
		  !stall_wire &&&
		  can_run &&&
		  grant_wire);
      let remaining = count - 1;
      count <= remaining;
      let next = incrTLMAddr(des);
      descriptor <= tagged Valid next;
      let ctrl = getAhbCtrl(des);
      ctrl.transfer = (getAhbBurst(des) == SINGLE) ? NONSEQ : SEQ;
      let data = ?;
      if (data_reg matches tagged Valid .d) data = d;
      data_reg <= tagged Valid d.data;
      let ahb_request = AhbRequest { ctrl: ctrl, data: data};
      req_prev <= tagged Valid ahb_request;
      do_incr.send;
      data_prev <= data_reg;
      if (ebt_mode == WIND_DOWN)
	 begin
	    ctrl.burst    = SINGLE;
	    ctrl.transfer = NONSEQ;
	    ahb_request = AhbRequest { ctrl: ctrl, data: data};
	 end
      let response <- ifc.obj.getput(ahb_request);
      response_wire <= response;
      fifo_rx.deq;
      req_reg <= (ctrl.burst == INCR) && (remaining > 0);
   endrule

   rule read_op (descriptor matches tagged Valid .des &&&
		 des.command == READ &&&
		 count > 0 &&&
		 !stall_wire &&&
		 can_run &&&
		 grant_wire);
      let remaining = count - 1;
      count <= remaining;
      let next = incrTLMAddr(des);
      descriptor <= tagged Valid next;
      let ctrl = getAhbCtrl(des);
      ctrl.transfer = (getAhbBurst(des) == SINGLE) ? NONSEQ : SEQ;
      let data = ?;
      if (data_reg matches tagged Valid .d) data = d;
      data_reg <= tagged Valid 0;
      let ahb_request = AhbRequest { ctrl: ctrl, data: data};
      req_prev <= tagged Valid ahb_request;
      do_incr.send;
      data_prev <= data_reg;
      if (ebt_mode == WIND_DOWN)
	 begin
	    ctrl.burst    = SINGLE;
	    ctrl.transfer = NONSEQ;
	    ahb_request = AhbRequest { ctrl: ctrl, data: data};
	 end
      let response <- ifc.obj.getput(ahb_request);
      response_wire <= response;
      req_reg <= (ctrl.burst == INCR) && (remaining > 0);
   endrule

   rule idle_op (data_reg matches tagged Valid .x);
      let ctrl = unpack(0);
      if (descriptor matches tagged Valid .des) ctrl = getAhbCtrl(des);
      if (descriptor matches tagged Valid .des &&& (getAhbBurst(des) == SINGLE))
	 ctrl.transfer = IDLE;
      else
	 ctrl.transfer = (count == 0 || early_end) ? IDLE : BUSY;
      let data = ?;
      if (data_reg matches tagged Valid .d) data = d;
      data_reg <= tagged Invalid;
      data_prev <= data_reg;
      if (ebt_mode == WIND_DOWN)
	 begin
	    ctrl.burst    = SINGLE;
	    ctrl.transfer = IDLE;
	 end
      let response <- ifc.obj.getput(AhbRequest { ctrl: ctrl, data: data});
      response_wire <= response;
      req_reg <= (ctrl.transfer == IDLE) ? False : req_reg;
   endrule

   rule stall_op (data_reg matches tagged Invalid);
      let ctrl = unpack(0);
      if (descriptor matches tagged Valid .des) ctrl = getAhbCtrl(des);
      if (descriptor matches tagged Valid .des &&& (getAhbBurst(des) == SINGLE))
	 ctrl.transfer = IDLE;
      else
	 ctrl.transfer = (count == 0 || early_end) ? IDLE : BUSY;
      if (ebt_mode == WIND_DOWN)
	 begin
	    ctrl.burst    = SINGLE;
	    ctrl.transfer = IDLE;
	 end
      let response <- ifc.obj.getput(AhbRequest { ctrl: ctrl, data: ?});
      response_wire <= response;
      req_reg <= (ctrl.transfer == IDLE) ? False : req_reg;
   endrule

   (* aggressive_implicit_conditions *)
   rule grab_valid_response (response_wire.command matches tagged Valid .c

      			     &&& (length_fifo.first || fromAhbWrite(c) == READ));
      let is_last = length_fifo.first;
      let value = response_wire;
      TLMResponse#(`TLM_PRM) response = defaultValue ;
      response.data    = value.data;
      response.status  = fromAhbResp(value.status);
      response.command = fromAhbWrite(c);
      response.transaction_id = id_fifo.first;
      response.is_last = is_last;
      case (value.status)
	 SPLIT: begin
		   TLMErrorCode code = SPLIT;
		   response.data   = extendNP(pack(code));
		   split_retry.send;
		end
	 RETRY: begin
		   TLMErrorCode code = RETRY;
		   response.data   = extendNP(pack(code));
		   split_retry.send;
		end
	 ERROR: begin
		   TLMErrorCode code = SLVERR;
		   response.data   = extendNP(pack(code));
		end
	 default: begin // OKAY
		     response.data   = response.data;
		  end
      endcase
      if (value.status != SPLIT && value.status != RETRY)
	 begin
	    if(is_last) id_fifo.deq;
	    length_fifo.deq;
	    fifo_tx.enq(fromTLMResponse(response));
	 end
      do_decr.send;
      if (is_last) last_pw.send;
   endrule

   (* aggressive_implicit_conditions *)
   rule grab_valid_response_skip (response_wire.command matches tagged Valid .c
				  &&& !(length_fifo.first || fromAhbWrite(c) == READ));

      let value = response_wire;
      TLMResponse#(`TLM_PRM) response = defaultValue ;
      response.data    = value.data;
      response.status  = fromAhbResp(value.status);
      response.command = fromAhbWrite(c);
      response.transaction_id = id_fifo.first;
      response.is_last = False;
      case (value.status)
	 SPLIT: begin
		   TLMErrorCode code = SPLIT;
		   response.data   = extendNP(pack(code));
		   split_retry.send;
		end
	 RETRY: begin
		   TLMErrorCode code = RETRY;
		   response.data   = extendNP(pack(code));
		   split_retry.send;
		end
	 ERROR: begin
		   TLMErrorCode code = SLVERR;
		   response.data   = extendNP(pack(code));
		end
	 default: begin // OKAY
		     response.data   = response.data;
		  end
      endcase
      do_decr.send;
      if (value.status != SPLIT && value.status != RETRY)
	 length_fifo.deq;
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

   interface AhbXtorMaster fabric;
      interface AhbMaster bus = ifc.bus;
      interface AhbMasterArbiter arbiter;
	 method hbusreq = (req_wire || req_reg || ebt_mode != RUN);
	 method hlock   = lock_reg;
	 method hgrant  = grant_wire._write;
      endinterface
   endinterface


endmodule

function Bool assertLock (RequestDescriptor#(`TLM_PRM) desc);
   let burst = getAhbBurst(desc);
   let length = desc.b_length;
   return (desc.lock != NORMAL) || (burst == SINGLE && length != 0);
endfunction

module mkAHBMasterDummy (AhbXtorMaster#(`TLM_PRM));

   function Action noop (a ignore);
      return noAction;
   endfunction

   interface AhbMaster bus;
      // Outputs
      method haddr  = 0;
      method hwdata = 'h234;
      method hwrite = READ;
      method htrans = IDLE;
      method hburst = ?;
      method hsize  = ?;
      method hprot  = unpack(0);

      // Inputs
      method hrdata = noop;
      method hready = noop;
      method hresp  = noop;
   endinterface

   interface AhbMasterArbiter arbiter;
      method hbusreq = False;
      method hlock   = False;
      method hgrant  = noop;
   endinterface

endmodule

endpackage
