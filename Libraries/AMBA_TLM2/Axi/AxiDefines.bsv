// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AxiDefines;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import Arbiter::*;
import Bus::*;
import Connectable::*;
import DefaultValue::*;
import FShow::*;
import TLM2::*;
import BUtils::*;
import Vector::*;

`include "TLM.defines"

 ////////////////////////////////////////////////////////////////////////////////
/// Data Structures
////////////////////////////////////////////////////////////////////////////////

typedef Bit#(addr_size)                  AxiAddr#(`TLM_PRM_DCL);
typedef Bit#(data_size)                  AxiData#(`TLM_PRM_DCL);
typedef Bit#(TDiv#(data_size, 8))        AxiByteEn#(`TLM_PRM_DCL);

typedef Bit#(id_size)                        AxiId#(`TLM_PRM_DCL); // Unique id
typedef Bit#(4)                              AxiLen;  // 1 - 16
typedef Bit#(3)                              AxiSize; // width in bytes
typedef Bit#(4)                              AxiCache;
typedef Bit#(3)                              AxiProt;

typedef enum {FIXED, INCR, WRAP}             AxiBurst deriving (Bits, Eq, Bounded);
typedef enum {NORMAL, EXCLUSIVE, LOCKED}     AxiLock  deriving (Bits, Eq, Bounded);
typedef enum {OKAY, EXOKAY, SLVERR, DECERR } AxiResp deriving (Bits, Eq, Bounded);


typedef struct {
                AxiId#(`TLM_PRM)     id;
                AxiLen               len;
                AxiSize              size;
                AxiBurst             burst;
                AxiLock              lock;
                AxiCache             cache;
                AxiProt              prot;
                AxiAddr#(`TLM_PRM)   addr;
		} AxiAddrCmd#(`TLM_PRM_DCL) `dv;

instance DefaultValue#(AxiAddrCmd#(`TLM_PRM));
   defaultValue = AxiAddrCmd {
      id:     0,
      len:    0,
      size:   0,
      burst:  INCR,
      lock:   NORMAL,
      cache:  0,
      prot:   0,
      addr:   ?
      };
endinstance

typedef struct {
		AxiId#(`TLM_PRM)     id;
		AxiData#(`TLM_PRM)   data;
		AxiByteEn#(`TLM_PRM) strb;
		Bool                 last;
		} AxiWrData#(`TLM_PRM_DCL) `dv;

instance DefaultValue#(AxiWrData#(`TLM_PRM));
   defaultValue = AxiWrData {
      id:     0,
      data:   ?,
      strb:   maxBound,
      last:   True
      };
endinstance

typedef struct {
		AxiId#(`TLM_PRM)     id;
		AxiData#(`TLM_PRM)   data;
		AxiResp              resp;
		Bool                 last;
		} AxiRdResp#(`TLM_PRM_DCL) `dv;

instance DefaultValue#(AxiRdResp#(`TLM_PRM));
   defaultValue = AxiRdResp {
      id:     0,
      data:   ?,
      resp:   OKAY,
      last:   True
      };
endinstance

typedef struct {
		AxiId#(`TLM_PRM)     id;
		AxiResp              resp;
		} AxiWrResp#(`TLM_PRM_DCL) `dv;

instance DefaultValue#(AxiWrResp#(`TLM_PRM));
   defaultValue = AxiWrResp {
      id:     0,
      resp:   OKAY
      };
endinstance


////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance BusPayload#(AxiAddrCmd#(`TLM_PRM), TLMId#(`TLM_PRM));
   function isLast (payload);
      return True;
   endfunction
   function getId(payload);
      return fromAxiId(payload.id);
   endfunction
   function setId(payload, value);
      payload.id = getAxiId(value);
      return payload;
   endfunction
endinstance

instance BusPayload#(AxiWrData#(`TLM_PRM), TLMId#(`TLM_PRM));
   function isLast (payload);
      return payload.last;
   endfunction
   function getId(payload);
      return fromAxiId(payload.id);
   endfunction
   function setId(payload, value);
      payload.id = getAxiId(value);
      return payload;
   endfunction
endinstance

