// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AxiMaster;


////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import AxiDefines::*;
import Bus::*;
import FIFO::*;
import GetPut::*;
import Probe::*;
import SpecialFIFOs::*;
import TLM2::*;
import BUtils::*;
import Vector::*;
import DefaultValue::*;

`include "Axi.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAxiRdMasterIFC#(BusSend#(AxiAddrCmd#(`TLM_PRM))  request_addr,
			 BusRecv#(AxiRdResp#(`TLM_PRM))   response) (AxiRdMaster#(`TLM_PRM));

   Wire#(AxiId#(`TLM_PRM))   rID_wire   <- mkBypassWire;
   Wire#(AxiData#(`TLM_PRM)) rDATA_wire <- mkBypassWire;
   Wire#(AxiResp)              rRESP_wire <- mkBypassWire;
   Wire#(Bool)                 rLAST_wire <- mkBypassWire;

   rule every ;
      let value = AxiRdResp {id:   rID_wire,
			     data: rDATA_wire,
			     resp: rRESP_wire,
			     last: rLAST_wire};
      response.data(value);
   endrule

   // Address Outputs
   method arID    = request_addr.data.id;
   method arADDR  = request_addr.data.addr;
   method arLEN   = request_addr.data.len;
   method arSIZE  = request_addr.data.size;
   method arBURST = request_addr.data.burst;
   method arLOCK  = request_addr.data.lock;
   method arCACHE = request_addr.data.cache;
   method arPROT  = request_addr.data.prot;
   method arVALID = request_addr.valid;

   // Address Inputs
   method arREADY = request_addr.ready;

   // Response Outputs
   method rREADY  = response.ready;

   // Response Inputs
   method rID     = rID_wire._write;
   method rDATA   = rDATA_wire._write;
   method rRESP   = rRESP_wire._write;
   method rLAST   = rLAST_wire._write;
   method rVALID  = response.valid;

endmodule

module mkAxiWrMasterIFC#(BusSend#(AxiAddrCmd#(`TLM_PRM))  request_addr,
			 BusSend#(AxiWrData#(`TLM_PRM))   request_data,
			 BusRecv#(AxiWrResp#(`TLM_PRM))   response) (AxiWrMaster#(`TLM_PRM));

   Wire#(AxiId#(`TLM_PRM)) bID_wire    <- mkBypassWire;
   Wire#(AxiResp)            bRESP_wire  <- mkBypassWire;

   rule every ;
      let value = AxiWrResp { id: bID_wire, resp: bRESP_wire};
      response.data(value);
   endrule

   // Address Outputs
   method awID    = request_addr.data.id;
   method awADDR  = request_addr.data.addr;
   method awLEN   = request_addr.data.len;
   method awSIZE  = request_addr.data.size;
   method awBURST = request_addr.data.burst;
   method awLOCK  = request_addr.data.lock;
   method awCACHE = request_addr.data.cache;
   method awPROT  = request_addr.data.prot;
   method awVALID = request_addr.valid;

   // Address Inputs
   method awREADY = request_addr.ready;

   // Data Outputs
   method wID     = request_data.data.id;
   method wDATA   = request_data.data.data;
   method wSTRB   = request_data.data.strb;
   method wLAST   = request_data.data.last;
   method wVALID  = request_data.valid;

   // Data Inputs
   method wREADY  = request_data.ready;

   // Response Outputs
   method bREADY  = response.ready;

   // Response Inputs
   method bID     = bID_wire._write;
   method bRESP   = bRESP_wire._write;
   method bVALID  = response.valid;

endmodule

