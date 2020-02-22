////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : ApbDefines.bsv
//  Description   : AMBA APB Protocol Version 2.0  (ARM IHI 0024C) (APB4)
////////////////////////////////////////////////////////////////////////////////
package ApbDefines;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////

import BUtils            ::*;
import Connectable       ::*;
import DefaultValue      ::*;
import TieOff            ::*;
import FShow             ::*;
import TLM3              ::*;
import Vector            ::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
/// Types
////////////////////////////////////////////////////////////////////////////////

typedef Bit#(addr_size)                      ApbAddr#(`TLM_PRM_DCL);
typedef Bit#(data_size)                      ApbData#(`TLM_PRM_DCL);
typedef Bit#(TDiv#(data_size, 8))            ApbByteEn#(`TLM_PRM_DCL);

typedef enum { READ, WRITE } ApbWrite deriving (Bits, Eq, Bounded);

typedef struct {
		TLMAccess    access;
		TLMSecurity  security;
		TLMPrivilege privilege;
		} ApbProt deriving (Eq, Bits, Bounded);

typedef struct {
   ApbWrite             command;
   ApbAddr#(`TLM_PRM)   addr;
   ApbProt              prot;
} ApbCtrl#(`TLM_PRM_DCL) deriving (Bits, Eq);

instance DefaultValue#(ApbCtrl#(`TLM_PRM));
   defaultValue = ApbCtrl {
      command: WRITE,
      addr:    0,
      prot:    unpack(0)
      };
endinstance

typedef struct {
   ApbCtrl#(`TLM_PRM)   ctrl;
   ApbByteEn#(`TLM_PRM) strb;
   ApbData#(`TLM_PRM)   data;
} ApbRequest#(`TLM_PRM_DCL) deriving (Bits, Eq);

instance DefaultValue#(ApbRequest#(`TLM_PRM));
   defaultValue = ApbRequest {
      ctrl: defaultValue,
      strb: 0,
      data: 0
      };
endinstance

typedef struct {
   Bool                 error;
   ApbData#(`TLM_PRM)   data;
} ApbResponse#(`TLM_PRM_DCL) deriving (Bits, Eq);

instance DefaultValue#(ApbResponse#(`TLM_PRM));
   defaultValue = ApbResponse {
      error:   False,
      data:    0
      };
