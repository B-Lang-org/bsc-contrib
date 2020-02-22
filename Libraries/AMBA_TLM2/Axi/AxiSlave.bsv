// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AxiSlave;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import AxiDefines::*;
import Bus::*;
import FIFO::*;
import FIFOF::*;
import FShow::*;
import GetPut::*;
import SpecialFIFOs::*;
import TLM2::*;

`include "Axi.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAxiRdSlaveIFC#(BusRecv#(AxiAddrCmd#(`TLM_PRM)) request_addr,
			BusSend#(AxiRdResp#(`TLM_PRM))  response) (AxiRdSlave#(`TLM_PRM));

   Wire#(AxiId#(`TLM_PRM))   arID_wire    <- mkBypassWire;
   Wire#(AxiLen)               arLEN_wire   <- mkBypassWire;
   Wire#(AxiSize)              arSIZE_wire  <- mkBypassWire;
   Wire#(AxiBurst)             arBURST_wire <- mkBypassWire;
   Wire#(AxiLock)              arLOCK_wire  <- mkBypassWire;
   Wire#(AxiCache)             arCACHE_wire <- mkBypassWire;
   Wire#(AxiProt)              arPROT_wire  <- mkBypassWire;
   Wire#(AxiAddr#(`TLM_PRM)) arADDR_wire  <- mkBypassWire;

   rule every;
      let addr_value = AxiAddrCmd {id:    arID_wire,
				   len:   arLEN_wire,
				   size:  arSIZE_wire,
				   burst: arBURST_wire,
				   lock:  arLOCK_wire,
				   cache: arCACHE_wire,
				   prot:  arPROT_wire,
				   addr:  arADDR_wire};
      request_addr.data(addr_value);
   endrule

   // Address Inputs
   method arID     = arID_wire._write;
   method arADDR   = arADDR_wire._write;
   method arLEN    = arLEN_wire._write;
   method arSIZE   = arSIZE_wire._write;
   method arBURST  = arBURST_wire._write;
   method arLOCK   = arLOCK_wire._write;
   method arCACHE  = arCACHE_wire._write;
   method arPROT   = arPROT_wire._write;
   method arVALID  = request_addr.valid;

   // Address Outputs
   method arREADY  = request_addr.ready;

   // Response Inputs
   method rREADY  = response.ready;

   // Response Outputs
   method rID     = response.data.id;
   method rDATA   = response.data.data;
   method rRESP   = response.data.resp;
   method rLAST   = response.data.last;
   method rVALID  = response.valid;

endmodule

module mkAxiWrSlaveIFC#(BusRecv#(AxiAddrCmd#(`TLM_PRM)) request_addr,
			BusRecv#(AxiWrData#(`TLM_PRM))  request_data,
			BusSend#(AxiWrResp#(`TLM_PRM))  response) (AxiWrSlave#(`TLM_PRM));

   Wire#(AxiId#(`TLM_PRM))   awID_wire    <- mkBypassWire;
   Wire#(AxiLen)               awLEN_wire   <- mkBypassWire;
   Wire#(AxiSize)              awSIZE_wire  <- mkBypassWire;
   Wire#(AxiBurst)             awBURST_wire <- mkBypassWire;
   Wire#(AxiLock)              awLOCK_wire  <- mkBypassWire;
   Wire#(AxiCache)             awCACHE_wire <- mkBypassWire;
   Wire#(AxiProt)              awPROT_wire  <- mkBypassWire;
   Wire#(AxiAddr#(`TLM_PRM)) awADDR_wire  <- mkBypassWire;

   Wire#(AxiId#(`TLM_PRM))     wID_wire     <- mkBypassWire;
   Wire#(AxiData#(`TLM_PRM))   wDATA_wire   <- mkBypassWire;
   Wire#(AxiByteEn#(`TLM_PRM)) wSTRB_wire   <- mkBypassWire;
   Wire#(Bool)                   wLAST_wire   <- mkBypassWire;


   rule every;
      let addr_value = AxiAddrCmd {id:    awID_wire,
				   len:   awLEN_wire,
				   size:  awSIZE_wire,
				   burst: awBURST_wire,
				   lock:  awLOCK_wire,
				   cache: awCACHE_wire,
				   prot:  awPROT_wire,
				   addr:  awADDR_wire};
      request_addr.data(addr_value);
      let data_value = AxiWrData {id:    wID_wire,
				  data:  wDATA_wire,
				  strb:  wSTRB_wire,
				  last:  wLAST_wire};
      request_data.data(data_value);
   endrule

   // Address Inputs
   method awID     = awID_wire._write;
   method awADDR   = awADDR_wire._write;
   method awLEN    = awLEN_wire._write;
   method awSIZE   = awSIZE_wire._write;
   method awBURST  = awBURST_wire._write;
   method awLOCK   = awLOCK_wire._write;
   method awCACHE  = awCACHE_wire._write;
   method awPROT   = awPROT_wire._write;
   method awVALID  = request_addr.valid;

   // Address Outputs
   method awREADY  = request_addr.ready;

   // Data Inputs
   method wID      = wID_wire._write;
   method wDATA    = wDATA_wire._write;
   method wSTRB    = wSTRB_wire._write;
   method wLAST    = wLAST_wire._write;
   method wVALID   = request_data.valid;

   // Data Outputs
   method wREADY   = request_data.ready;

   // Response Inputs
   method bREADY  = response.ready;

   // Response Outputs
   method bID     = response.data.id;
   method bRESP   = response.data.resp;
   method bVALID  = response.valid;

