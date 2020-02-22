////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : ApbSlave.bsv
//  Description   : APB Slave Target Defintion
////////////////////////////////////////////////////////////////////////////////
package ApbSlave;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import ApbDefines        ::*;

import TLM3              ::*;
import DefaultValue      ::*;
import FIFO              ::*;
import FIFOF             ::*;
import SpecialFIFOs      ::*;
import Bus               ::*;
import GetPut            ::*;
import BUtils            ::*;
import FShow             ::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
/// Types
////////////////////////////////////////////////////////////////////////////////
typedef enum {
   IDLE,
   SETUP,
   ACCESS
} ApbState deriving (Bits, Eq);

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
interface ApbSlaveIFC#(`TLM_PRM_DCL);
   interface ApbSlave#(`TLM_PRM)              bus;
   interface Put#(ApbResponse#(`TLM_PRM))     response;
   interface ReadOnly#(ApbRequest#(`TLM_PRM)) request;
   interface ReadOnly#(Bool)                  penable;
   interface ReadOnly#(Bool)                  psel;
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkApbSlaveIFC (ApbSlaveIFC#(`TLM_PRM))
   provisos(DefaultValue#(ApbResponse#(`TLM_PRM)));

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Wire#(ApbData#(`TLM_PRM))                 wPWDATA             <- mkBypassWire;
   Wire#(ApbWrite)                           wPWRITE             <- mkBypassWire;
   Wire#(ApbProt)                            wPPROT              <- mkBypassWire;
   Wire#(ApbAddr#(`TLM_PRM))                 wPADDR              <- mkBypassWire;
   Wire#(ApbByteEn#(`TLM_PRM))               wPSTRB              <- mkBypassWire;
   Wire#(Bool)                               wPENABLE            <- mkBypassWire;
   Wire#(Bool)                               wPSEL               <- mkBypassWire;

   RWire#(ApbResponse#(`TLM_PRM))            rwResponse          <- mkRWire;
   Reg#(Bool)                                rSelected           <- mkReg(False);

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   rule update_select;
      rSelected <= wPSEL;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface Put response;
      method Action put(value) if (rSelected);
         rwResponse.wset(value);
      endmethod
   endinterface

   interface ReadOnly request;
      method ApbRequest#(`TLM_PRM) _read if (wPSEL && !wPENABLE);
         let ctrl  = ApbCtrl {
	    command: wPWRITE,
	    addr:    wPADDR,
	    prot:    wPPROT
	    };
         let value = ApbRequest {
	    ctrl: ctrl,
	    strb: wPSTRB,
	    data: wPWDATA
	    };
         return value;
      endmethod
   endinterface

   interface ReadOnly penable;
      method _read = wPENABLE;
   endinterface

   interface ReadOnly psel;
      method _read = wPSEL;
   endinterface

   interface ApbSlave bus;
      // Outputs
      method pready    = isValid(rwResponse.wget);
      method prdata    = fromMaybe(defaultValue, rwResponse.wget).data;
      method pslverr   = fromMaybe(defaultValue, rwResponse.wget).error;

      // Inputs
      method paddr     = wPADDR._write;
      method pprot     = wPPROT._write;
      method penable   = wPENABLE._write;
      method pwrite    = wPWRITE._write;
      method pwdata    = wPWDATA._write;
      method pstrb     = wPSTRB._write;
      method psel      = wPSEL._write;
   endinterface
endmodule

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
///
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkApbSlaveWM#(function Bool addr_match(ApbAddr#(`TLM_PRM) addr))(ApbSlaveXActorWM#(`TLM_XTR))
   provisos( Bits#(req_t, s0)
           , Bits#(resp_t, s1)
           , DefaultValue#(TLMResponse#(`TLM_PRM))
           , TLMRequestTC#(req_t, `TLM_PRM)
           , TLMResponseTC#(resp_t, `TLM_PRM)
           , FShow#(resp_t)
           );

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   let                                       _ifc                <- mkApbSlave;

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface TLMSendIFC tlm = _ifc.tlm;
   interface ApbXtorSlaveWM fabric;
      interface ApbSlave         bus      = _ifc.fabric.bus;
      method    addrMatch                 = addr_match;
   endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
///
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkApbSlave(ApbSlaveXActor#(`TLM_XTR))
   provisos( Bits#(req_t, s0)
           , Bits#(resp_t, s1)
           , DefaultValue#(TLMResponse#(`TLM_PRM))
           , TLMRequestTC#(req_t, `TLM_PRM)
           , TLMResponseTC#(resp_t, `TLM_PRM)
           , FShow#(resp_t)
           , TLMRequestTC#(ApbRequest#(`TLM_PRM), `TLM_PRM));

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   FIFO#(resp_t)                             fifoRx              <- mkLFIFO;
   FIFO#(req_t)                              fifoTx              <- mkLFIFO;

   let                                       ifc                 <- mkApbSlaveIFC;
   let                                       request              = ifc.request;

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   rule process_setup(ifc.psel && !ifc.penable);
      let desc = toTLMRequest(request);
      fifoTx.enq(fromTLMRequest(desc));
   endrule

   rule process_access(ifc.psel && ifc.penable);
      let desc = toTLMResponse(fifoRx.first); fifoRx.deq;
      ifc.response.put(fromTLMResponse(desc));
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface TLMSendIFC tlm;
      interface Get tx = toGet(fifoTx);
      interface Put rx = toPut(fifoRx);
   endinterface

   interface ApbXtorSlave fabric;
      interface ApbSlave         bus = ifc.bus;
   endinterface
endmodule

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Slave that sends back an error (intended to collect all other targets)
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkApbErrorSlave(ApbXtorSlave#(`TLM_PRM));
   function Action nop(a ignore);
      return noAction;
   endfunction

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface ApbSlave bus;
      method paddr   = nop;
      method pprot   = nop;
      method penable = nop;
      method pwrite  = nop;
      method pwdata  = nop;
      method pstrb   = nop;

      method pready  = True;
      method prdata  = 'hEE;
      method pslverr = True;
      method psel    = nop;
   endinterface
endmodule

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Slave that never comes ready (mainly for testing purposes)
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkApbNotReadySlave(ApbXtorSlave#(`TLM_PRM));
   function Action nop(a ignore);
      return noAction;
   endfunction

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface ApbSlave bus;
      method paddr   = nop;
      method pprot   = nop;
      method penable = nop;
      method pwrite  = nop;
      method pwdata  = nop;
      method pstrb   = nop;

      method pready  = False;
      method prdata  = 'hDD;
      method pslverr = True;
      method psel    = nop;
   endinterface
endmodule

endpackage: ApbSlave