instance BusPayload#(AxiWrResp#(`TLM_PRM), TLMId#(`TLM_PRM));
   function isLast (payload);
      return True;
   endfunction
   function getId(payload);
      return fromAxiId(payload.id);
   endfunction
   function setId(payload, value);
      payload.id = getAxiId(value);
      return payload;
   endfunction
endinstance

instance BusPayload#(AxiRdResp#(`TLM_PRM), TLMId#(`TLM_PRM));
   function isLast (payload);
      return payload.last;
   endfunction
   function getId(payload);
      return fromAxiId(payload.id);
   endfunction
   function setId(payload, value);
      payload.id = getAxiId(value);
      return payload;
   endfunction
endinstance

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////

(* always_ready, always_enabled *)
interface AxiWrMaster#(`TLM_PRM_DCL);

   // Address Outputs
   (* result = "AWID" *)
   method AxiId#(`TLM_PRM)   awID;
   (* result = "AWADDR" *)
   method AxiAddr#(`TLM_PRM) awADDR;
   (* result = "AWLEN" *)
   method AxiLen               awLEN;
   (* result = "AWSIZE" *)
   method AxiSize              awSIZE;
   (* result = "AWBURST" *)
   method AxiBurst             awBURST;
   (* result = "AWLOCK" *)
   method AxiLock              awLOCK;
   (* result = "AWCACHE" *)
   method AxiCache             awCACHE;
   (* result = "AWPROT" *)
   method AxiProt              awPROT;
   (* result = "AWVALID" *)
   method Bool                 awVALID;

   // Address Inputs
   (* prefix = "", result = "unusedwm0" *)
   method Action awREADY((* port = "AWREADY" *) Bool value);

   // Data Outputs
   (* result = "WID" *)
   method AxiId#(`TLM_PRM)     wID;
   (* result = "WDATA" *)
   method AxiData#(`TLM_PRM)   wDATA;
   (* result = "WSTRB" *)
   method AxiByteEn#(`TLM_PRM) wSTRB;
   (* result = "WLAST" *)
   method Bool                   wLAST;
   (* result = "WVALID" *)
   method Bool                   wVALID;

   // Data Inputs
   (* prefix = "", result = "unusedwm1" *)
   method Action wREADY((* port = "WREADY" *) Bool value);

   // Response Outputs
   (* result = "BREADY" *)
   method Bool                   bREADY;

   // Response Inputs
   (* prefix = "", result = "unusedwm2" *)
   method Action bID((* port = "BID" *) AxiId#(`TLM_PRM) value);
   (* prefix = "", result = "unusedwm3" *)
   method Action bRESP((* port = "BRESP" *) AxiResp value);
   (* prefix = "", result = "unusedwm4" *)
   method Action bVALID((* port = "BVALID" *) Bool value);

endinterface

(* always_ready, always_enabled *)
interface AxiRdMaster#(`TLM_PRM_DCL);

   // Address Outputs
   (* result = "ARID" *)
   method AxiId#(`TLM_PRM)   arID;
   (* result = "ARADDR" *)
   method AxiAddr#(`TLM_PRM) arADDR;
   (* result = "ARLEN" *)
   method AxiLen               arLEN;
   (* result = "ARSIZE" *)
   method AxiSize              arSIZE;
   (* result = "ARBURST" *)
   method AxiBurst             arBURST;
   (* result = "ARLOCK" *)
   method AxiLock              arLOCK;
   (* result = "ARCACHE" *)
   method AxiCache             arCACHE;
   (* result = "ARPROT" *)
   method AxiProt              arPROT;
   (* result = "ARVALID" *)
   method Bool                 arVALID;

   // Address Inputs
   (* prefix = "", result = "unusedrm0" *)
   method Action arREADY((* port = "ARREADY" *) Bool value);

   // Response Outputs
   (* result = "RREADY" *)
   method Bool                   rREADY;

   // Response Inputs
   (* prefix = "", result = "unusedrm1" *)
   method Action rID((* port = "RID" *) AxiId#(`TLM_PRM) value);
   (* prefix = "", result = "unusedrm2" *)
   method Action rDATA((* port = "RDATA" *) AxiData#(`TLM_PRM) value);
   (* prefix = "", result = "unusedrm3" *)
   method Action rRESP((* port = "RRESP" *) AxiResp value);
   (* prefix = "", result = "unusedrm4" *)
   method Action rLAST((* port = "RLAST" *) Bool value);
   (* prefix = "", result = "unusedrm5" *)
   method Action rVALID((* port = "RVALID" *) Bool value);

endinterface


(* always_ready, always_enabled *)
interface AxiWrSlave#(`TLM_PRM_DCL);

   // Address Inputs
   (* prefix = "", result = "unusedws0" *)
   method Action awID((* port = "AWID" *) AxiId#(`TLM_PRM) value);
   (* prefix = "", result = "unusedws1" *)
   method Action awADDR((* port = "AWADDR" *) AxiAddr#(`TLM_PRM) value);
   (* prefix = "", result = "unusedws2" *)
   method Action awLEN((* port = "AWLEN" *) AxiLen value);
   (* prefix = "", result = "unusedws3" *)
   method Action awSIZE((* port = "AWSIZE" *) AxiSize value);
   (* prefix = "", result = "unusedws4" *)
   method Action awBURST((* port = "AWBURST" *) AxiBurst value);
   (* prefix = "", result = "unusedws5" *)
   method Action awLOCK((* port = "AWLOCK" *) AxiLock value);
   (* prefix = "", result = "unusedws6" *)
   method Action awCACHE((* port = "AWCACHE" *) AxiCache value);
   (* prefix = "", result = "unusedws7" *)
   method Action awPROT((* port = "AWPROT" *) AxiProt value);
   (* prefix = "", result = "unusedws8" *)
   method Action awVALID((* port = "AWVALID" *) Bool value);

   // Address Outputs
   (* result = "AWREADY" *)
   method Bool                  awREADY;

   // Data Inputs
   (* prefix = "", result = "unusedws9" *)
   method Action wID((* port = "WID" *) AxiId#(`TLM_PRM) value);
   (* prefix = "", result = "unusedws10" *)
   method Action wDATA((* port = "WDATA" *) AxiData#(`TLM_PRM) value);
   (* prefix = "", result = "unusedws11" *)
   method Action wSTRB((* port = "WSTRB" *) AxiByteEn#(`TLM_PRM) value);
   (* prefix = "", result = "unusedws12" *)
   method Action wLAST((* port = "WLAST" *) Bool value);
   (* prefix = "", result = "unusedws13" *)
   method Action wVALID((* port = "WVALID" *) Bool value);

   // Data Ouptuts
   (* result = "WREADY" *)
   method Bool                   wREADY;

   // Response Inputs
   (* prefix = "", result = "unusedws14" *)
   method Action bREADY((* port = "BREADY" *) Bool value);

   // Response Outputs
   (* result = "BID" *)
   method AxiId#(`TLM_PRM)     bID;
   (* result = "BRESP" *)
   method AxiResp                bRESP;
   (* result = "BVALID" *)
   method Bool                   bVALID;

endinterface

(* always_ready, always_enabled *)
interface AxiRdSlave#(`TLM_PRM_DCL);

   // Address Inputs
   (* prefix = "", result = "unusedrs0" *)
   method Action arID((* port = "ARID" *) AxiId#(`TLM_PRM) value);
   (* prefix = "", result = "unusedrs1" *)
   method Action arADDR((* port = "ARADDR" *) AxiAddr#(`TLM_PRM) value);
   (* prefix = "", result = "unusedrs2" *)
   method Action arLEN((* port = "ARLEN" *) AxiLen value);
   (* prefix = "", result = "unusedrs3" *)
   method Action arSIZE((* port = "ARSIZE" *) AxiSize value);
   (* prefix = "", result = "unusedrs4" *)
   method Action arBURST((* port = "ARBURST" *) AxiBurst value);
   (* prefix = "", result = "unusedrs5" *)
   method Action arLOCK((* port = "ARLOCK" *) AxiLock value);
   (* prefix = "", result = "unusedrs6" *)
   method Action arCACHE((* port = "ARCACHE" *) AxiCache value);
   (* prefix = "", result = "unusedrs7" *)
   method Action arPROT((* port = "ARPROT" *) AxiProt value);
   (* prefix = "", result = "unusedrs8" *)
   method Action arVALID((* port = "ARVALID" *) Bool value);

   // Address Outputs
   (* result = "ARREADY" *)
   method Bool                  arREADY;

   // Response Inputs
   (* prefix = "", result = "unusedrs9" *)
   method Action rREADY((* port = "RREADY" *) Bool value);

   // Response Outputs
   (* result = "RID" *)
   method AxiId#(`TLM_PRM)     rID;
   (* result = "RDATA" *)
   method AxiData#(`TLM_PRM)   rDATA;
   (* result = "RRESP" *)
   method AxiResp                rRESP;
   (* result = "RLAST" *)
   method Bool                   rLAST;
   (* result = "RVALID" *)
   method Bool                   rVALID;

endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AxiRdBusMaster#(`TLM_PRM_DCL);
   interface BusSend#(AxiAddrCmd#(`TLM_PRM)) addr;
   interface BusRecv#(AxiRdResp#(`TLM_PRM))  resp;
endinterface

interface AxiWrBusMaster#(`TLM_PRM_DCL);
   interface BusSend#(AxiAddrCmd#(`TLM_PRM)) addr;
   interface BusSend#(AxiWrData#(`TLM_PRM))  data;
   interface BusRecv#(AxiWrResp#(`TLM_PRM))  resp;
endinterface

interface AxiRdBusSlave#(`TLM_PRM_DCL);
   interface BusRecv#(AxiAddrCmd#(`TLM_PRM)) addr;
   interface BusSend#(AxiRdResp#(`TLM_PRM))  resp;
endinterface

interface AxiWrBusSlave#(`TLM_PRM_DCL);
   interface BusRecv#(AxiAddrCmd#(`TLM_PRM)) addr;
   interface BusRecv#(AxiWrData#(`TLM_PRM))  data;
   interface BusSend#(AxiWrResp#(`TLM_PRM))  resp;
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AxiRdFabricMaster#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface AxiRdMaster#(`TLM_PRM) bus;
endinterface

interface AxiRdFabricSlave#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface AxiRdSlave#(`TLM_PRM) bus;
   method Bool addrMatch(AxiAddr#(`TLM_PRM) value);
endinterface

interface AxiWrFabricMaster#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface AxiWrMaster#(`TLM_PRM) bus;
endinterface

interface AxiWrFabricSlave#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface AxiWrSlave#(`TLM_PRM) bus;
   method Bool addrMatch(AxiAddr#(`TLM_PRM) value);
endinterface

interface AxiRdMasterXActorIFC#(`TLM_RR_DCL, `TLM_PRM_DCL);
   interface TLMRecvIFC#(`TLM_RR)        tlm;
   (* prefix = "" *)
   interface AxiRdFabricMaster#(`TLM_PRM) fabric;
endinterface

interface AxiWrMasterXActorIFC#(`TLM_RR_DCL, `TLM_PRM_DCL);
   interface TLMRecvIFC#(`TLM_RR)        tlm;
   (* prefix = "" *)
   interface AxiWrFabricMaster#(`TLM_PRM) fabric;
endinterface

interface AxiRdSlaveXActorIFC#(`TLM_RR_DCL, `TLM_PRM_DCL);
   interface TLMSendIFC#(`TLM_RR)       tlm;
   (* prefix = "" *)
   interface AxiRdFabricSlave#(`TLM_PRM) fabric;
endinterface

interface AxiWrSlaveXActorIFC#(`TLM_RR_DCL, `TLM_PRM_DCL);
   interface TLMSendIFC#(`TLM_RR)       tlm;
   (* prefix = "" *)
   interface AxiWrFabricSlave#(`TLM_PRM) fabric;
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance Connectable#(AxiWrMaster#(`TLM_PRM), AxiWrSlave#(`TLM_PRM));
   module mkConnection#(AxiWrMaster#(`TLM_PRM) m, AxiWrSlave#(`TLM_PRM) s )(Empty);

      rule master_to_slave_addr_data;
	 // Address Signals
	 s.awID(m.awID);
	 s.awADDR(m.awADDR);
	 s.awLEN(m.awLEN);
	 s.awSIZE(m.awSIZE);
	 s.awBURST(m.awBURST);
	 s.awLOCK(m.awLOCK);
	 s.awCACHE(m.awCACHE);
	 s.awPROT(m.awPROT);
	 s.awVALID(m.awVALID);
	 // Data Signals
	 s.wID(m.wID);
	 s.wDATA(m.wDATA);
	 s.wSTRB(m.wSTRB);
	 s.wLAST(m.wLAST);
	 s.wVALID(m.wVALID);
      endrule

      rule master_to_slave_response;
	 // Response Signals
	 s.bREADY(m.bREADY);
      endrule

      rule slave_to_master_addr_data;
	 // Address Signals
	 m.awREADY(s.awREADY);
	 // Data Signals
	 m.wREADY(s.wREADY);
      endrule

      rule slave_to_master_response;
	 // Response Signals
	 m.bID(s.bID);
	 m.bRESP(s.bRESP);
	 m.bVALID(s.bVALID);
      endrule

   endmodule
endinstance

instance Connectable#(AxiRdMaster#(`TLM_PRM), AxiRdSlave#(`TLM_PRM));
   module mkConnection#(AxiRdMaster#(`TLM_PRM) m, AxiRdSlave#(`TLM_PRM) s )(Empty);

      rule master_to_slave_addr;
	 // Address Signals
	 s.arID(m.arID);
	 s.arADDR(m.arADDR);
	 s.arLEN(m.arLEN);
	 s.arSIZE(m.arSIZE);
	 s.arBURST(m.arBURST);
	 s.arLOCK(m.arLOCK);
	 s.arCACHE(m.arCACHE);
	 s.arPROT(m.arPROT);
	 s.arVALID(m.arVALID);
      endrule

      rule master_to_slave_response;
	 // Response Signals
	 s.rREADY(m.rREADY);
      endrule

      rule slave_to_master_addr;
	 // Address Signals
	 m.arREADY(s.arREADY);
      endrule

      rule slave_to_master_response;
	 // Response Signals
	 m.rID(s.rID);
	 m.rDATA(s.rDATA);
	 m.rRESP(s.rRESP);
	 m.rLAST(s.rLAST);
	 m.rVALID(s.rVALID);
      endrule

   endmodule
endinstance

////////////////////////////////////////////////////////////////////////////////
/// TLM conversion functions
/// TLM to AXI:
////////////////////////////////////////////////////////////////////////////////

function AxiAddrCmd#(`TLM_PRM) getAxiAddrCmd (RequestDescriptor#(`TLM_PRM) tlm_descriptor)
   provisos(AxiConvert#(AxiProt, cstm_type),
	    AxiConvert#(AxiCache, cstm_type),
	    AxiConvert#(AxiLock, cstm_type)
	    );

   AxiAddrCmd#(`TLM_PRM) addr_cmd = unpack(0);
   addr_cmd.id    = getAxiId(tlm_descriptor.transaction_id);
   addr_cmd.len   = getAxiLen(tlm_descriptor.burst_length);
   addr_cmd.size  = getAxiSize(tlm_descriptor.burst_size);
   addr_cmd.burst = getAxiBurst(tlm_descriptor.burst_mode);
   addr_cmd.lock  = toAxi(tlm_descriptor.custom);
   addr_cmd.cache = toAxi(tlm_descriptor.custom);
   addr_cmd.prot  = toAxi(tlm_descriptor.custom);
   addr_cmd.addr  = tlm_descriptor.addr;

   return addr_cmd;

endfunction

function AxiWrData#(`TLM_PRM) getFirstAxiWrData (RequestDescriptor#(`TLM_PRM) tlm_descriptor);
   AxiWrData#(`TLM_PRM) wr_data = unpack(0);
   wr_data.id   = getAxiId(tlm_descriptor.transaction_id);
   wr_data.data = tlm_descriptor.data;
   wr_data.strb = getAxiByteEn(tlm_descriptor);
   wr_data.last = (tlm_descriptor.burst_length == 1);
   return wr_data;
endfunction

function AxiByteEn#(`TLM_PRM) getAxiByteEn (RequestDescriptor#(`TLM_PRM) tlm_descriptor);
   Bit#(TLog#(SizeOf#(AxiByteEn#(`TLM_PRM)))) addr = zExtend(tlm_descriptor.addr);
   AxiByteEn#(`TLM_PRM) all_ones  = unpack('1);
   AxiByteEn#(`TLM_PRM) all_zeros = unpack(0);
   let tlm_byte_enable = tlm_descriptor.byte_enable;
   let out = tlm_byte_enable;
   if (tlm_byte_enable == all_zeros || tlm_byte_enable == all_ones)
      begin
	 let mask = ~(all_ones << ({1'b0,tlm_descriptor.burst_size} + 1));
	 out = (mask << addr);
      end
   return out;
endfunction


function AxiLen getAxiLen(TLMUInt#(`TLM_PRM) burst_length);
   AxiLen length = cExtend(burst_length - 1);
   return length;
endfunction

function AxiSize getAxiSize(TLMBurstSize#(`TLM_PRM) incr);
   Bit#(8) value = cExtend(incr);
   case (value)
      (  1 - 1): return 0;
      (  2 - 1): return 1;
      (  4 - 1): return 2;
      (  8 - 1): return 3;
      ( 16 - 1): return 4;
      ( 32 - 1): return 5;
      ( 64 - 1): return 6;
      (128 - 1): return 7;
   endcase
endfunction

function AxiBurst getAxiBurst(TLMBurstMode burst_mode);
   case (burst_mode)
      INCR: return INCR;
      CNST: return FIXED;
      WRAP: return WRAP;
   endcase
endfunction

function AxiId#(`TLM_PRM) getAxiId(TLMId#(`TLM_PRM) transaction_id);
   return cExtend(transaction_id);
endfunction

function AxiResp getAxiResp(TLMStatus status);
   case (status)
      SUCCESS:     return OKAY;
      ERROR:       return SLVERR;
      NO_RESPONSE: return DECERR;
      UNKNOWN:     return EXOKAY;
     endcase
endfunction

////////////////////////////////////////////////////////////////////////////////
/// AXI to TLM:
////////////////////////////////////////////////////////////////////////////////

function RequestDescriptor#(`TLM_PRM) fromAxiAddrCmd (AxiAddrCmd#(`TLM_PRM) addr_cmd)
   provisos(Bits#(RequestDescriptor#(`TLM_PRM), s0),
	    AxiConvert#(AxiCustom, cstm_type));

   RequestDescriptor#(`TLM_PRM) desc = unpack(0);
   desc.mode            = REGULAR;
   desc.addr            = addr_cmd.addr;
   desc.burst_length    = fromAxiLen(addr_cmd.len);
   desc.burst_mode      = fromAxiBurst(addr_cmd.burst);
   desc.burst_size      = fromAxiSize(addr_cmd.size);
   desc.prty            = 0;
   desc.thread_id       = 0;
   desc.transaction_id  = fromAxiId(addr_cmd.id);
   desc.export_id       = 0;
   desc.custom          = fromAxi(updateProt(fromAxi(addr_cmd.prot), toAxi(desc.custom)));
   desc.custom          = fromAxi(updateCache(fromAxi(addr_cmd.cache), toAxi(desc.custom)));
   desc.custom          = fromAxi(updateLock(fromAxi(addr_cmd.lock), toAxi(desc.custom)));

   desc.command         = READ; // added later
   desc.data            = 0;    // added later
   desc.byte_enable     = '1;   // added later

   return desc;
endfunction

function TLMUInt#(`TLM_PRM) fromAxiLen(AxiLen len);
   let burst_length = unpack(zExtend(len) + 1);
   return burst_length;
endfunction

function TLMBurstMode fromAxiBurst(AxiBurst burst);
   case (burst)
      INCR:  return INCR;
      FIXED: return CNST;
      WRAP:  return WRAP;
   endcase
endfunction

function TLMBurstSize#(`TLM_PRM) fromAxiSize(AxiSize size);
   Bit#(TAdd#(SizeOf#(TLMBurstSize#(`TLM_PRM)), 1)) incr;
   incr = (1 << size) - 1;
   return zExtend(incr);
endfunction

function TLMId#(`TLM_PRM) fromAxiId(AxiId#(`TLM_PRM) id);
   return cExtend(id);
endfunction

function TLMStatus fromAxiResp(AxiResp resp);
   case (resp)
      OKAY:    return SUCCESS;
      EXOKAY:  return UNKNOWN;
      SLVERR:  return ERROR;
      DECERR:  return NO_RESPONSE;
     endcase
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance Arbitable#(AxiWrBusMaster#(`TLM_PRM));
   module mkArbiterRequest#(AxiWrBusMaster#(`TLM_PRM) master) (ArbiterRequest_IFC);

      let addr_req <- mkArbiterRequest(master.addr);

      method Bool request;
	 return addr_req.request;
      endmethod
      method Bool lock;
	 return master.addr.data.lock == LOCKED;
      endmethod
      method Action grant;
	 dummyAction;
      endmethod

   endmodule
endinstance


instance Arbitable#(AxiRdBusMaster#(`TLM_PRM));
   module mkArbiterRequest#(AxiRdBusMaster#(`TLM_PRM) master) (ArbiterRequest_IFC);

      let addr_req <- mkArbiterRequest(master.addr);

      method Bool request;
	 return addr_req.request;
      endmethod
      method Bool lock;
	 return master.addr.data.lock == LOCKED;
      endmethod
      method Action grant;
	 dummyAction;
      endmethod

   endmodule
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance FShow#(AxiBurst);
   function Fmt fshow (AxiBurst label);
      case (label)
	 FIXED: return fshow("FIXED");
	 INCR:  return fshow("INCR");
	 WRAP:  return fshow("WRAP");
      endcase
   endfunction
endinstance

instance FShow#(AxiLock);
   function Fmt fshow (AxiLock label);
      case (label)
	 NORMAL:    return fshow("NORMAL");
	 EXCLUSIVE: return fshow("EXCLSV");
	 LOCKED:    return fshow("LOCKED");
      endcase
   endfunction
endinstance


instance FShow#(AxiResp);
   function Fmt fshow (AxiResp label);
      case (label)
	 OKAY:   return fshow("OKAY");
	 EXOKAY: return fshow("EXOKAY");
	 SLVERR: return fshow("SLVERR");
	 DECERR: return fshow("DECERR");
      endcase
   endfunction
endinstance


////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typedef struct {
		AxiLock              lock;
		AxiCache             cache;
		AxiProt              prot;
		} AxiCustom deriving (Eq, Bits, Bounded);

instance DefaultValue #(AxiCustom);
   function defaultValue ();
      return AxiCustom { lock: NORMAL, cache: 0, prot: 0};
   endfunction
endinstance

instance FShow#(AxiCustom);
   function Fmt fshow (AxiCustom value);
      return ($format("<AxiCustom ")
	      +
	      fshow(value.lock)
	      +
	      $format(" ")
	      +
	      fshow(value.cache)
	      +
	      $format(" ")
	      +
	      fshow(value.prot)
	      +
	      $format(" >")
	      );
   endfunction
endinstance

typeclass AxiConvert#(type a, type b);
   function a       toAxi(b value);
   function b       fromAxi(a value);
endtypeclass

instance AxiConvert#(AxiProt, AxiProt);
   function AxiProt toAxi(AxiProt value);
      return value;
   endfunction
   function AxiProt fromAxi(AxiProt value);
      return value;
   endfunction
endinstance

instance AxiConvert#(AxiProt, AxiCustom);
   function AxiProt toAxi(AxiCustom value);
      return value.prot;
   endfunction
   function AxiCustom fromAxi(AxiProt value);
      AxiCustom custom = unpack(0);
      custom.prot = value;
      return custom;
   endfunction
endinstance

instance AxiConvert#(AxiProt, Bit#(0));
   function AxiProt toAxi(Bit#(0) value);
      return 0;
   endfunction
   function Bit#(0) fromAxi(AxiProt value);
      return ?;
   endfunction
endinstance

instance AxiConvert#(AxiProt, Bit#(9));
   function AxiProt toAxi(Bit#(9) value);
      return unpack(truncate(value));
   endfunction
   function Bit#(9) fromAxi(AxiProt value);
      return zExtend(pack(value));
   endfunction
endinstance

function AxiCustom updateProt(AxiProt prot, AxiCustom custom);
   custom.prot = prot;
   return custom;
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance AxiConvert#(AxiCache, AxiCache);
   function AxiCache toAxi(AxiCache value);
      return value;
   endfunction
   function AxiCache fromAxi(AxiCache value);
      return value;
   endfunction
endinstance

instance AxiConvert#(AxiCache, AxiCustom);
   function AxiCache toAxi(AxiCustom value);
      return value.cache;
   endfunction
   function AxiCustom fromAxi(AxiCache value);
      AxiCustom custom = unpack(0);
      custom.cache = value;
      return custom;
   endfunction
endinstance

instance AxiConvert#(AxiCache, Bit#(0));
   function AxiCache toAxi(Bit#(0) value);
      return 0;
   endfunction
   function Bit#(0) fromAxi(AxiCache value);
      return ?;
   endfunction
endinstance

instance AxiConvert#(AxiCache, Bit#(9));
   function AxiCache toAxi(Bit#(9) value);
      return unpack(truncate(value >> 3));
   endfunction
   function Bit#(9) fromAxi(AxiCache value);
      return zExtend(pack(value)) << 3;
   endfunction
endinstance

function AxiCustom updateCache(AxiCache cache, AxiCustom custom);
   custom.cache = cache;
   return custom;
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance AxiConvert#(AxiLock, AxiLock);
   function AxiLock toAxi(AxiLock value);
      return value;
   endfunction
   function AxiLock fromAxi(AxiLock value);
      return value;
   endfunction
endinstance

instance AxiConvert#(AxiLock, AxiCustom);
   function AxiLock toAxi(AxiCustom value);
      return value.lock;
   endfunction
   function AxiCustom fromAxi(AxiLock value);
      AxiCustom custom = unpack(0);
      custom.lock = value;
      return custom;
   endfunction
endinstance

instance AxiConvert#(AxiLock, Bit#(0));
   function AxiLock toAxi(Bit#(0) value);
      return unpack(0);
   endfunction
   function Bit#(0) fromAxi(AxiLock value);
      return ?;
   endfunction
endinstance

instance AxiConvert#(AxiLock, Bit#(9));
   function AxiLock toAxi(Bit#(9) value);
      return unpack(value[8:7]);
   endfunction
   function Bit#(9) fromAxi(AxiLock value);
      return zExtend(pack(value)) << 7;
   endfunction
endinstance

instance AxiConvert#(AxiLock, Bit#(2));
   function AxiLock toAxi(Bit#(2) value);
      return unpack(value);
   endfunction
   function Bit#(2) fromAxi(AxiLock value);
      return pack(value);
   endfunction
endinstance

function AxiCustom updateLock(AxiLock lock, AxiCustom custom);
   custom.lock = lock;
   return custom;
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance AxiConvert#(AxiCustom, AxiCustom);
   function AxiCustom toAxi(AxiCustom value);
      return value;
   endfunction
   function AxiCustom fromAxi(AxiCustom value);
      return value;
   endfunction
endinstance

instance AxiConvert#(AxiCustom, Bit#(0));
   function AxiCustom toAxi(Bit#(0) value);
      return unpack(0);
   endfunction
   function Bit#(0) fromAxi(AxiCustom value);
      return ?;
   endfunction
endinstance

instance AxiConvert#(AxiCustom, Bit#(9));
   function AxiCustom toAxi(Bit#(9) value);
      return unpack(value);
   endfunction
   function Bit#(9) fromAxi(AxiCustom value);
      return pack(value);
   endfunction
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

endpackage