endmodule

module mkAxiRdBusSlaveIFC#(AxiRdSlave#(`TLM_PRM) ifc) (AxiRdBusSlave#(`TLM_PRM));

   interface BusRecv addr;
      method Action data(AxiAddrCmd#(`TLM_PRM) value);
	 ifc.arID(value.id);
	 ifc.arADDR(value.addr);
	 ifc.arLEN(value.len);
	 ifc.arSIZE(value.size);
	 ifc.arBURST(value.burst);
	 ifc.arLOCK(value.lock);
	 ifc.arCACHE(value.cache);
	 ifc.arPROT(value.prot);
      endmethod
      method valid = ifc.arVALID;
      method ready = ifc.arREADY;
   endinterface
   interface BusSend resp;
      method AxiRdResp#(`TLM_PRM) data;
	 let resp = AxiRdResp {id:    ifc.rID,
			       data: ifc.rDATA,
			       resp: ifc.rRESP,
			       last: ifc.rLAST};
	 return resp;
      endmethod
      method valid = ifc.rVALID;
      method ready = ifc.rREADY;
   endinterface

endmodule

module mkAxiWrBusSlaveIFC#(AxiWrSlave#(`TLM_PRM) ifc) (AxiWrBusSlave#(`TLM_PRM));

   interface BusRecv addr;
      method Action data(AxiAddrCmd#(`TLM_PRM) value);
	 ifc.awID(value.id);
	 ifc.awADDR(value.addr);
	 ifc.awLEN(value.len);
	 ifc.awSIZE(value.size);
	 ifc.awBURST(value.burst);
	 ifc.awLOCK(value.lock);
	 ifc.awCACHE(value.cache);
	 ifc.awPROT(value.prot);
      endmethod
      method valid = ifc.awVALID;
      method ready = ifc.awREADY;
   endinterface
   interface BusRecv data;
      method Action data(AxiWrData#(`TLM_PRM) value);
	 ifc.wID(value.id);
	 ifc.wDATA(value.data);
	 ifc.wSTRB(value.strb);
	 ifc.wLAST(value.last);
      endmethod
      method valid = ifc.wVALID;
      method ready = ifc.wREADY;
   endinterface
   interface BusSend resp;
      method AxiWrResp#(`TLM_PRM) data;
	 let resp = AxiWrResp {id:   ifc.bID,
			       resp: ifc.bRESP};
	 return resp;
      endmethod
      method valid = ifc.bVALID;
      method ready = ifc.bREADY;
   endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAxiRdSlaveStd#(function Bool addr_match(AxiAddr#(`AXI_PRM_STD) addr))
			   (AxiRdSlaveXActorIFC#(`AXI_XTR_STD));

   let _ifc <- mkAxiRdSlaveSynthStd;

   interface TLMSendIFC tlm = _ifc.tlm;
   interface AxiRdFabricSlave fabric;
      interface AxiRdSlave bus = _ifc.fabric.bus;
      method addrMatch = addr_match;
   endinterface
endmodule

module mkAxiRdSlave#(Integer max_flight, function Bool addr_match(AxiAddr#(`TLM_PRM) addr))
			(AxiRdSlaveXActorIFC#(`TLM_XTR))
   provisos (TLMRequestTC#(req_t, `TLM_PRM),
	     TLMResponseTC#(resp_t, `TLM_PRM),
	     Bits#(req_t, s0),
	     Bits#(resp_t, s1),
	     Bits#(cstm_type, s2),
	     AxiConvert#(AxiCustom, cstm_type));

   let _ifc <- mkAxiRdSlaveSynth(max_flight);

   interface TLMSendIFC tlm = _ifc.tlm;
   interface AxiRdFabricSlave fabric;
      interface AxiRdSlave bus = _ifc.fabric.bus;
      method addrMatch = addr_match;
   endinterface
endmodule


(* synthesize *)
module mkAxiRdSlaveSynthStd (AxiRdSlaveXActorIFC#(`AXI_XTR_STD));
   let _ifc <- mkAxiRdSlaveSynth(1);
   return _ifc;
endmodule


module mkAxiRdSlaveSynth#(Integer max_flight) (AxiRdSlaveXActorIFC#(`TLM_XTR))
   provisos(TLMRequestTC#(req_t, `TLM_PRM),
	    TLMResponseTC#(resp_t, `TLM_PRM),
	    Bits#(req_t, s0),
	    Bits#(resp_t, s1),
	    Bits#(cstm_type, s2),
	    Add#(SizeOf#(AxiLen), 1, n),
	    AxiConvert#(AxiCustom, cstm_type)
	    );


   BusReceiver#(AxiAddrCmd#(`TLM_PRM)) rd_addr_fifo <- mkBypassBusReceiver;
   BusSender#(AxiRdResp#(`TLM_PRM))    rd_resp_fifo <- mkBypassBusSender(unpack(0));

   FIFO#(req_t)        fifo_tx      <- mkBypassFIFO;
   FIFO#(resp_t)       fifo_rx      <- mkBypassFIFO;

   FIFO#(Bool)        fifo_buffer   <- mkSizedFIFO(max_flight + 1);

   Reg#(Bit#(n))                         count        <- mkReg(0);
   Reg#(RequestDescriptor#(`TLM_PRM))  desc_prev    <- mkReg(?);

   let _ifc <- mkAxiRdSlaveIFC(rd_addr_fifo.in, rd_resp_fifo.out);

   rule grab_addr (count == 0);
      let value = rd_addr_fifo.out.first;
      TLMBurstSize#(`TLM_PRM) zz = fromAxiSize(value.size);
      Bit#(n) remaining = {0, value.len} + 1;
      let desc = fromAxiAddrCmd(value);
      desc.command = READ;
      count <= remaining;
      desc_prev <= desc;
      rd_addr_fifo.out.deq;
   endrule

   rule do_read (count > 0);
      let remaining = count - 1;
      let last = (remaining == 0);
      count <= remaining;
      let desc = desc_prev;
      desc_prev <= incrTLMAddr(desc);
      desc.burst_length = 1;
      fifo_tx.enq(fromTLMRequest(tagged Descriptor desc));
      fifo_buffer.enq(last);
   endrule

   rule grap_tlm_response;
      let response =  toTLMResponse(fifo_rx.first);
      let id = response.transaction_id;
      let last = fifo_buffer.first;
      fifo_rx.deq;
      fifo_buffer.deq;
      AxiRdResp#(`TLM_PRM) axi_response = unpack(0);
      axi_response.id = getAxiId(id);
      axi_response.resp = getAxiResp(response.status);
      axi_response.data = response.data;
      axi_response.last = last;
      rd_resp_fifo.in.enq(axi_response);
   endrule

   interface TLMSendIFC tlm;
      interface Get tx = toGet(fifo_tx);
      interface Put rx = toPut(fifo_rx);
   endinterface

   interface AxiRdFabricSlave fabric;
      interface AxiRdSlave bus = _ifc;
      method Bool addrMatch(AxiAddr#(`TLM_PRM) value) = False;
   endinterface

endmodule


////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAxiWrSlaveStd#(function Bool addr_match(AxiAddr#(`AXI_PRM_STD) addr))
			   (AxiWrSlaveXActorIFC#(`AXI_XTR_STD));

   let _ifc <- mkAxiWrSlaveSynthStd;

   interface TLMSendIFC tlm = _ifc.tlm;
   interface AxiWrFabricSlave fabric;
      interface AxiWrSlave bus = _ifc.fabric.bus;
      method addrMatch = addr_match;
   endinterface
endmodule

module mkAxiWrSlave#(Integer max_flight, function Bool addr_match(AxiAddr#(`TLM_PRM) addr))
			(AxiWrSlaveXActorIFC#(`TLM_XTR))
   provisos(TLMRequestTC#(req_t, `TLM_PRM),
	    TLMResponseTC#(resp_t, `TLM_PRM),
	    Bits#(req_t, s0),
	    Bits#(resp_t, s1),
	    Bits#(cstm_type, s2),
	    AxiConvert#(AxiCustom, cstm_type));

   let _ifc <- mkAxiWrSlaveSynth(max_flight);

   interface TLMSendIFC tlm = _ifc.tlm;
   interface AxiWrFabricSlave fabric;
      interface AxiWrSlave bus = _ifc.fabric.bus;
      method addrMatch = addr_match;
   endinterface
endmodule

(* synthesize *)
module mkAxiWrSlaveSynthStd (AxiWrSlaveXActorIFC#(`AXI_XTR_STD));
   let _ifc <- mkAxiWrSlaveSynth(1);
   return _ifc;
endmodule


module mkAxiWrSlaveSynth#(Integer max_flight) (AxiWrSlaveXActorIFC#(`TLM_XTR))
   provisos(TLMRequestTC#(req_t, `TLM_PRM),
	    TLMResponseTC#(resp_t, `TLM_PRM),
	    Bits#(req_t, s0),
	    Bits#(resp_t, s1),
	    Bits#(cstm_type, s2),
	    Add#(SizeOf#(AxiLen), 1, n),
	    AxiConvert#(AxiCustom, cstm_type));

   BusReceiver#(AxiAddrCmd#(`TLM_PRM)) wr_addr_fifo <- mkBypassBusReceiver;
   BusReceiver#(AxiWrData#(`TLM_PRM))  wr_data_fifo <- mkBypassBusReceiver;
   let _ifc <- mkAxiWrSlaveSynthP(max_flight, wr_addr_fifo, wr_data_fifo);
   return _ifc;

endmodule

module mkAxiWrSlaveSynthP#(Integer max_flight,
			   BusReceiver#(AxiAddrCmd#(`TLM_PRM)) wr_addr_fifo,
			   BusReceiver#(AxiWrData#(`TLM_PRM))  wr_data_fifo) (AxiWrSlaveXActorIFC#(`TLM_XTR))
   provisos(TLMRequestTC#(req_t, `TLM_PRM),
	    TLMResponseTC#(resp_t, `TLM_PRM),
	    Bits#(req_t, s0),
	    Bits#(resp_t, s1),
	    Bits#(cstm_type, s2),
	    Add#(SizeOf#(AxiLen), 1, n),
	    AxiConvert#(AxiCustom, cstm_type));

   BusSender#(AxiWrResp#(`TLM_PRM))    wr_resp_fifo <- mkBusSender(unpack(0));

   FIFO#(req_t)        fifo_tx      <- mkBypassFIFO;
   FIFO#(resp_t)       fifo_rx      <- mkBypassFIFO;

   FIFO#(Maybe#(AxiId#(`TLM_PRM)))    fifo_buffer  <- mkSizedFIFO(max_flight + 1);

   Reg#(Bit#(n))                       count        <- mkReg(0);
   Reg#(RequestDescriptor#(`TLM_PRM))  desc_prev    <- mkReg(?);

   let _ifc <- mkAxiWrSlaveIFC(wr_addr_fifo.in, wr_data_fifo.in, wr_resp_fifo.out);

   rule grab_addr (count == 0);
      let value  = wr_addr_fifo.out.first;
      let dvalue = wr_data_fifo.out.first;
      Bit#(n) remaining = {0, value.len};
      let desc = fromAxiAddrCmd(value);
      desc.command = WRITE;
      desc.data = dvalue.data;
      desc.byte_enable = dvalue.strb;
      count <= remaining;
      desc_prev <= incrTLMAddr(desc);
      wr_addr_fifo.out.deq;
      wr_data_fifo.out.deq;
      let token = (dvalue.last) ? (tagged Valid dvalue.id) : tagged Invalid;
      desc.burst_length = 1;
      fifo_tx.enq(fromTLMRequest(tagged Descriptor desc));
      fifo_buffer.enq(token);
   endrule

   rule grab_data (count > 0);
      let value = wr_data_fifo.out.first;
      let remaining =  count - 1;
      count <= remaining;
      let desc = desc_prev;
      desc.data = value.data;
      desc.byte_enable = value.strb;
      desc_prev <= incrTLMAddr(desc);
      wr_data_fifo.out.deq;
      let token = (value.last) ? (tagged Valid value.id) : tagged Invalid;
      desc.burst_length = 1;
      fifo_tx.enq(fromTLMRequest(tagged Descriptor desc));
      fifo_buffer.enq(token);
   endrule

   rule grap_tlm_response (fifo_buffer.first matches tagged Invalid);
      fifo_buffer.deq;
      fifo_rx.deq;
   endrule
/* -----\/----- EXCLUDED -----\/-----

   rule send_axi_response (fifo_buffer.first matches tagged Valid .id);
      AxiWrResp#(`TLM_PRM) resp = unpack(0);
      resp.id = id;
      resp.resp = OKAY;
      wr_resp_fifo.in.enq(resp);
      fifo_buffer.deq;
      fifo_rx.deq;
   endrule
 -----/\----- EXCLUDED -----/\----- */

   rule send_axi_response (fifo_buffer.first matches tagged Valid .id);
      let response = toTLMResponse(fifo_rx.first);
      fifo_rx.deq;
      fifo_buffer.deq;
      AxiWrResp#(`TLM_PRM) axi_response = unpack(0);
      axi_response.id = id;
      axi_response.resp = getAxiResp(response.status);
      wr_resp_fifo.in.enq(axi_response);
   endrule

   interface TLMSendIFC tlm;
      interface Get tx = toGet(fifo_tx);
      interface Put rx = toPut(fifo_rx);
   endinterface

   interface AxiWrFabricSlave fabric;
      interface AxiWrSlave bus = _ifc;
      method Bool addrMatch(AxiAddr#(`TLM_PRM) value) = False;
   endinterface

endmodule

module mkAxiRdSlaveDummy(AxiRdFabricSlave#(`TLM_PRM));

   Reg#(Bool)              rARValid      <- mkReg(False);
   Reg#(AxiId#(`TLM_PRM))  rARId         <- mkRegU;

   Wire#(Bool)             wARSet        <- mkBypassWire;
   Wire#(Bool)             wARReset      <- mkBypassWire;

   rule valid_toggle;
      if (wARSet)
	 rARValid <= True;
      else if (wARReset && rARValid)
	 rARValid <= False;
   endrule

   function Action nop(a ignore);
      return noAction;
   endfunction

   interface AxiRdSlave bus;
      method arID     = rARId._write;
      method arADDR   = nop;
      method arLEN    = nop;
      method arSIZE   = nop;
      method arBURST  = nop;
      method arLOCK   = nop;
      method arCACHE  = nop;
      method arPROT   = nop;
      method arVALID  = wARSet._write;
      method arREADY  = True;

      method rID      = rARId;
      method rDATA    = 'h567;
      method rRESP    = DECERR;
      method rLAST    = True;
      method rVALID   = rARValid;
      method rREADY   = wARReset._write;
   endinterface

   method addrMatch(value);
      return False;
   endmethod

endmodule


module mkAxiWrSlaveDummy(AxiWrFabricSlave#(`TLM_PRM));

   Reg#(AxiId#(`TLM_PRM))  rAWId         <- mkRegU;
   Reg#(Bool)              rwLast        <- mkReg(False);

   Wire#(Bool)             awValid       <- mkBypassWire;
   Wire#(Bool)             wValid        <- mkBypassWire;
   Reg#(Bool)              rBReady       <- mkReg(False);

   function Action nop(a ignore);
      return noAction;
   endfunction

   interface AxiWrSlave bus;
      method awID     = rAWId._write;
      method awADDR   = nop;
      method awLEN    = nop;
      method awSIZE   = nop;
      method awBURST  = nop;
      method awLOCK   = nop;
      method awCACHE  = nop;
      method awPROT   = nop;
      method awVALID  = awValid._write;
      method awREADY  = True;
      method wID      = nop;
      method wDATA    = nop;
      method wSTRB    = nop;
      method wLAST    = rwLast._write;
      method wVALID   = wValid._write;
      method wREADY   = True;

      method bREADY   = rBReady._write;
      method bID      = rAWId;
      method bRESP    = DECERR;
      method bVALID   = True;
   endinterface

   method addrMatch(value);
      return False;
   endmethod

endmodule


endpackage
