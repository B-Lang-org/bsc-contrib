////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : SPI.bsv
//  Description   :
////////////////////////////////////////////////////////////////////////////////
package SPI;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import TLM2              ::*;
import FIFO              ::*;
import DefaultValue      ::*;
import GetPut            ::*;
import SpecialFIFOs      ::*;
import BUtils            ::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
(* always_enabled, always_ready *)
interface SPI_Pins;
   (* prefix = "", result = "SSEL" *)
   method    Bit#(1)     ssel();
   (* prefix = "", result = "MOSI" *)
   method    Bit#(1)     mosi();
   (* prefix = "" *)
   method    Action      miso((* port = "MISO" *)Bit#(1) i);
   (* prefix = "", result = "SCK" *)
   method    Bit#(1)     sck();
endinterface

interface SPI#(`TLM_XTR_DCL);
   interface TLMRecvIFC#(`TLM_RR) read;
   interface TLMRecvIFC#(`TLM_RR) write;
   (* prefix = "" *)
   interface SPI_Pins             spi;
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkSPI(SPI#(`TLM_XTR))
   provisos(  Bits#(req_t, sreq)
	    , Bits#(resp_t, sresp)
	    , DefaultValue#(TLMResponse#(`TLM_PRM))
	    , TLMRequestTC#(req_t, `TLM_PRM)
	    , TLMResponseTC#(resp_t, `TLM_PRM)
	    , Add#(4, _1, data_size)
	    );

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   FIFO#(req_t)                    fRdRequest          <- mkBypassFIFO;
   FIFO#(resp_t)                   fRdResponse         <- mkLFIFO;

   FIFO#(req_t)                    fWrRequest          <- mkBypassFIFO;
   FIFO#(resp_t)                   fWrResponse         <- mkLFIFO;

   Reg#(Bit#(1))                   rSSEL               <- mkReg(1);
   Reg#(Bit#(1))                   rMOSI               <- mkReg(1);
   Reg#(Bit#(1))                   rMISO               <- mkRegU;
   Reg#(Bit#(1))                   rSCLK               <- mkReg(0);

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   rule process_read_data(toTLMRequest(fRdRequest.first) matches tagged Descriptor .d &&&
			  d.command matches READ
			  );
      fRdRequest.deq;

      TLMResponse#(`TLM_PRM) response = defaultValue;
      response.command        = READ;
      response.data           = cExtend({ rSSEL, rMOSI, rMISO, rSCLK });
      response.status         = SUCCESS;
      response.transaction_id = d.transaction_id;
      response.custom         = d.custom;
      fRdResponse.enq(fromTLMResponse(response));
   endrule

   rule process_write_data(toTLMRequest(fWrRequest.first) matches tagged Descriptor .d &&&
			   d.command matches WRITE
			   );
      fWrRequest.deq;

      rSCLK <= d.data[0];
      rMOSI <= d.data[2];
      rSSEL <= d.data[3];

      TLMResponse#(`TLM_PRM) response = defaultValue;
      response.command        = WRITE;
      response.status         = SUCCESS;
      response.transaction_id = d.transaction_id;
      response.custom         = d.custom;
      fWrResponse.enq(fromTLMResponse(response));
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface TLMRecvIFC read;
      interface tx = toGet(fRdResponse);
      interface rx = toPut(fRdRequest);
   endinterface

   interface TLMRecvIFC write;
      interface tx = toGet(fWrResponse);
      interface rx = toPut(fWrRequest);
   endinterface

   interface SPI_Pins spi;
      method    Bit#(1)     ssel();
	 return rSSEL;
      endmethod
      method    Bit#(1)     mosi();
	 return rMOSI;
      endmethod
      method    Action      miso(Bit#(1) i);
	 rMISO <= i;
      endmethod
      method    Bit#(1)     sck();
	 return rSCLK;
      endmethod
   endinterface

endmodule: mkSPI



endpackage: SPI