module mkAxiRdBusMasterIFC#(AxiRdMaster#(`TLM_PRM) ifc) (AxiRdBusMaster#(`TLM_PRM));

   interface BusSend addr;
      method AxiAddrCmd#(`TLM_PRM) data;
	 let addr =  AxiAddrCmd {id:    ifc.arID,
				 len:   ifc.arLEN,
				 size:  ifc.arSIZE,
				 burst: ifc.arBURST,
				 lock:  ifc.arLOCK,
				 cache: ifc.arCACHE,
				 prot:  ifc.arPROT,
				 addr:  ifc.arADDR};
	 return addr;
      endmethod
      method valid = ifc.arVALID;
      method ready = ifc.arREADY;
   endinterface
   interface BusRecv resp;
      method Action data(AxiRdResp#(`TLM_PRM) value);
	 ifc.rID(value.id);
	 ifc.rDATA(value.data);
	 ifc.rRESP(value.resp);
	 ifc.rLAST(value.last);
      endmethod
      method valid = ifc.rVALID;
      method ready = ifc.rREADY;
   endinterface

endmodule

module mkAxiWrBusMasterIFC#(AxiWrMaster#(`TLM_PRM) ifc) (AxiWrBusMaster#(`TLM_PRM));

   interface BusSend addr;
      method AxiAddrCmd#(`TLM_PRM) data;
	 let addr =  AxiAddrCmd {id:    ifc.awID,
				 len:   ifc.awLEN,
				 size:  ifc.awSIZE,
				 burst: ifc.awBURST,
				 lock:  ifc.awLOCK,
				 cache: ifc.awCACHE,
				 prot:  ifc.awPROT,
				 addr:  ifc.awADDR};
	 return addr;
      endmethod
      method valid = ifc.awVALID;
      method ready = ifc.awREADY;
   endinterface
   interface BusSend data;
      method AxiWrData#(`TLM_PRM) data;
	 let out = AxiWrData {id:   ifc.wID,
			      data: ifc.wDATA,
			      strb: ifc.wSTRB,
			      last: ifc.wLAST};
	 return out;
      endmethod
      method valid = ifc.wVALID;
      method ready = ifc.wREADY;
   endinterface
   interface BusRecv resp;
      method Action data(AxiWrResp#(`TLM_PRM) value);
	 ifc.bID(value.id);
	 ifc.bRESP(value.resp);
      endmethod
      method valid = ifc.bVALID;
      method ready = ifc.bREADY;
   endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

(* synthesize *)
module mkAxiRdMasterStd (AxiRdMasterXActorIFC#(`AXI_XTR_STD));
   let _ifc <- mkAxiRdMaster;
   return _ifc;
endmodule

module mkAxiRdMaster (AxiRdMasterXActorIFC#(`TLM_XTR))
   provisos(Bits#(req_t, s0),
	    Bits#(resp_t, s1),
	    TLMRequestTC#(req_t, `TLM_PRM),
	    TLMResponseTC#(resp_t, `TLM_PRM),
	    DefaultValue#(cstm_type),
	    AxiConvert#(AxiProt, cstm_type),
	    AxiConvert#(AxiCache, cstm_type),
	    AxiConvert#(AxiLock, cstm_type)
	    );

   BusSender#(AxiAddrCmd#(`TLM_PRM))  rd_addr_fifo <- mkBypassBusSender(unpack(0));
   BusReceiver#(AxiRdResp#(`TLM_PRM)) rd_resp_fifo <- mkBypassBusReceiver;

   FIFO#(req_t)                       fifo_rx <- mkBypassFIFO;
   FIFO#(resp_t)                      fifo_tx <- mkBypassFIFO;

   Reg#(TLMUInt#(`TLM_PRM))      count   <- mkReg(0);

   let _ifc <- mkAxiRdMasterIFC(rd_addr_fifo.out, rd_resp_fifo.in);

   let rx_first = toTLMRequest(fifo_rx.first);

   rule start_read (rx_first matches tagged Descriptor .d &&&
		    d.command matches READ);
      let addr_cmd = getAxiAddrCmd(d);
      rd_addr_fifo.in.enq(addr_cmd);
      fifo_rx.deq;
   endrule

   rule grab_response;
      let axi_response = rd_resp_fifo.out.first;
      TLMResponse#(`TLM_PRM) response = defaultValue ;
      response.command = READ;
      response.transaction_id = fromAxiId(axi_response.id);
      response.status = fromAxiResp(axi_response.resp);
      response.data = axi_response.data;
      fifo_tx.enq(fromTLMResponse(response));
      rd_resp_fifo.out.deq;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Error cases:
   ////////////////////////////////////////////////////////////////////////////////
   (* preempts = "start_write, grab_response" *)
   rule start_write (rx_first matches tagged Descriptor .d
		     &&& d.command matches WRITE);
      $display("(%0d) ERROR: AxiRdMaster cannot handle WRITE ops!", $time);
      fifo_rx.deq;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   ///
   ////////////////////////////////////////////////////////////////////////////////

   interface TLMRecvIFC tlm;
      interface Get tx = toGet(fifo_tx);
      interface Put rx = toPut(fifo_rx);
   endinterface

   interface AxiRdFabricMaster fabric;
      interface AxiRdMaster bus = _ifc;
   endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

(* synthesize *)
module mkAxiWrMasterStd (AxiWrMasterXActorIFC#(`AXI_XTR_STD));
   let _ifc <- mkAxiWrMaster;
   return _ifc;
endmodule

module mkAxiWrMaster (AxiWrMasterXActorIFC#(`TLM_XTR))
   provisos(Bits#(req_t, s0),
	    Bits#(resp_t, s1),
	    TLMRequestTC#(req_t, `TLM_PRM),
	    TLMResponseTC#(resp_t, `TLM_PRM),
	    DefaultValue#(cstm_type),
	    Bits#(cstm_type, s2),
	    AxiConvert#(AxiProt, cstm_type),
	    AxiConvert#(AxiCache, cstm_type),
	    AxiConvert#(AxiLock, cstm_type)
	    );

   BusSender#(AxiAddrCmd#(`TLM_PRM)) wr_addr_fifo <- mkBypassBusSender(unpack(0));
   BusSender#(AxiWrData#(`TLM_PRM))  wr_data_fifo <- mkBypassBusSender(unpack(0));
   let _ifc <- mkAxiWrMasterP(wr_addr_fifo, wr_data_fifo);
   return _ifc;

endmodule

module mkAxiWrMasterP#(BusSender#(AxiAddrCmd#(`TLM_PRM)) wr_addr_fifo,
		       BusSender#(AxiWrData#(`TLM_PRM))  wr_data_fifo) (AxiWrMasterXActorIFC#(`TLM_XTR))
   provisos(Bits#(req_t, s0),
	    Bits#(resp_t, s1),
	    TLMRequestTC#(req_t, `TLM_PRM),
	    TLMResponseTC#(resp_t, `TLM_PRM),
	    DefaultValue#(cstm_type),
	    Bits#(cstm_type, s2),
	    AxiConvert#(AxiProt, cstm_type),
	    AxiConvert#(AxiCache, cstm_type),
	    AxiConvert#(AxiLock, cstm_type)
	    );

   BusReceiver#(AxiWrResp#(`TLM_PRM))   wr_resp_fifo <- mkBypassBusReceiver;

   FIFO#(req_t)                         fifo_rx      <- mkBypassFIFO;
   FIFO#(resp_t)                        fifo_tx      <- mkBypassFIFO;

   Reg#(AxiWrData#(`TLM_PRM))           saved_data   <- mkReg(?);
   Reg#(TLMUInt#(`TLM_PRM))             count        <- mkReg(0);
   Reg#(RequestDescriptor#(`TLM_PRM))   descriptor   <- mkReg(?);

   let _ifc <- mkAxiWrMasterIFC(wr_addr_fifo.out, wr_data_fifo.out, wr_resp_fifo.in);

   let rx_first = toTLMRequest(fifo_rx.first);

   rule start_write (rx_first matches tagged Descriptor .d &&&
		     d.command matches WRITE);
      let addr_cmd = getAxiAddrCmd(d);
      let wr_data  = getFirstAxiWrData(d);
      saved_data <= wr_data;
      count <= getTLMCycleCount(d) - 1;
      wr_addr_fifo.in.enq(addr_cmd);
      wr_data_fifo.in.enq(wr_data);
      fifo_rx.deq;
      descriptor <= incrTLMAddr(d);
   endrule

   rule data_write (rx_first matches tagged Data .d);
      let wr_data = saved_data;
      wr_data.data = d.data;
      wr_data.last = (count == 1);
      wr_data.strb = getAxiByteEn(descriptor);
      saved_data <= wr_data;
      count <= count - 1;
      wr_data_fifo.in.enq(wr_data);
      fifo_rx.deq;
      descriptor <= incrTLMAddr(descriptor);
   endrule

   rule grab_response;
      let axi_response = wr_resp_fifo.out.first;
      TLMResponse#(`TLM_PRM) response = defaultValue;
      response.command = WRITE;
      response.transaction_id = fromAxiId(axi_response.id);
      response.status = fromAxiResp(axi_response.resp);
      fifo_tx.enq(fromTLMResponse(response));
      wr_resp_fifo.out.deq;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Error cases:
   ////////////////////////////////////////////////////////////////////////////////
   (* preempts = "start_read, grab_response" *)
   rule start_read (rx_first matches tagged Descriptor .d &&&
		    d.command matches READ);
      $display("(%0d) ERROR: AxiWrMaster cannot handle READ OPS!", $time);
      fifo_rx.deq;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   ///
   ////////////////////////////////////////////////////////////////////////////////

   interface TLMRecvIFC tlm;
      interface Get tx = toGet(fifo_tx);
      interface Put rx = toPut(fifo_rx);
   endinterface

   interface AxiWrFabricMaster fabric;
      interface AxiWrMaster bus = _ifc;
   endinterface

endmodule

endpackage
