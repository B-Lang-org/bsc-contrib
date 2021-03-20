// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AHBDefines;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import AHBArbiter::*;
import BUtils::*;
import Connectable::*;
import DefaultValue::*;
import FShow::*;
import Probe::*;
import TLM2::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typedef Bit#(addr_size)                  AHBAddr#(`TLM_PRM_DCL);
typedef Bit#(data_size)                  AHBData#(`TLM_PRM_DCL);

typedef enum { READ, WRITE } AHBWrite `dv;
typedef enum { OKAY, ERROR, RETRY, SPLIT } AHBResp `dv;
typedef enum { IDLE, BUSY, NONSEQ, SEQ } AHBTransfer `dv;
typedef enum { BITS8, BITS16, BITS32, BITS64, BITS128, BITS256, BITS512, BITS1024} AHBSize `dv;
typedef enum { SINGLE, INCR, WRAP4, INCR4, WRAP8, INCR8, WRAP16, INCR16 } AHBBurst `dv;

typedef Bit#(4) AHBProt;

typedef struct {
                AHBWrite             command;
                AHBSize              size;
                AHBBurst             burst;
                AHBTransfer          transfer;
                AHBProt              prot;
		AHBAddr#(`TLM_PRM)   addr;
		} AHBCtrl#(`TLM_PRM_DCL) `dv;

typedef struct {
		AHBCtrl#(`TLM_PRM) ctrl;
		AHBData#(`TLM_PRM) data;
		} AHBRequest#(`TLM_PRM_DCL) `dv;

typedef struct {
		AHBResp            status;
		AHBData#(`TLM_PRM) data;
		Maybe#(AHBWrite)   command;
		} AHBResponse#(`TLM_PRM_DCL) `dv;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

