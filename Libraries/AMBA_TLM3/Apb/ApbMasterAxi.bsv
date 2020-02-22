////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : ApbMasterAxi.bsv
//  Description   : Axi/Apb bridge
////////////////////////////////////////////////////////////////////////////////
package ApbMasterAxi;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////

import Axi               ::*;
import ApbDefines        ::*;
import ApbSlave          ::*;
import BUtils            ::*;

import TLM3               ::*;
import DefaultValue      ::*;
import FIFO              ::*;
import FIFOF             ::*;
import SpecialFIFOs      ::*;
import Connectable       ::*;
import GetPut            ::*;
import Counter           ::*;

`include "TLM.defines"

`define TLMM_RR_DCL      type mreq_t, type mresp_t
`define TLMS_RR_DCL      type sreq_t, type sresp_t

`define TLMM_RR          mreq_t, mresp_t
`define TLMS_RR          sreq_t, sresp_t

`define TLMM_PRM_DCL     numeric type mid_size, \
                         numeric type maddr_size, \
                         numeric type mdata_size, \
                         numeric type muint_size, \
                         type mcstm_type
`define TLMS_PRM_DCL     numeric type sid_size, \
                         numeric type saddr_size, \
                         numeric type sdata_size, \
                         numeric type suint_size, \
                         type scstm_type

`define TLMM_PRM         mid_size, maddr_size, mdata_size, muint_size, mcstm_type
`define TLMS_PRM         sid_size, saddr_size, sdata_size, suint_size, scstm_type

`define TLMM_XTR_DCL     `TLMM_RR_DCL, `TLMM_PRM_DCL
`define TLMS_XTR_DCL     `TLMS_RR_DCL, `TLMS_PRM_DCL

`define TLMM_XTR         `TLMM_RR, `TLMM_PRM
`define TLMS_XTR         `TLMS_RR, `TLMS_PRM

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
interface AxiToApb#(`TLMM_XTR_DCL, `TLMS_XTR_DCL);
   interface AxiRdFabricSlave#(`TLMM_PRM) axi_rd;
   interface AxiWrFabricSlave#(`TLMM_PRM) axi_wr;
   interface ApbXtorMaster#(`TLMS_PRM)    apb;
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkAxiToApb#(  parameter UInt#(32) max_in_flight
		   , parameter ApbAddr#(`TLMS_PRM) idle_addr
		   , function Bool addr_match(AxiAddr#(`TLMM_PRM) addr)
		   )
		   (AxiToApb#(`TLMM_XTR, `TLMS_XTR))
   provisos(  Bits#(mreq_t, s0)
	    , Bits#(mresp_t, s1)
	    , Bits#(sreq_t, s2)
	    , Bits#(sresp_t, s3)
	    , Bits#(mcstm_type, s4)
	    , TLMRequestTC#(mreq_t, `TLMM_PRM)
	    , TLMResponseTC#(mresp_t, `TLMM_PRM)
	    , DefaultValue#(TLMResponse#(`TLMM_PRM))
	    , Add#(sdata_size, s5, mdata_size)
	    , Add#(TDiv#(sdata_size,8), s6, TDiv#(mdata_size,8))
	    , Mul#(sdata_size, s7, mdata_size)
	    , Div#(mdata_size, s7, sdata_size)
	    , Add#(maddr_size, 0, saddr_size)
            , TLMResponseTC#(mresp_t, mid_size, saddr_size, mdata_size,
    muint_size, mcstm_type)
	    );

   ////////////////////////////////////////////////////////////////////////////////
   /// Axi Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   AxiRdSlaveXActorIFC#(`TLMM_XTR)           axi_read            <- mkAxiRdSlave(addr_match );
   AxiWrSlaveXActorIFC#(`TLMM_XTR)           axi_write           <- mkAxiWrSlave(addr_match );

   FIFOF#(mreq_t)                            fAxiReqs            <- mkBypassFIFOF;

   ////////////////////////////////////////////////////////////////////////////////
   /// Apb Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Reg#(ApbState)                            rState              <- mkReg(IDLE);

   Reg#(RequestDescriptor#(`TLMM_PRM))       rDescriptor         <- mkRegU;
   Counter#(SizeOf#(TLMBurstLength))         rCount              <- mkCounter(0);

   Reg#(Bool)                                rEnable             <- mkReg(False);
   Reg#(ApbAddr#(`TLMS_PRM))                 rAddr               <- mkReg(idle_addr);
   Reg#(ApbProt)                             rProt               <- mkRegU;
   Reg#(ApbWrite)                            rWrite              <- mkRegU;
   Reg#(ApbData#(`TLMS_PRM))                 rWData              <- mkRegU;
   Reg#(ApbByteEn#(`TLMS_PRM))               rWStrb              <- mkRegU;

   Wire#(ApbData#(`TLMS_PRM))                wRData              <- mkBypassWire;
   Wire#(Bool)                               wSlvErr             <- mkBypassWire;
   Wire#(Bool)                               wReady              <- mkBypassWire;

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   Counter#(SizeOf#(TLMBurstLength))        rAxiWrCount         <- mkCounter(0);

   (* descending_urgency = "process_read, process_write" *)
   rule process_read(rAxiWrCount.value == 0);
      let request <- axi_read.tlm.tx.get;
      fAxiReqs.enq(request);
   endrule

   rule process_write;
      let request <- axi_write.tlm.tx.get;
      let tlmreq = toTLMRequest(request);

      case(tlmreq) matches
	 tagged Descriptor .d: rAxiWrCount.setF(pack(d.b_length) );
	 tagged Data       .d: rAxiWrCount.down;
      endcase

      fAxiReqs.enq(request);
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Idle State
   ////////////////////////////////////////////////////////////////////////////////
   (* preempts = "idle_state_to_setup, idle_state_to_idle" *)
   rule idle_state_to_setup(toTLMRequest(fAxiReqs.first) matches tagged Descriptor .tlmreq &&& rState == IDLE);
      fAxiReqs.deq;

      ApbProt apbprot = tuple3(tlmreq.access, tlmreq.security, tlmreq.privilege);

      rEnable     <= False;
      rAddr       <= zExtend(tlmreq.addr);
      rProt       <= apbprot;
      rWrite      <= getApbWrite(tlmreq.command);
      rWData      <= (tlmreq.addr[2] == 1) ? truncateLSB(tlmreq.data) : truncate(tlmreq.data);
      rWStrb      <= (tlmreq.addr[2] == 1) ? truncateLSB(tlmreq.byte_enable) : truncate(tlmreq.byte_enable);
      rState      <= SETUP;
      rDescriptor <= incrTLMAddr(tlmreq);
      rCount.setF(pack(tlmreq.b_length) );
   endrule

   rule idle_state_to_idle(rState == IDLE);
      rEnable     <= False;
      rAddr       <= idle_addr;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Setup State
   ////////////////////////////////////////////////////////////////////////////////
   rule setup_state(rState == SETUP);
      rEnable     <= True;
      rState      <= ACCESS;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Access State
   ////////////////////////////////////////////////////////////////////////////////
   // We fire this rule on the occasions where we are about to finish this transaction and there
   // is no subsequent transaction to process.  We therefore, progress to the IDLE state and
   // wait for the next request.
   rule access_state_to_idle(rState == ACCESS && wReady && rCount.value == 0 && !fAxiReqs.notEmpty);
      TLMResponse#(`TLMM_PRM) response = defaultValue;
      response.command        = rDescriptor.command;
      response.transaction_id = rDescriptor.transaction_id;
      response.custom         = rDescriptor.custom;
      response.status         = (wSlvErr) ? ERROR : SUCCESS;
      response.data           = duplicate(wRData);
      if (rDescriptor.command matches WRITE) begin
	 axi_write.tlm.rx.put(fromTLMResponse(response));
      end
      else begin
	 axi_read.tlm.rx.put(fromTLMResponse(response));
      end

      rEnable     <= False;
      rAddr       <= idle_addr;
      rState      <= IDLE;
   endrule

   // We fire this rule on the occasions where we are about to finish this transaction and there
   // is a subsequent transaction to process.  We progress to the SETUP state and start the address
   // phase without idle cycles.
   rule access_state_to_setup(toTLMRequest(fAxiReqs.first) matches tagged Descriptor .d &&& rState == ACCESS &&& wReady &&& rCount.value == 0);
      fAxiReqs.deq;

      TLMResponse#(`TLMM_PRM) response = defaultValue;
      response.command        = rDescriptor.command;
      response.transaction_id = rDescriptor.transaction_id;
      response.custom         = rDescriptor.custom;
      response.status         = (wSlvErr) ? ERROR : SUCCESS;
      response.data           = duplicate(wRData);

      if (rDescriptor.command matches WRITE) begin
	 axi_write.tlm.rx.put(fromTLMResponse(response));
      end
      else begin
	 axi_read.tlm.rx.put(fromTLMResponse(response));
      end

      ApbProt apbprot = tuple3(d.access, d.security, d.privilege);

      rEnable     <= False;
      rAddr       <= d.addr;
      rProt       <= apbprot;
      rWrite      <= getApbWrite(d.command);
      rWData      <= (d.addr[2] == 1) ? truncateLSB(d.data) : truncate(d.data);
      rWStrb      <= (d.command == READ) ? 0 : (d.addr[2] == 1) ? truncateLSB(d.byte_enable) : truncate(d.byte_enable);
      rState      <= SETUP;
      rDescriptor <= incrTLMAddr(d);
      rCount.setF(pack(d.b_length) );
   endrule

   // We fire this rule if we are in the middle of a read-burst transaction.  The read burst
   // is characterized by a single cycle TLM descriptor with a b_length field >1.  We
   // cycle through ACCESS and SETUP states until the slave has provided all the responses
   // of the read burst.
   rule access_state_to_setup_read_burst(rState == ACCESS && wReady && rCount.value > 0 && rDescriptor.command == READ);
      TLMResponse#(`TLMM_PRM) response = defaultValue;
      response.command        = rDescriptor.command;
      response.transaction_id = rDescriptor.transaction_id;
      response.custom         = rDescriptor.custom;
      response.status         = (wSlvErr) ? ERROR : SUCCESS;
      response.data           = duplicate(wRData);

      axi_read.tlm.rx.put(fromTLMResponse(response));

      rEnable     <= False;
      rAddr       <= rDescriptor.addr;
      rState      <= SETUP;
      rDescriptor <= incrTLMAddr(rDescriptor);
      rCount.down;
   endrule

   // We fire this rule if we are in the middle of a write-burst transaction.  The write burst
   // is characterized by a single cycle TLM descriptor with a b_length field >1 and
   // subsequent TLM data beats.  We cycle through ACCESS and SETUP states until the slave has
   // provided all the responses of the write burst.
   rule access_state_to_setup_write_burst(toTLMRequest(fAxiReqs.first) matches tagged Data .d &&& rState == ACCESS &&& wReady &&& rCount.value > 0 &&& rDescriptor.command == WRITE);
      TLMResponse#(`TLMM_PRM) response = defaultValue;
      response.command        = rDescriptor.command;
      response.transaction_id = rDescriptor.transaction_id;
      response.custom         = rDescriptor.custom;
      response.status         = (wSlvErr) ? ERROR : SUCCESS;
      response.data           = duplicate(wRData);

      axi_write.tlm.rx.put(fromTLMResponse(response));

      fAxiReqs.deq;

      ApbProt apbprot = tuple3(rDescriptor.access, rDescriptor.security, rDescriptor.privilege);

      rEnable     <= False;
      rAddr       <= rDescriptor.addr;
      rProt       <= apbprot;
      rWrite      <= getApbWrite(rDescriptor.command);
      rWData      <= (rDescriptor.addr[2] == 1) ? truncateLSB(d.data) : truncate(d.data);
      rWStrb      <= maxBound;
      rState      <= SETUP;
      rDescriptor <= incrTLMAddr(rDescriptor);
      rCount.down;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface AxiRdFabricSlave axi_rd = axi_read.fabric;
   interface AxiWrFabricSlave axi_wr = axi_write.fabric;
   interface ApbXtorMaster    apb;
      interface ApbMaster bus;
         method paddr   = rAddr;
   	 method pprot   = rProt;
   	 method penable = rEnable;
   	 method pwrite  = rWrite;
   	 method pwdata  = rWData;
   	 method pstrb   = rWStrb;
   	 method pready  = wReady._write;
   	 method prdata  = wRData._write;
   	 method pslverr = wSlvErr._write;
      endinterface
   endinterface
endmodule

endpackage: ApbMasterAxi

