////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : ApbMaster.bsv
//  Description   : APB master target definition
////////////////////////////////////////////////////////////////////////////////
package ApbMaster;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////

import ApbDefines       ::*;
import ApbSlave         ::*;
import BUtils           ::*;

import TLM3             ::*;
import DefaultValue     ::*;
import FShow            ::*;
import FIFO             ::*;
import FIFOF            ::*;
import SpecialFIFOs     ::*;
import Connectable      ::*;
import GetPut           ::*;
import Vector           ::*;
import Counter          ::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

module mkApbMaster#(parameter Bool big_endian) (ApbMasterXActor#(`TLM_XTR))
   provisos (TLMRequestTC#(req_t, `TLM_PRM),
      TLMResponseTC#(resp_t, `TLM_PRM),
      Bits#(req_t, s0),
      Bits#(resp_t, s1),
      Bits#(RequestDescriptor#(`TLM_PRM), s2)
      );

  ////////////////////////////////////////////////////////////////////////////////
  /// TLM Design Elements
  ////////////////////////////////////////////////////////////////////////////////
  FIFOF#(req_t)                         fTlmReqs            <- mkBypassFIFOF;
  FIFOF#(resp_t)                        fTlmRsps            <- mkLFIFOF;

  ////////////////////////////////////////////////////////////////////////////////
  /// Apb Design Elements
  ////////////////////////////////////////////////////////////////////////////////
  Reg#(ApbState)                           rState              <- mkReg(IDLE);

  Reg#(RequestDescriptor#(`TLM_PRM))       rDescriptor         <- mkRegU;
  Counter#(SizeOf#(TLMBLength#(`TLM_PRM))) rCount              <- mkCounter(0);

  Reg#(Bool)                            rEnable             <- mkReg(False);
  Reg#(ApbAddr#(`TLM_PRM))              rAddr               <- mkReg(0);
  Reg#(ApbProt)                         rProt               <- mkRegU;
  Reg#(ApbWrite)                        rWrite              <- mkRegU;
  Reg#(ApbData#(`TLM_PRM))              rWData              <- mkRegU;
  Reg#(ApbByteEn#(`TLM_PRM))            rWStrb              <- mkRegU;
  Reg#(Bool)                            rSel                <- mkReg(False);

  Wire#(ApbData#(`TLM_PRM))             wRData              <- mkBypassWire;
  Wire#(Bool)                           wSlvErr             <- mkBypassWire;
  Wire#(Bool)                           wReady              <- mkBypassWire;

  ////////////////////////////////////////////////////////////////////////////////
  /// Rules
  ////////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////////
  /// Idle State
  ////////////////////////////////////////////////////////////////////////////////
  (* preempts = "idle_state_to_setup, idle_state_to_idle" *)
  rule idle_state_to_setup(toTLMRequest(fTlmReqs.first) matches tagged Descriptor .tlmreq &&& rState == IDLE);
    fTlmReqs.deq;

    ApbProt apbprot = ?;
    apbprot.access = tlmreq.access;
    apbprot.security = tlmreq.security;
    apbprot.privilege = tlmreq.privilege;

    rEnable     <= False;
    rAddr       <= zExtend(tlmreq.addr);
    rSel        <= True;
    rProt       <= apbprot;
    rWrite      <= getApbWrite(tlmreq.command);
    rWData      <= tlmreq.data;

     let be = getTLMByteEn(big_endian, tlmreq);
     if (tlmreq.byte_enable matches tagged Specify .b)
	be = b;
     rWStrb      <= be;

    rState      <= SETUP;
    rDescriptor <= incrTLMAddr(tlmreq);
    rCount.setF (pack(tlmreq.b_length));
  endrule

  rule idle_state_to_idle ((rState == IDLE) && (!fTlmReqs.notEmpty));
    rEnable     <= False;
    rSel        <= False;
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
  rule access_state_to_idle(rState == ACCESS && wReady && rCount.value == 0 && !fTlmReqs.notEmpty);
    TLMResponse#(`TLM_PRM) response = defaultValue;
    response.command        = rDescriptor.command;
    response.transaction_id = rDescriptor.transaction_id;
    response.status         = (wSlvErr) ? ERROR : SUCCESS;
    response.data           = duplicate(wRData);
    response.is_last        = True;

    fTlmRsps.enq (fromTLMResponse(response));

    rEnable     <= False;
    rState      <= IDLE;
    rSel        <= False;
  endrule

  // We fire this rule on the occasions where we are about to finish this transaction and there
  // is a subsequent transaction to process.  We progress to the SETUP state and start the address
  // phase without idle cycles.
  rule access_state_to_setup(toTLMRequest(fTlmReqs.first) matches tagged Descriptor .d &&& rState == ACCESS &&& wReady &&& rCount.value == 0);
    fTlmReqs.deq;

    TLMResponse#(`TLM_PRM) response = defaultValue;
    response.command        = rDescriptor.command;
    response.transaction_id = rDescriptor.transaction_id;
    response.status         = (wSlvErr) ? ERROR : SUCCESS;
    response.data           = duplicate(wRData);
    response.is_last        = True;

    fTlmRsps.enq (fromTLMResponse(response));

    ApbProt apbprot = ?;
    apbprot.access = d.access;
    apbprot.security = d.security;
    apbprot.privilege = d.privilege;

    rEnable     <= False;
    rAddr       <= d.addr;
    rSel        <= True;
    rProt       <= apbprot;
    rWrite      <= getApbWrite(d.command);
    rWData      <= d.data;

     let be = getTLMByteEn(big_endian, d);
     if (d.byte_enable matches tagged Specify .b)
	be = b;
     rWStrb      <= be;

    rState      <= SETUP;
    rDescriptor <= incrTLMAddr(d);
    rCount.setF(pack(d.b_length) );
  endrule

  // We fire this rule if we are in the middle of a read-burst transaction.  The read burst
  // is characterized by a single cycle TLM descriptor with a b_length field >1.  We
  // cycle through ACCESS and SETUP states until the slave has provided all the responses
  // of the read burst.
  rule access_state_to_setup_read_burst(rState == ACCESS && wReady && rCount.value > 0 && rDescriptor.command == READ);
    TLMResponse#(`TLM_PRM) response = defaultValue;
    response.command        = rDescriptor.command;
    response.transaction_id = rDescriptor.transaction_id;
    response.status         = (wSlvErr) ? ERROR : SUCCESS;
    response.data           = duplicate(wRData);
    response.is_last        = True;

    fTlmRsps.enq(fromTLMResponse(response));

    rEnable     <= False;
    rAddr       <= rDescriptor.addr;
    rSel        <= True;
    rState      <= SETUP;
    rDescriptor <= incrTLMAddr(rDescriptor);
    rCount.down;
  endrule

  // We fire this rule if we are in the middle of a write-burst transaction.  The write burst
  // is characterized by a single cycle TLM descriptor with a b_length field >1 and
  // subsequent TLM data beats.  We cycle through ACCESS and SETUP states until the slave has
  // provided all the responses of the write burst.
  rule access_state_to_setup_write_burst(toTLMRequest(fTlmReqs.first) matches tagged Data .d &&& rState == ACCESS &&& wReady &&& rCount.value > 0 &&& rDescriptor.command == WRITE);
    TLMResponse#(`TLM_PRM) response = defaultValue;
    response.command        = rDescriptor.command;
    response.transaction_id = rDescriptor.transaction_id;
    response.status         = (wSlvErr) ? ERROR : SUCCESS;
    response.data           = duplicate(wRData);
    response.is_last        = True;

    fTlmRsps.enq(fromTLMResponse(response));
    fTlmReqs.deq;

    ApbProt apbprot = ?;
    apbprot.access = rDescriptor.access;
    apbprot.security = rDescriptor.security;
    apbprot.privilege = rDescriptor.privilege;

    rEnable     <= False;
    rAddr       <= rDescriptor.addr;
    rSel        <= True;
    rProt       <= apbprot;
    rWrite      <= getApbWrite(rDescriptor.command);
//  rWData      <= (rDescriptor.addr[2] == 1) ? truncateLSB(d.data) : truncate(d.data);
    rWData      <= d.data;
    rWStrb      <= maxBound;
    rState      <= SETUP;
    rDescriptor <= incrTLMAddr(rDescriptor);
    rCount.down;
  endrule

  ////////////////////////////////////////////////////////////////////////////////
  /// Interface Connections / Methods
  ////////////////////////////////////////////////////////////////////////////////
  interface TLMRecvIFC tlm;
    interface Put rx = toPut (fTlmReqs);
    interface Get tx = toGet (fTlmRsps);
  endinterface

  interface ApbXtorMaster fabric;
    interface ApbMaster bus;
      method paddr   = rAddr;
      method pprot   = rProt;
      method penable = rEnable;
      method pwrite  = rWrite;
      method pwdata  = rWData;
      method pstrb   = rWStrb;
      method psel    = rSel;
      method pready  = wReady._write;
      method prdata  = wRData._write;
      method pslverr = wSlvErr._write;
    endinterface
  endinterface
endmodule

endpackage: ApbMaster