(* always_ready, always_enabled *)
interface AHBMaster#(`TLM_PRM_DCL);

   // Outputs
   (* result = "HADDR" *)
   method AHBAddr#(`TLM_PRM)  hADDR;
   (* result = "HWDATA" *)
   method AHBData#(`TLM_PRM)  hWDATA;
   (* result = "HWRITE" *)
   method AHBWrite              hWRITE;
   (* result = "HTRANS" *)
   method AHBTransfer           hTRANS;
   (* result = "HBURST" *)
   method AHBBurst              hBURST;
   (* result = "HSIZE" *)
   method AHBSize               hSIZE;
   (* result = "HPROT" *)
   method AHBProt               hPROT;
   // Inputs
   (* prefix = "", result = "unused0" *)
   method Action      hRDATA((* port = "HRDATA" *) AHBData#(`TLM_PRM) data);
   (* prefix = "", result = "unused1" *)
   method Action      hREADY((* port = "HREADY" *) Bool value);
   (* prefix = "", result = "unused2" *)
   method Action      hRESP((* port = "HRESP" *) AHBResp response);

endinterface


(* always_ready, always_enabled *)
interface AHBSlave#(`TLM_PRM_DCL);

    // Inputs
   (* prefix = "", result = "unused0" *)
   method Action      hADDR((* port = "HADDR" *)    AHBAddr#(`TLM_PRM) addr);
   (* prefix = "", result = "unused1" *)
   method Action      hWDATA((* port = "HWDATA" *)  AHBData#(`TLM_PRM) data);
   (* prefix = "", result = "unused2" *)
   method Action      hWRITE((* port = "HWRITE" *)  AHBWrite    value);
   (* prefix = "", result = "unused3" *)
   method Action      hTRANS((* port = "HTRANS" *)  AHBTransfer value);
   (* prefix = "", result = "unused4" *)
   method Action      hBURST((* port = "HBURST" *)  AHBBurst    value);
   (* prefix = "", result = "unused5" *)
   method Action      hSIZE((* port = "HSIZE" *)    AHBSize     value);
   (* prefix = "", result = "unused6" *)
   method Action      hPROT((* port = "HPROT" *)    AHBProt     value);

   // Outputs
   (* result = "HRDATA" *)
   method AHBData#(`TLM_PRM) hRDATA;
   (* result = "HREADY" *)
   method Bool               hREADY;
   (* result = "HRESP" *)
   method AHBResp            hRESP;

endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

(* always_ready, always_enabled *)
interface AHBSlaveSelector#(`TLM_PRM_DCL);
   method Bool   addrMatch(AHBAddr#(`TLM_PRM) value);
   (* prefix = "" *)
   method Action select((* port = "HSEL" *) Bool value);
endinterface

(* always_ready, always_enabled *)
interface AHBMasterArbiter;
   (* result = "HBUSREQ" *)
   method Bool        hBUSREQ;
   (* result = "HLOCK" *)
   method Bool        hLOCK;
   (* prefix = "" *)
   method Action      hGRANT((* port = "HGRANT" *) Bool value);
endinterface

(* always_ready, always_enabled *)
interface AHBMasterArbiterDual;
   (* prefix = "", result = "unused7" *)
   method Action      hBUSREQ((* port = "HBUSREQ" *) Bool value);
   (* prefix = "", result = "unused8" *)
   method Action      hLOCK((* port = "HLOCK" *)     Bool value);
   (* result = "HGRANT" *)
   method Bool hGRANT;
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AHBFabricMaster#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface AHBMaster#(`TLM_PRM)  bus;
   (* prefix = "" *)
   interface AHBMasterArbiter        arbiter;
endinterface

interface AHBFabricSlave#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface AHBSlave#(`TLM_PRM)         bus;
   (* prefix = "" *)
   interface AHBSlaveSelector#(`TLM_PRM) selector;
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AHBMasterXActor#(`TLM_RR_DCL, `TLM_PRM_DCL);
   interface TLMRecvIFC#(`TLM_RR)      tlm;
   (* prefix = "" *)
   interface AHBFabricMaster#(`TLM_PRM) fabric;
endinterface

interface AHBSlaveXActor#(`TLM_RR_DCL, `TLM_PRM_DCL);
   interface TLMSendIFC#(`TLM_RR)     tlm;
   (* prefix = "" *)
   interface AHBFabricSlave#(`TLM_PRM) fabric;
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance Connectable#(AHBMaster#(`TLM_PRM), AHBSlave#(`TLM_PRM));
   module mkConnection#(AHBMaster#(`TLM_PRM) m, AHBSlave#(`TLM_PRM) s )(Empty);

      rule master_to_slave;
	 s.hADDR(m.hADDR);
	 s.hWDATA(m.hWDATA);
	 s.hWRITE(m.hWRITE);
	 s.hTRANS(m.hTRANS);
	 s.hBURST(m.hBURST);
	 s.hSIZE(m.hSIZE);
	 s.hPROT(m.hPROT);
      endrule

      rule slave_to_master;
	 m.hRDATA(s.hRDATA);
	 m.hREADY(s.hREADY);
	 m.hRESP(s.hRESP);
      endrule

   endmodule
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance FShow#(AHBWrite);
   function Fmt fshow (AHBWrite label);
      case (label)
	 READ: return fshow("READ");
	 WRITE: return fshow("WRITE");
      endcase
   endfunction
endinstance

instance FShow#(AHBResp);
   function Fmt fshow (AHBResp label);
      case (label)
	 OKAY: return fshow("OKAY");
	 ERROR: return fshow("ERROR");
	 RETRY: return fshow("RETRY");
	 SPLIT: return fshow("SPLIT");
      endcase
   endfunction
endinstance

instance FShow#(AHBTransfer);
   function Fmt fshow (AHBTransfer label);
      case (label)
	 IDLE: return fshow("IDLE");
	 BUSY: return fshow("BUSY");
	 NONSEQ: return fshow("NONSEQ");
	 SEQ: return fshow("SEQ");
      endcase
   endfunction
endinstance

instance FShow#(AHBSize);
   function Fmt fshow (AHBSize label);
      case (label)
	 BITS8:    return fshow("BITS8");
	 BITS16:   return fshow("BITS16");
	 BITS32:   return fshow("BITS32");
	 BITS64:   return fshow("BITS64");
	 BITS128:  return fshow("BITS128");
	 BITS256:  return fshow("BITS256");
	 BITS512:  return fshow("BITS512");
	 BITS1024: return fshow("BITS1024");
      endcase
   endfunction
endinstance

instance FShow#(AHBBurst);
   function Fmt fshow (AHBBurst label);
      case (label)
	 SINGLE: return fshow("SINGLE");
	 INCR:   return fshow("INCR");
	 WRAP4:  return fshow("WRAP4");
	 INCR4:  return fshow("INCR4");
	 WRAP8:  return fshow("WRAP8");
	 INCR8:  return fshow("INCR8");
	 WRAP16: return fshow("WRAP16");
	 INCR16: return fshow("INCR16");
      endcase
   endfunction
endinstance

instance FShow#(AHBCtrl#(`TLM_PRM));
   function Fmt fshow (AHBCtrl#(`TLM_PRM) ctrl);
      return ($format("<AHBCTRL ",
	      +
	      fshow(ctrl.command)
	      +
	      fshow(" ")
	      +
	      fshow(ctrl.transfer)
	      +
	      fshow(" ")
	      +
	      fshow(ctrl.burst)
	      +
	      fshow(" ")
	      +
	      fshow(ctrl.addr)
	      +
	      fshow(" >")));
   endfunction
endinstance

instance FShow#(AHBRequest#(`TLM_PRM));
   function Fmt fshow (AHBRequest#(`TLM_PRM) req);
      return ($format("<AHBREQ ",
	      +
	      fshow(req.ctrl)
	      +
	      fshow(" ")
	      +
	      fshow(req.data)
	      +
	      fshow(" >")));
   endfunction
endinstance

instance FShow#(AHBResponse#(`TLM_PRM));
   function Fmt fshow (AHBResponse#(`TLM_PRM) resp);
      return ($format("<AHBRESP ",
	      +
	      fshow(resp.status)
	      +
	      fshow(" ")
	      +
	      fshow(resp.data)
	      +
	      fshow(" >")));
   endfunction
endinstance

////////////////////////////////////////////////////////////////////////////////
/// TLM conversion functions
/// TLM to AHB:
////////////////////////////////////////////////////////////////////////////////

function AHBCtrl#(`TLM_PRM) getAHBCtrl (RequestDescriptor#(`TLM_PRM) tlm_descriptor)
   provisos(AHBConvert#(AHBProt, cstm_type));

   AHBCtrl#(`TLM_PRM) ctrl;

   ctrl.command  = getAHBWrite(tlm_descriptor.command);
   ctrl.size     = getAHBSize(tlm_descriptor.burst_size);
   ctrl.burst    = getAHBBurst(tlm_descriptor);
   ctrl.transfer = IDLE; // set this later.
   ctrl.prot     = toAHB(tlm_descriptor.custom);
   ctrl.addr     = tlm_descriptor.addr;

   return ctrl;

endfunction

function AHBWrite getAHBWrite(TLMCommand command);
   case (command)
      READ:  return READ;
      WRITE: return WRITE;
   endcase
endfunction

function AHBBurst getAHBBurst(RequestDescriptor#(`TLM_PRM) tlm_descriptor);
   let burst_mode = tlm_descriptor.burst_mode;
   let burst_length = tlm_descriptor.burst_length;
   case (tuple2(burst_mode, burst_length)) matches
      {INCR,  1}: return SINGLE;
      {INCR,  4}: return INCR4;
      {INCR,  8}: return INCR8;
      {INCR, 16}: return INCR16;
      {     WRAP,  4}: return WRAP4;
      {     WRAP,  8}: return WRAP8;
      {     WRAP, 16}: return WRAP16;
      { CNST, .n}: return SINGLE;
      {     WRAP, .n}: return SINGLE;
      {INCR, .n}: return INCR;
              default: return SINGLE;
   endcase
endfunction

function AHBSize getAHBSize(TLMBurstSize#(`TLM_PRM) incr);
   Bit#(8) value = zExtend(incr);
   case (value)
      (  1 - 1): return BITS8;
      (  2 - 1): return BITS16;
      (  4 - 1): return BITS32;
      (  8 - 1): return BITS64;
      ( 16 - 1): return BITS128;
      ( 32 - 1): return BITS256;
      ( 64 - 1): return BITS512;
      (128 - 1): return BITS1024;
        default: return BITS8;
   endcase
endfunction

function Integer getAHBCycleCount (AHBBurst burst);
   case (burst)
      SINGLE:         return 1;
      WRAP4, INCR4:   return 4;
      WRAP8, INCR8:   return 8;
      WRAP16, INCR16: return 16;
      INCR:           return 1; // needed for last cycle;
   endcase
endfunction

function AHBData#(`TLM_PRM) getAHBData (RequestDescriptor#(`TLM_PRM) tlm_descriptor);

   AHBData#(`TLM_PRM) data = tlm_descriptor.data;

   return data;

endfunction

////////////////////////////////////////////////////////////////////////////////
/// AHB to TLM:
////////////////////////////////////////////////////////////////////////////////

function RequestDescriptor#(`TLM_PRM) fromAHBCtrl (AHBCtrl#(`TLM_PRM) ctrl)
   provisos(DefaultValue#(RequestDescriptor#(`TLM_PRM)),
	    AHBConvert#(AHBProt, cstm_type));

   RequestDescriptor#(`TLM_PRM) desc = defaultValue;

   Tuple2#(TLMBurstMode,  TLMUInt#(`TLM_PRM)) pair = fromAHBBurst(ctrl.burst);
   let burst_mode       = tpl_1(pair);
   let length           = tpl_2(pair);

   desc.command         = fromAHBWrite(ctrl.command);
   desc.mode            = REGULAR;
   desc.addr            = ctrl.addr;
   desc.byte_enable     = '1;
   desc.custom          = fromAHB(ctrl.prot);
   desc.burst_size      = fromAHBSize(ctrl.size);
   desc.burst_mode      = burst_mode;
   desc.burst_length    = length;

/* -----\/----- EXCLUDED -----\/-----

   desc.data            = 0; // added later
   desc.burst_length      = fromAxiLen(addr_cmd.len);
   desc.burst_mode      = fromAxiBurst(addr_cmd.burst);
   desc.burst_size = fromAxiSize(addr_cmd. size);
   desc.prty = 0;
   desc.thread_id = 0;
   desc.transaction_id = fromAxiId(addr_cmd.id);
   desc.export_id = 0;
 -----/\----- EXCLUDED -----/\----- */

   return desc;

endfunction

function TLMCommand fromAHBWrite(AHBWrite command);
   case (command)
      READ:  return READ;
      WRITE: return WRITE;
   endcase
endfunction

function TLMStatus fromAHBResp(AHBResp resp);
   case (resp)
      OKAY:    return SUCCESS;
      ERROR:   return ERROR;
      RETRY:   return ERROR;
      SPLIT:   return ERROR;
      default: return ERROR;
     endcase
endfunction

function TLMBurstSize#(`TLM_PRM) fromAHBSize(AHBSize size);
   Bit#(8) value = 0;
   case (size)
      BITS8:    value = (  1 - 1);
      BITS16:   value = (  2 - 1);
      BITS32:   value = (  4 - 1);
      BITS64:   value = (  8 - 1);
      BITS128:  value = ( 16 - 1);
      BITS256:  value = ( 32 - 1);
      BITS512:  value = ( 64 - 1);
      BITS1024: value = (128 - 1);
      default:  value = (  1 - 1);
   endcase
   return zExtend(value);
endfunction

function Tuple2#(TLMBurstMode, TLMUInt#(`TLM_PRM)) fromAHBBurst(AHBBurst value);
   case (value)
      SINGLE:  return tuple2(INCR, 1);
      INCR4:   return tuple2(INCR, 4);
      INCR8:   return tuple2(INCR, 8);
      INCR16:  return tuple2(INCR, 16);
      WRAP4:   return tuple2(WRAP, 4);
      WRAP8:   return tuple2(WRAP, 8);
      WRAP16:  return tuple2(WRAP, 16);
      INCR:    return tuple2(INCR, 0);
      default: return tuple2(INCR, 1);
   endcase
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typedef struct {AHBProt              prot;
		AHBResp              status;
		} AHBCustom `dv;

instance DefaultValue #(AHBCustom);
   function defaultValue ();
      return AHBCustom { prot: 0, status: OKAY};
   endfunction
endinstance

instance FShow#(AHBCustom);
   function Fmt fshow (AHBCustom value);
      return ($format("<AHBCustom %d ", value.prot)
	      +
	      fshow(value.status)
	      +
	      fshow(" >"));
   endfunction
endinstance

typeclass AHBConvert#(type a, type b);
   function a       toAHB(b value);
   function b       fromAHB(a value);
endtypeclass

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance AHBConvert#(AHBProt, AHBProt);
   function AHBProt toAHB(AHBProt value);
      return value;
   endfunction
   function AHBProt fromAHB(AHBProt value);
      return value;
   endfunction
endinstance

instance AHBConvert#(AHBProt, AHBCustom);
   function AHBProt toAHB(AHBCustom value);
      return value.prot;
   endfunction
   function AHBCustom fromAHB(AHBProt value);
      AHBCustom custom = unpack(0);
      custom.prot = value;
      return custom;
   endfunction
endinstance

instance AHBConvert#(AHBProt, Bit#(0));
   function AHBProt toAHB(Bit#(0) value);
      return 0;
   endfunction
   function Bit#(0) fromAHB(AHBProt value);
      return ?;
   endfunction
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance AHBConvert#(AHBResp, AHBResp);
   function AHBResp toAHB(AHBResp value);
      return value;
   endfunction
   function AHBResp fromAHB(AHBResp value);
      return value;
   endfunction
endinstance

instance AHBConvert#(AHBResp, AHBCustom);
   function AHBResp toAHB(AHBCustom value);
      return value.status;
   endfunction
   function AHBCustom fromAHB(AHBResp value);
      AHBCustom custom = unpack(0);
      custom.status = value;
      return custom;
   endfunction
endinstance

instance AHBConvert#(AHBResp, Bit#(0));
   function AHBResp toAHB(Bit#(0) value);
      return OKAY;
   endfunction
   function Bit#(0) fromAHB(AHBResp value);
      return ?;
   endfunction
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance Arbitable#(AHBMasterArbiter);
   module mkArbiterRequest#(AHBMasterArbiter ifc) (ArbiterRequest_IFC);

      Reg#(Bool) grant_wire <- mkDWire(False);

      rule every;
	 ifc.hGRANT(grant_wire);
      endrule

      method Bool request();
	 return ifc.hBUSREQ;
      endmethod

      method Bool lock();
	 return ifc.hLOCK;
      endmethod

      method Action grant();
	 grant_wire <= True;
      endmethod
   endmodule
endinstance

instance Arbitable#(AHBFabricMaster#(`TLM_PRM));
   module mkArbiterRequest#(AHBFabricMaster#(`TLM_PRM) ifc) (ArbiterRequest_IFC);
      let _ifc <- mkArbiterRequest(ifc.arbiter);
      return _ifc;
   endmodule
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

endpackage