endinstance

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
(* always_ready, always_enabled *)
interface ApbMaster#(`TLM_PRM_DCL);
   // Apb Bridge Outputs
   (* prefix = "",
      result = "PADDR" *)
   method    ApbAddr#(`TLM_PRM)   paddr;
   (* prefix = "",
      result = "PPROT" *)
   method    ApbProt              pprot;
   (* prefix = "",
      result = "PENABLE" *)
   method    Bool                 penable;
   (* prefix = "",
      result = "PWRITE" *)
   method    ApbWrite             pwrite;
   (* prefix = "",
      result = "PWDATA" *)
   method    ApbData#(`TLM_PRM)   pwdata;
   (* prefix = "",
      result = "PSTRB" *)
   method    ApbByteEn#(`TLM_PRM) pstrb;
   (* prefix = "",
      result = "PSEL" *)
   method    Bool                 psel;

   // Apb Bridge Inputs
   (* prefix = "" *)
   method    Action               pready((* port = "PREADY" *)   Bool x);
   (* prefix = "" *)
   method    Action               prdata((* port = "PRDATA" *)   ApbData#(`TLM_PRM) x);
   (* prefix = "" *)
   method    Action               pslverr((* port = "PSLVERR" *) Bool x);
endinterface

(* always_ready, always_enabled *)
interface ApbMasterDual#(`TLM_PRM_DCL);
   // Apb Slave Inputs
   (* prefix = "" *)
   method    Action               paddr((* port = "PADDR" *)     ApbAddr#(`TLM_PRM) x);
   (* prefix = "" *)
   method    Action               pprot((* port = "PPROT" *)     ApbProt x);
   (* prefix = "" *)
   method    Action               penable((* port = "PENABLE" *) Bool x);
   (* prefix = "" *)
   method    Action               pwrite((* port = "PWRITE" *)   ApbWrite x);
   (* prefix = "" *)
   method    Action               pwdata((* port = "PWDATA" *)   ApbData#(`TLM_PRM) x);
   (* prefix = "" *)
   method    Action               pstrb((* port = "PSTRB" *)     ApbByteEn#(`TLM_PRM) x);
   (* prefix = "" *)
   method    Action               psel((* port = "PSEL" *)       Bool x);

   // Apb Slave Outputs
   (* prefix = "",
      result = "PREADY" *)
   method    Bool                 pready;
   (* prefix = "",
      result = "PRDATA" *)
   method    ApbData#(`TLM_PRM)   prdata;
   (* prefix = "",
      result = "PSLVERR" *)
   method    Bool                 pslverr;
endinterface

(* always_ready, always_enabled *)
interface ApbSlave#(`TLM_PRM_DCL);
   // Apb Slave Outputs
   (* prefix = "",
      result = "PREADY" *)
   method    Bool                  pready;
   (* prefix = "",
      result = "PRDATA" *)
   method    ApbData#(`TLM_PRM)    prdata;
   (* prefix = "",
      result = "PSLVERR" *)
   method    Bool                  pslverr;

   // Apb Slave Inputs
   (* prefix = "" *)
   method    Action                paddr((* port = "PADDR" *)     ApbAddr#(`TLM_PRM) x);
   (* prefix = "" *)
   method    Action                pprot((* port = "PPROT" *)     ApbProt x);
   (* prefix = "" *)
   method    Action                penable((* port = "PENABLE" *) Bool x);
   (* prefix = "" *)
   method    Action                pwrite((* port = "PWRITE" *)   ApbWrite x);
   (* prefix = "" *)
   method    Action                pwdata((* port = "PWDATA" *)   ApbData#(`TLM_PRM) x);
   (* prefix = "" *)
   method    Action                pstrb((* port = "PSTRB" *)     ApbByteEn#(`TLM_PRM) x);
   (* prefix = "" *)
   method    Action                psel((* port = "PSEL" *)           Bool x);
endinterface

(* always_ready, always_enabled *)
interface ApbSlaveDual#(`TLM_PRM_DCL);
   // Apb Bridge Inputs
   (* prefix = "" *)
   method    Action                pready((* port = "PREADY" *)   Bool x);
   (* prefix = "" *)
   method    Action                prdata((* port = "PRDATA" *)   ApbData#(`TLM_PRM) x);
   (* prefix = "" *)
   method    Action                pslverr((* port = "PSLVERR" *) Bool x);

   // Apb Bridge Outputs
   (* prefix = "",
      result = "PADDR" *)
   method    ApbAddr#(`TLM_PRM)    paddr;
   (* prefix = "",
      result = "PPROT" *)
   method    ApbProt               pprot;
   (* prefix = "",
      result = "PENABLE" *)
   method    Bool                  penable;
   (* prefix = "",
      result = "PWRITE" *)
   method    ApbWrite              pwrite;
   (* prefix = "",
      result = "PWDATA" *)
   method    ApbData#(`TLM_PRM)    pwdata;
   (* prefix = "",
      result = "PSTRB" *)
   method    ApbByteEn#(`TLM_PRM)  pstrb;
   (* prefix = "",
      result = "PSEL" *)
   method    Bool                  psel;
endinterface


////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////
interface ApbXtorMaster#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface ApbMaster#(`TLM_PRM)     bus;
endinterface

interface ApbXtorSlave#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface ApbSlave#(`TLM_PRM)      bus;
endinterface

interface ApbXtorSlaveWM#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface ApbSlave#(`TLM_PRM)      bus;
   (* prefix = "" *)
   method    Bool  addrMatch(ApbAddr#(`TLM_PRM) x);
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////
interface ApbXtorMasterDual#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface ApbMasterDual#(`TLM_PRM)     bus;
endinterface

interface ApbXtorSlaveDual#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface ApbSlaveDual#(`TLM_PRM)      bus;
endinterface

interface ApbXtorMasterConnector#(`TLM_PRM_DCL);
   interface ApbXtorMaster#(`TLM_PRM)     master;
   interface ApbXtorMasterDual#(`TLM_PRM) dual;
endinterface

interface ApbXtorSlaveConnector#(`TLM_PRM_DCL);
   interface ApbXtorSlaveWM#(`TLM_PRM)    slave;
   interface ApbXtorSlaveDual#(`TLM_PRM)  dual;
endinterface

interface ApbBus#(numeric type s, `TLM_PRM_DCL);
   interface ApbXtorMasterDual#(`TLM_PRM)            master;
   interface Vector#(s, ApbXtorSlaveDual#(`TLM_PRM)) slaves;
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////
interface ApbMasterXActor#(`TLM_RR_DCL, `TLM_PRM_DCL);
   interface TLMRecvIFC#(`TLM_RR)      tlm;
   (* prefix = "" *)
   interface ApbXtorMaster#(`TLM_PRM)  fabric;
endinterface

interface ApbSlaveXActorWM#(`TLM_RR_DCL, `TLM_PRM_DCL);
   interface TLMSendIFC#(`TLM_RR)      tlm;
   (* prefix = "" *)
   interface ApbXtorSlaveWM#(`TLM_PRM) fabric;
endinterface

interface ApbSlaveXActor#(`TLM_RR_DCL, `TLM_PRM_DCL);
   interface TLMSendIFC#(`TLM_RR)      tlm;
   (* prefix = "" *)
   interface ApbXtorSlave#(`TLM_PRM)   fabric;
endinterface

////////////////////////////////////////////////////////////////////////////////
/// Connectables
////////////////////////////////////////////////////////////////////////////////
instance Connectable#(ApbXtorMaster#(`TLM_PRM), ApbXtorMasterDual#(`TLM_PRM));
   module mkConnection#(ApbXtorMaster#(`TLM_PRM)      m,
                        ApbXtorMasterDual#(`TLM_PRM)  d)(Empty);
      mkConnection(m.bus, d.bus);
   endmodule
endinstance

instance Connectable#(ApbXtorSlave#(`TLM_PRM), ApbXtorSlaveDual#(`TLM_PRM));
   module mkConnection#(ApbXtorSlave#(`TLM_PRM)       s,
                        ApbXtorSlaveDual#(`TLM_PRM)   d)(Empty);
      mkConnection(d.bus, s.bus);
   endmodule
endinstance

instance Connectable#(ApbXtorMaster#(`TLM_PRM), ApbXtorSlave#(`TLM_PRM));
   module mkConnection#(ApbXtorMaster#(`TLM_PRM) m,
                        ApbXtorSlave#(`TLM_PRM)  s)(Empty);
      mkConnection(m.bus, s.bus);
   endmodule
endinstance

instance Connectable#(ApbXtorSlave#(`TLM_PRM), ApbXtorMaster#(`TLM_PRM));
   module mkConnection#(ApbXtorSlave#(`TLM_PRM) s,
                        ApbXtorMaster#(`TLM_PRM)  m) (Empty);
      (*hide*) let _i <- mkConnection(m, s);
   endmodule
endinstance

instance Connectable#(ApbMaster#(`TLM_PRM), ApbSlave#(`TLM_PRM));
   module mkConnection#(ApbMaster#(`TLM_PRM) m,
                        ApbSlave#(`TLM_PRM)  s)(Empty);

      rule master_to_slave;
         s.paddr(m.paddr);
	 s.pprot(m.pprot);
         s.penable(m.penable);
         s.pwrite(m.pwrite);
         s.pwdata(m.pwdata);
	 s.pstrb(m.pstrb);
	 s.psel(m.psel);
      endrule

      rule slave_to_master;
	 m.pready(s.pready);
         m.prdata(s.prdata);
         m.pslverr(s.pslverr);
      endrule
   endmodule
endinstance

instance Connectable#(ApbMaster#(`TLM_PRM), ApbMasterDual#(`TLM_PRM));
   module mkConnection#(ApbMaster#(`TLM_PRM)     m,
                        ApbMasterDual#(`TLM_PRM) s)(Empty);
      rule master_to_slave;
         s.paddr(m.paddr);
	 s.pprot(m.pprot);
         s.penable(m.penable);
         s.pwrite(m.pwrite);
         s.pwdata(m.pwdata);
	 s.pstrb(m.pstrb);
	 s.psel(m.psel);
      endrule

      rule slave_to_master;
	 m.pready(s.pready);
         m.prdata(s.prdata);
         m.pslverr(s.pslverr);
      endrule
   endmodule
endinstance

instance Connectable#(ApbSlaveDual#(`TLM_PRM), ApbSlave#(`TLM_PRM));
   module mkConnection#(ApbSlaveDual#(`TLM_PRM) m,
                        ApbSlave#(`TLM_PRM)     s)(Empty);
      rule master_to_slave;
         s.paddr(m.paddr);
         s.psel (m.psel);
	 s.pprot(m.pprot);
         s.penable(m.penable);
         s.pwrite(m.pwrite);
         s.pwdata(m.pwdata);
	 s.pstrb(m.pstrb);
      endrule
      rule slave_to_master;
	 m.pready(s.pready);
         m.prdata(s.prdata);
         m.pslverr(s.pslverr);
      endrule
   endmodule
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance FShow#(ApbWrite);
   function Fmt fshow (ApbWrite label);
      case (label)
         READ:  return $format("READ");
         WRITE: return $format("WRITE");
      endcase
   endfunction
endinstance

instance FShow#(ApbProt);
   function Fmt fshow (ApbProt prot);
      return fshow(tuple3(prot.access, prot.security, prot.privilege));
   endfunction
endinstance

instance FShow#(ApbCtrl#(`TLM_PRM));
   function Fmt fshow (ApbCtrl#(`TLM_PRM) ctrl);
      return ($format("<ApbCTRL ")
	      +
	      fshow(ctrl.command)
	      +
              $format(" ")
	      +
              fshow(ctrl.addr)
	      +
	      $format(" ")
	      +
	      fshow(ctrl.prot)
	      +
	      $format(" >"));

   endfunction
endinstance

instance FShow#(ApbRequest#(`TLM_PRM));
   function Fmt fshow (ApbRequest#(`TLM_PRM) req);
      return ($format("<ApbREQ ")
                      +
                      fshow(req.ctrl)
                      +
                      $format(" ")
                      +
                      fshow(req.data)
                      +
                      $format(" ")
                      +
                      fshow(req.strb)
                      +
                      $format(" >"));
   endfunction
endinstance

instance FShow#(ApbResponse#(`TLM_PRM));
   function Fmt fshow (ApbResponse#(`TLM_PRM) resp);
      return ($format("<ApbRESP ")
              +
	      fshow(resp.error)
	      +
              $format(" ")
	      +
              fshow(resp.data)
	      +
              $format(" >"));
   endfunction
endinstance

////////////////////////////////////////////////////////////////////////////////
/// TLM conversion functions
////////////////////////////////////////////////////////////////////////////////

function ApbCtrl#(`TLM_PRM) getApbCtrl(RequestDescriptor#(`TLM_PRM) tlm_descriptor);

   ApbProt prot = ?;
   prot.access    = tlm_descriptor.access;
   prot.security  = tlm_descriptor.security;
   prot.privilege = tlm_descriptor.privilege;

   ApbCtrl#(`TLM_PRM) ctrl;

   ctrl.command = getApbWrite(tlm_descriptor.command);
   ctrl.addr    = tlm_descriptor.addr;
   ctrl.prot    = prot;

   return ctrl;
endfunction

function ApbWrite getApbWrite(TLMCommand command);
   case(command)
      READ:  return READ;
      WRITE: return WRITE;
   endcase
endfunction

function ApbData#(`TLM_PRM) getApbData(RequestDescriptor#(`TLM_PRM) tlm_descriptor);
   ApbData#(`TLM_PRM) data = tlm_descriptor.data;
   return data;
endfunction

////////////////////////////////////////////////////////////////////////////////
/// Apb to TLM
////////////////////////////////////////////////////////////////////////////////
function RequestDescriptor#(`TLM_PRM) fromApbCtrl(ApbCtrl#(`TLM_PRM) ctrl)
   provisos(DefaultValue#(RequestDescriptor#(`TLM_PRM)));

   RequestDescriptor#(`TLM_PRM) desc = defaultValue;

   desc.command      = fromApbWrite(ctrl.command);
   desc.mode         = REGULAR;
   desc.addr         = ctrl.addr;

   desc.access       = ctrl.prot.access;
   desc.security     = ctrl.prot.security;
   desc.privilege    = ctrl.prot.privilege;

   desc.b_length = 1;

   return desc;
endfunction



function TLMCommand fromApbWrite(ApbWrite command);
   case(command)
      READ:  return READ;
      WRITE: return WRITE;
   endcase
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////
interface ApbSlaveMonitor#(`TLM_PRM_DCL);
   interface ApbXtorSlave#(`TLM_PRM) fabric;
   interface ApbInfo#(`TLM_PRM)      info;
endinterface

interface ApbMasterMonitor#(`TLM_PRM_DCL);
   interface ApbXtorMaster#(`TLM_PRM) fabric;
   interface ApbInfo#(`TLM_PRM)       info;
endinterface

(* always_ready *)
interface ApbInfo#(`TLM_PRM_DCL);
   method    Bool     update;
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

function ApbXtorSlaveWM#(`TLM_PRM) addAddrMatch(function Bool addr_match(ApbAddr#(`TLM_PRM) addr),
                                                ApbXtorSlave#(`TLM_PRM) ifc);
   let ifc_wm = (interface ApbXtorSlaveWM;
                    interface ApbSlave          bus       = ifc.bus;
                    method    addrMatch                   = addr_match;
                 endinterface);
   return ifc_wm;
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typeclass Convert#(type a, type b);
   function b convert(a value);
endtypeclass

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance Convert#(ApbXtorSlaveWM#(`TLM_PRM), ApbXtorSlave#(`TLM_PRM));
   function ApbXtorSlave#(`TLM_PRM) convert(ApbXtorSlaveWM#(`TLM_PRM) ifc_wm);
      let ifc = (interface ApbXtorSlave;
                    interface ApbSlave         bus       = ifc_wm.bus;
                 endinterface);
      return ifc;
   endfunction
endinstance

instance Convert#(ApbSlaveXActorWM#(`TLM_XTR), ApbSlaveXActor#(`TLM_XTR));
   function ApbSlaveXActor#(`TLM_XTR) convert(ApbSlaveXActorWM#(`TLM_XTR) ifc_wm);
      let ifc = (interface ApbSlaveXActor;
                    interface TLMSendIFC          tlm       = ifc_wm.tlm;
                    interface ApbXtorSlave fabric;
                       interface ApbSlave         bus       = ifc_wm.fabric.bus;
                    endinterface
                 endinterface);
      return ifc;
   endfunction
endinstance

instance TLMResponseTC#(ApbResponse#(`TLM_PRM), `TLM_PRM)
   provisos(DefaultValue#(TLMResponse#(`TLM_PRM)));

   function TLMResponse#(`TLM_PRM) toTLMResponse(ApbResponse#(`TLM_PRM) value);
      TLMResponse#(`TLM_PRM) response = defaultValue;
      response.data    = value.data;
      response.status  = (value.error) ? ERROR : SUCCESS;
      return response;
   endfunction

   function ApbResponse#(`TLM_PRM) fromTLMResponse(TLMResponse#(`TLM_PRM) value);
      ApbResponse#(`TLM_PRM) response;
      response.data    = value.data;
      response.error   = (value.status == ERROR);
      return response;
   endfunction
endinstance

instance TLMRequestTC#(ApbRequest#(`TLM_PRM), `TLM_PRM)
   provisos(DefaultValue#(RequestDescriptor#(`TLM_PRM)));

   function TLMRequest#(`TLM_PRM) toTLMRequest(ApbRequest#(`TLM_PRM) value);
      RequestDescriptor#(`TLM_PRM) request = defaultValue;
      request.command      = fromApbWrite(value.ctrl.command);
      request.addr         = value.ctrl.addr;

      request.data         = value.data;
      // request.byte_enable  = unpack(pack(value.strb));
      request.byte_enable = tagged Specify ( value.strb );
      request.b_length     = 0;

      request.access    = value.ctrl.prot.access;
      request.security  = value.ctrl.prot.security;
      request.privilege = value.ctrl.prot.privilege;

      return tagged Descriptor request;
   endfunction

   function ApbRequest#(`TLM_PRM) fromTLMRequest(TLMRequest#(`TLM_PRM) value);
      ApbRequest#(`TLM_PRM) request;
      case (value) matches
         tagged Descriptor .desc: begin

	    ApbProt prot = ?;
	    prot.access    = desc.access;
	    prot.security  = desc.security;
	    prot.privilege = desc.privilege;

            request.ctrl.command = getApbWrite(desc.command);
            request.ctrl.addr    = desc.addr;

	    request.ctrl.prot    = prot;

	    let be = '1;
	    if (desc.byte_enable matches tagged Specify .b)
	       be = b;

            request.strb         = be;
            request.data         = desc.data;
         end
         tagged Data .data: begin
            request.data         = data.data;
         end
      endcase
      return request;
   endfunction

endinstance

endpackage: ApbDefines


