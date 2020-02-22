// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AhbDefines;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import Arbiter::*;
import BUtils::*;
import CBus::*;
import Connectable::*;
import DefaultValue::*;
import FShow::*;
import OInt::*;
import TLM3::*;
import TieOff::*;
import Vector::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typedef Bit#(TLog#(TAdd#(m, 1)))  LBit#(numeric type m);
typedef UInt#(TLog#(TAdd#(m, 1))) LUInt#(numeric type m);

typedef Bit#(addr_size)                  AhbAddr#(`TLM_PRM_DCL);
typedef Bit#(data_size)                  AhbData#(`TLM_PRM_DCL);
typedef UInt#(length_size)               AhbLength#(`TLM_PRM_DCL);

typedef enum { READ, WRITE } AhbWrite deriving (Eq, Bits, Bounded);
typedef enum { OKAY, ERROR, RETRY, SPLIT } AhbResp deriving (Eq, Bits, Bounded);
typedef enum { IDLE, BUSY, NONSEQ, SEQ } AhbTransfer deriving (Eq, Bits, Bounded);

typedef TLMBSize AhbSize;
typedef enum { SINGLE, INCR, WRAP4, INCR4, WRAP8, INCR8, WRAP16, INCR16 } AhbBurst
        deriving (Eq, Bits, Bounded);

typedef struct {
		TLMCache     cache;
		TLMBuffer    buffer;
		TLMPrivilege privilege;
		TLMAccess    access;
		} AhbProt deriving (Eq, Bits, Bounded);

typedef Bit#(4)   AhbSplit;
typedef OInt#(16) AhbSplitOneHot;

typedef struct {
                AhbWrite             command;
                AhbSize              size;
                AhbBurst             burst;
                AhbTransfer          transfer;
                AhbProt              prot;
                AhbAddr#(`TLM_PRM)   addr;
                } AhbCtrl#(`TLM_PRM_DCL) deriving (Eq, Bits, Bounded);

typedef struct {
                AhbCtrl#(`TLM_PRM) ctrl;
		AhbData#(`TLM_PRM) data;
                } AhbRequest#(`TLM_PRM_DCL) deriving (Eq, Bits, Bounded);

typedef struct {
                AhbResp            status;
                AhbData#(`TLM_PRM) data;
                Maybe#(AhbWrite)   command;
		} AhbResponse#(`TLM_PRM_DCL) deriving (Eq, Bits);


typedef struct {
                AhbWrite             command;
                AhbSize              size;
                AhbBurst             burst;
                AhbTransfer          transfer;
                AhbProt              prot;
		AhbAddr#(`TLM_PRM)   addr;
		AhbSplit             mast;
		} AhbMastCtrl#(`TLM_PRM_DCL) deriving (Eq, Bits, Bounded);

function AhbCtrl#(`TLM_PRM) fromAhbMastCtrl (AhbMastCtrl#(`TLM_PRM) ctrl);
   let value = AhbCtrl {command:  ctrl.command,
                        size:     ctrl.size,
                        burst:    ctrl.burst,
                        transfer: ctrl.transfer,
                        prot:     ctrl.prot,
                        addr:     ctrl.addr};
   return value;
endfunction


function AhbMastCtrl#(`TLM_PRM) toAhbMastCtrl (AhbCtrl#(`TLM_PRM) ctrl);
   let value = AhbMastCtrl {command:  ctrl.command,
                        size:     ctrl.size,
                        burst:    ctrl.burst,
                        transfer: ctrl.transfer,
                        prot:     ctrl.prot,
                        addr:     ctrl.addr,
			mast:     0};
   return value;
endfunction


////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

(* always_ready, always_enabled *)
interface AhbMaster#(`TLM_PRM_DCL);

   // Outputs
   (* result = "HADDR" *)
   method AhbAddr#(`TLM_PRM)  haddr;
   (* result = "HWDATA" *)
   method AhbData#(`TLM_PRM)  hwdata;
   (* result = "HWRITE" *)
   method AhbWrite              hwrite;
   (* result = "HTRANS" *)
   method AhbTransfer           htrans;
   (* result = "HBURST" *)
   method AhbBurst              hburst;
   (* result = "HSIZE" *)
   method AhbSize               hsize;
   (* result = "HPROT" *)
   method AhbProt               hprot;
   // Inputs
   (* prefix = "", result = "unused0" *)
   method Action      hrdata((* port = "HRDATA" *) AhbData#(`TLM_PRM) data);
   (* prefix = "", result = "unused1" *)
   method Action      hready((* port = "HREADY" *) Bool value);
   (* prefix = "", result = "unused2" *)
   method Action      hresp((* port = "HRESP" *) AhbResp response);

endinterface


(* always_ready, always_enabled *)
interface AhbMasterDual#(`TLM_PRM_DCL);

    // Inputs
   (* prefix = "", result = "unused0" *)
   method Action    haddr((* port = "HADDR" *)      AhbAddr#(`TLM_PRM) addr);
   (* prefix = "", result = "unused1" *)
   method Action    hwdata((* port = "HWDATA" *)    AhbData#(`TLM_PRM) data);
   (* prefix = "", result = "unused2" *)
   method Action    hwrite((* port = "HWRITE" *)    AhbWrite    value);
   (* prefix = "", result = "unused3" *)
   method Action    htrans((* port = "HTRANS" *)    AhbTransfer value);
   (* prefix = "", result = "unused4" *)
   method Action    hburst((* port = "HBURST" *)    AhbBurst    value);
   (* prefix = "", result = "unused5" *)
   method Action    hsize((* port = "HSIZE" *)      AhbSize     value);
   (* prefix = "", result = "unused6" *)
   method Action    hprot((* port = "HPROT" *)      AhbProt     value);

   // Outputs
   (* result = "HRDATA" *)
   method AhbData#(`TLM_PRM) hrdata;
   (* result = "HREADY" *)
   method Bool               hready;
   (* result = "HRESP" *)
   method AhbResp            hresp;

endinterface


(* always_ready, always_enabled *)
interface AhbSlave#(`TLM_PRM_DCL);

    // Inputs
   (* prefix = "", result = "unused0" *)
   method Action    haddr((* port = "HADDR" *)     AhbAddr#(`TLM_PRM) addr);
   (* prefix = "", result = "unused1" *)
   method Action    hwdata((* port = "HWDATA" *)   AhbData#(`TLM_PRM) data);
   (* prefix = "", result = "unused2" *)
   method Action    hwrite((* port = "HWRITE" *)   AhbWrite    value);
   (* prefix = "", result = "unused3" *)
   method Action    htrans((* port = "HTRANS" *)   AhbTransfer value);
   (* prefix = "", result = "unused4" *)
   method Action    hburst((* port = "HBURST" *)   AhbBurst    value);
   (* prefix = "", result = "unused5" *)
   method Action    hsize((* port = "HSIZE" *)     AhbSize     value);
   (* prefix = "", result = "unused6" *)
   method Action    hprot((* port = "HPROT" *)     AhbProt     value);
   (* prefix = "", result = "unused7" *)
   method Action    hreadyin((* port = "HREADY" *) Bool        value);
   (* prefix = "", result = "unused8" *)
   method Action    hmast((* port = "HMASTER" *)   AhbSplit    value);

   // Outputs
   (* result = "HRDATA" *)
   method AhbData#(`TLM_PRM) hrdata;
   (* result = "HREADYOUT" *)
   method Bool               hready;
   (* result = "HRESP" *)
   method AhbResp            hresp;
   (* result = "HSPLIT" *)
   method AhbSplit           hsplit;

endinterface

(* always_ready, always_enabled *)
interface AhbSlaveDual#(`TLM_PRM_DCL);

   // Outputs
   (* result = "HADDR" *)
   method AhbAddr#(`TLM_PRM)  haddr;
   (* result = "HWDATA" *)
   method AhbData#(`TLM_PRM)  hwdata;
   (* result = "HWRITE" *)
   method AhbWrite              hwrite;
   (* result = "HTRANS" *)
   method AhbTransfer           htrans;
   (* result = "HBURST" *)
   method AhbBurst              hburst;
   (* result = "HSIZE" *)
   method AhbSize               hsize;
   (* result = "HPROT" *)
   method AhbProt               hprot;
   (* result = "HREADY" *)
   method Bool                  hreadyin;
   (* result = "HMAST" *)
   method AhbSplit              hmast;
   // Inputs
   (* prefix = "", result = "unused0" *)
   method Action      hrdata((* port = "HRDATA" *) AhbData#(`TLM_PRM) data);
   (* prefix = "", result = "unused1" *)
   method Action      hready((* port = "HREADYOUT" *) Bool value);
   (* prefix = "", result = "unused2" *)
   method Action      hresp((* port = "HRESP" *) AhbResp response);
   (* prefix = "", result = "unused2" *)
   method Action      hsplit((* port = "HSPLIT" *) AhbSplit split);

endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

(* always_ready, always_enabled *)
interface AhbSlaveSelector#(`TLM_PRM_DCL);
   (* prefix = "" *)
   method Action select((* port = "HSEL" *) Bool value);
endinterface

(* always_ready, always_enabled *)
interface AhbSlaveSelectorDual;
   (* result = "HSEL" *)
   method Bool select;
endinterface

(* always_ready, always_enabled *)
interface AhbMasterArbiter;
   (* result = "HBUSREQ" *)
   method Bool        hbusreq;
   (* result = "HLOCK" *)
   method Bool        hlock;
   (* prefix = "" *)
   method Action      hgrant((* port = "HGRANT" *) Bool value);
endinterface

(* always_ready, always_enabled *)
interface AhbMasterArbiterDual;
   (* prefix = "", result = "unused7" *)
   method Action      hbusreq((* port = "HBUSREQ" *) Bool value);
   (* prefix = "", result = "unused8" *)
   method Action      hlock((* port = "HLOCK" *)     Bool value);
   (* result = "HGRANT" *)
   method Bool hgrant;
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AhbXtorMaster#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface AhbMaster#(`TLM_PRM) bus;
   (* prefix = "" *)
   interface AhbMasterArbiter       arbiter;
endinterface

interface AhbXtorSlave#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface AhbSlave#(`TLM_PRM)         bus;
   (* prefix = "" *)
   interface AhbSlaveSelector#(`TLM_PRM) selector;
endinterface

instance TieOff#(AhbXtorMaster#(`TLM_PRM));
   module mkTieOff#(AhbXtorMaster#(`TLM_PRM) ifc)(Empty);
      rule tie_off;
	 ifc.bus.hrdata(0);
	 ifc.bus.hready(False);
	 ifc.bus.hresp(unpack(0));
         ifc.arbiter.hgrant(False);
      endrule
   endmodule
endinstance

instance TieOff#(AhbXtorSlave#(`TLM_PRM));
   module mkTieOff#(AhbXtorSlave#(`TLM_PRM) ifc)(Empty);
      rule tie_off;
         ifc.bus.haddr(0);
         ifc.bus.hwdata(0);
         ifc.bus.hwrite(READ);
         ifc.bus.htrans(IDLE);
         ifc.bus.hburst(SINGLE);
         ifc.bus.hsize(BITS8);
         ifc.bus.hprot(unpack(0));
         ifc.bus.hreadyin(False);
         ifc.selector.select(False);
      endrule
   endmodule
endinstance

interface AhbXtorSlaveWM#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface AhbSlave#(`TLM_PRM)         bus;
   (* prefix = "" *)
   interface AhbSlaveSelector#(`TLM_PRM) selector;
   method    Bool addrMatch(AhbAddr#(`TLM_PRM) value);
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AhbXtorMasterDual#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface AhbMasterDual#(`TLM_PRM) bus;
   (* prefix = "" *)
   interface AhbMasterArbiterDual  arbiter;
endinterface

interface AhbXtorSlaveDual#(`TLM_PRM_DCL);
   (* prefix = "" *)
   interface AhbSlaveDual#(`TLM_PRM)  bus;
   (* prefix = "" *)
   interface AhbSlaveSelectorDual    selector;
endinterface

instance TieOff#(AhbXtorMasterDual#(`TLM_PRM));
   module mkTieOff#(AhbXtorMasterDual#(`TLM_PRM) ifc)(Empty);
      rule tie_off;
	 ifc.bus.haddr(0);
         ifc.bus.hwdata(0);
         ifc.bus.hwrite(unpack(0));
         ifc.bus.htrans(unpack(0));
         ifc.bus.hburst(unpack(0));
         ifc.bus.hsize(unpack(0));
         ifc.bus.hprot(unpack(0));
	 ifc.arbiter.hbusreq(False);
	 ifc.arbiter.hlock(False);
      endrule
   endmodule
endinstance

instance TieOff#(AhbXtorSlaveDual#(`TLM_PRM));
   module mkTieOff#(AhbXtorSlaveDual#(`TLM_PRM) ifc)(Empty);
      rule tie_off;
	 ifc.bus.hrdata(0);
	 ifc.bus.hready(False);
	 ifc.bus.hresp(unpack(0));
	 ifc.bus.hsplit(unpack(0));
      endrule
   endmodule
endinstance

interface AhbXtorMasterConnector#(`TLM_PRM_DCL);
   interface AhbXtorMaster#(`TLM_PRM)     master;
   interface AhbXtorMasterDual#(`TLM_PRM) dual;
endinterface

interface AhbXtorSlaveConnector#(`TLM_PRM_DCL);
   interface AhbXtorSlaveWM#(`TLM_PRM)   slave;
   interface AhbXtorSlaveDual#(`TLM_PRM) dual;
endinterface

interface AhbBus#(numeric type m, numeric type s, `TLM_PRM_DCL);
   interface Vector#(m, AhbXtorMasterDual#(`TLM_PRM)) masters;
   interface Vector#(s, AhbXtorSlaveDual#(`TLM_PRM))  slaves;
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AhbMasterXActor#(`TLM_RR_DCL, `TLM_PRM_DCL);
   interface TLMRecvIFC#(`TLM_RR)    tlm;
   (* prefix = "" *)
   interface AhbXtorMaster#(`TLM_PRM) fabric;
endinterface

interface AhbSlaveXActorWM#(`TLM_RR_DCL, `TLM_PRM_DCL);
   interface TLMSendIFC#(`TLM_RR)     tlm;
   (* prefix = "" *)
   interface AhbXtorSlaveWM#(`TLM_PRM) fabric;
endinterface

interface AhbSlaveXActor#(`TLM_RR_DCL, `TLM_PRM_DCL);
   interface TLMSendIFC#(`TLM_RR)     tlm;
   (* prefix = "" *)
   interface AhbXtorSlave#(`TLM_PRM) fabric;
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance Connectable#(AhbXtorMaster#(`TLM_PRM), AhbXtorMasterDual#(`TLM_PRM));
   module mkConnection#(AhbXtorMaster#(`TLM_PRM)     m,
                        AhbXtorMasterDual#(`TLM_PRM) d) (Empty);
      mkConnection(m.bus, d.bus);
      mkConnection(m.arbiter, d.arbiter);
   endmodule
endinstance

instance Connectable#(AhbXtorSlave#(`TLM_PRM), AhbXtorSlaveDual#(`TLM_PRM));
   module mkConnection#(AhbXtorSlave#(`TLM_PRM)     s,
                        AhbXtorSlaveDual#(`TLM_PRM) d) (Empty);
      mkConnection(d.bus, s.bus);
      mkConnection(s.selector, d.selector);
   endmodule
endinstance


instance Connectable#(AhbXtorMaster#(`TLM_PRM), AhbXtorSlave#(`TLM_PRM));
   module mkConnection#(AhbXtorMaster#(`TLM_PRM) m,
                        AhbXtorSlave#(`TLM_PRM)  s) (Empty);
      mkConnection(m.bus, s.bus);

      rule always_grant;
         m.arbiter.hgrant(True);
      endrule

      rule always_select;
         s.selector.select(True);
      endrule
   endmodule
endinstance

instance Connectable#(AhbXtorSlave#(`TLM_PRM), AhbXtorMaster#(`TLM_PRM));
   module mkConnection#(AhbXtorSlave#(`TLM_PRM) s,
                        AhbXtorMaster#(`TLM_PRM)  m) (Empty);
      (*hide*) let _i <- mkConnection(m, s);
   endmodule
endinstance

instance Connectable#(AhbMaster#(`TLM_PRM), AhbSlave#(`TLM_PRM));
   module mkConnection#(AhbMaster#(`TLM_PRM) m, AhbSlave#(`TLM_PRM) s )(Empty);

      let clk = clockOf(s.haddr);
      let rst = resetOf(s.haddr);

      Reg#(Bool) first <- mkReg(True, clocked_by clk, reset_by rst);

      let hready = first || s.hready;

      rule start (first);
         first <= False;
      endrule

      rule master_to_slave;
         s.haddr(m.haddr);
         s.hburst(m.hburst);
         s.hmast(0);
         s.hprot(m.hprot);
         s.hsize(m.hsize);
         s.htrans(m.htrans);
         s.hwdata(m.hwdata);
         s.hwrite(m.hwrite);
      endrule

      rule hready_to_slave;
         s.hreadyin(True);
      endrule

      rule slave_to_master_0;
         m.hrdata(s.hrdata);
      endrule

      rule slave_to_master_1;
	 m.hresp(s.hresp);
      endrule

      rule hready_to_master;
	 m.hready(hready);
      endrule

   endmodule
endinstance

instance Connectable#(AhbMaster#(`TLM_PRM), AhbMasterDual#(`TLM_PRM));
   module mkConnection#(AhbMaster#(`TLM_PRM) m, AhbMasterDual#(`TLM_PRM) s )(Empty);

      rule master_to_slave;
         s.haddr(m.haddr);
         s.hwdata(m.hwdata);
         s.hwrite(m.hwrite);
         s.htrans(m.htrans);
         s.hburst(m.hburst);
         s.hsize(m.hsize);
         s.hprot(m.hprot);
      endrule

      rule slave_to_master;
         m.hrdata(s.hrdata);
         m.hready(s.hready);
         m.hresp(s.hresp);
      endrule

   endmodule
endinstance

instance Connectable#(AhbSlaveDual#(`TLM_PRM), AhbSlave#(`TLM_PRM));
   module mkConnection#(AhbSlaveDual#(`TLM_PRM) m, AhbSlave#(`TLM_PRM) s )(Empty);

      rule master_to_slave;
         s.haddr(m.haddr);
         s.hwdata(m.hwdata);
         s.hwrite(m.hwrite);
         s.htrans(m.htrans);
         s.hburst(m.hburst);
         s.hsize(m.hsize);
         s.hprot(m.hprot);
	 s.hmast(m.hmast);
      endrule

      rule update_hready;
         s.hreadyin(m.hreadyin);
      endrule

      rule slave_to_master;
         m.hrdata(s.hrdata);
         m.hready(s.hready);
         m.hresp(s.hresp);
	 m.hsplit(s.hsplit);
      endrule

   endmodule
endinstance

instance Connectable#(AhbMasterArbiter, AhbMasterArbiterDual);
   module mkConnection#(AhbMasterArbiter     m,
                        AhbMasterArbiterDual d) (Empty);

      rule master_to_dual_lock;
         d.hlock(m.hlock);
      endrule

      rule master_to_dual_req;
         d.hbusreq(m.hbusreq);
      endrule

      rule dual_to_master;
         m.hgrant(d.hgrant);
      endrule

   endmodule
endinstance

instance Connectable#(AhbSlaveSelector#(`TLM_PRM), AhbSlaveSelectorDual);
   module mkConnection#(AhbSlaveSelector#(`TLM_PRM) s,
                        AhbSlaveSelectorDual        d) (Empty);

      rule dual_to_slave;
         s.select(d.select);
      endrule

   endmodule
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance FShow#(AhbWrite);
   function Fmt fshow (AhbWrite label);
      case (label)
         READ: return fshow("READ");
         WRITE: return fshow("WRITE");
      endcase
   endfunction
endinstance

instance FShow#(AhbResp);
   function Fmt fshow (AhbResp label);
      case (label)
         OKAY: return fshow("OKAY");
         ERROR: return fshow("ERROR");
         RETRY: return fshow("RETRY");
         SPLIT: return fshow("SPLIT");
      endcase
   endfunction
endinstance

instance FShow#(AhbTransfer);
   function Fmt fshow (AhbTransfer label);
      case (label)
         IDLE: return fshow("IDLE");
         BUSY: return fshow("BUSY");
         NONSEQ: return fshow("NONSEQ");
         SEQ: return fshow("SEQ");
      endcase
   endfunction
endinstance

instance FShow#(AhbBurst);
   function Fmt fshow (AhbBurst label);
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

instance FShow#(AhbCtrl#(`TLM_PRM));
   function Fmt fshow (AhbCtrl#(`TLM_PRM) ctrl);
      return ($format("<AhbCTRL ",
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

instance FShow#(AhbRequest#(`TLM_PRM));
   function Fmt fshow (AhbRequest#(`TLM_PRM) req);
      return ($format("<AhbREQ ",
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

instance FShow#(AhbResponse#(`TLM_PRM));
   function Fmt fshow (AhbResponse#(`TLM_PRM) resp);
      Fmt x = $format("<AhbResponse UNKNOWN",
		  +
		  fshow(resp.status)
		  +
		  fshow(" ")
		  +
		  fshow(resp.data)
		  +
		  fshow(">"));
      if (resp.command matches tagged Valid READ)
	 x = $format("<AhbResponse READ ",
		  +
		  fshow(resp.status)
		  +
		  fshow(" ")
		  +
		  fshow(resp.data)
		  +
		     fshow(">"));
      if (resp.command matches tagged Valid WRITE)
	 x = $format("<AhbResponse WRITE ",
		  +
		  fshow(resp.status)
		  +
		  fshow(">"));
      return x;
   endfunction
endinstance

////////////////////////////////////////////////////////////////////////////////
/// TLM conversion functions
/// TLM to Ahb:
////////////////////////////////////////////////////////////////////////////////

function AhbCtrl#(`TLM_PRM) getAhbCtrl (RequestDescriptor#(`TLM_PRM) tlm_descriptor);

   AhbCtrl#(`TLM_PRM) ctrl;

   AhbProt prot = ?;
   prot.cache     = tlm_descriptor.cache;
   prot.buffer    = tlm_descriptor.buffer;
   prot.privilege = tlm_descriptor.privilege;
   prot.access    = tlm_descriptor.access;

   ctrl.command  = getAhbWrite(tlm_descriptor.command);
   ctrl.size     = getAhbSize(tlm_descriptor.b_size);
   ctrl.burst    = getAhbBurst(tlm_descriptor);
   ctrl.transfer = IDLE; // set this later.
   ctrl.prot     = prot;
   ctrl.addr     = tlm_descriptor.addr;

   return ctrl;

endfunction

function AhbWrite getAhbWrite(TLMCommand command);
   case (command)
      READ:  return READ;
      WRITE: return WRITE;
   endcase
endfunction

function AhbBurst getAhbBurst(RequestDescriptor#(`TLM_PRM) tlm_descriptor);
   let burst_mode = tlm_descriptor.burst_mode;
   let burst_length = tlm_descriptor.b_length;
   case (tuple2(burst_mode, burst_length)) matches
      {INCR,  0}: return SINGLE;
      {INCR,  3}: return INCR4;
      {INCR,  7}: return INCR8;
      {INCR, 15}: return INCR16;
      {WRAP,  3}: return WRAP4;
      {WRAP,  7}: return WRAP8;
      {WRAP, 15}: return WRAP16;
      {CNST, .n}: return SINGLE;
      {WRAP, .n}: return SINGLE;
      {INCR, .n}: return INCR;
         default: return SINGLE;
   endcase
endfunction

function AhbSize getAhbSize(TLMBSize size);
   return size;
endfunction

function Integer getAhbCycleCount (AhbBurst burst);
   case (burst)
      SINGLE:         return 1;
      WRAP4, INCR4:   return 4;
      WRAP8, INCR8:   return 8;
      WRAP16, INCR16: return 16;
      INCR:           return 1; // needed for last cycle;
   endcase
endfunction

function AhbData#(`TLM_PRM) getAhbData (RequestDescriptor#(`TLM_PRM) tlm_descriptor);

   AhbData#(`TLM_PRM) data = tlm_descriptor.data;

   return data;

endfunction

////////////////////////////////////////////////////////////////////////////////
/// Ahb to TLM:
////////////////////////////////////////////////////////////////////////////////

function RequestDescriptor#(`TLM_PRM) fromAhbCtrl (AhbCtrl#(`TLM_PRM) ctrl)
   provisos(DefaultValue#(RequestDescriptor#(`TLM_PRM)));

   RequestDescriptor#(`TLM_PRM) desc = defaultValue;

   Tuple2#(TLMBurstMode, TLMBLength#(`TLM_PRM)) pair = fromAhbBurst(ctrl.burst, ctrl.transfer);

   match {.burst_mode, .length} = pair;

   desc.command         = fromAhbWrite(ctrl.command);
   desc.mode            = REGULAR;
   desc.addr            = ctrl.addr;
   desc.b_size          = fromAhbSize(ctrl.size);
   desc.burst_mode      = burst_mode;
   desc.b_length        = length;
   desc.cache           = ctrl.prot.cache;
   desc.buffer          = ctrl.prot.buffer;
   desc.privilege       = ctrl.prot.privilege;
   desc.access          = ctrl.prot.access;

//   desc = addByteEnable(desc);
   desc.byte_enable = tagged Calculate;


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

function TLMCommand fromAhbWrite(AhbWrite command);
   case (command)
      READ:  return READ;
      WRITE: return WRITE;
   endcase
endfunction

function TLMStatus fromAhbResp(AhbResp resp);
   case (resp)
      OKAY:    return SUCCESS;
      ERROR:   return ERROR;
      RETRY:   return ERROR;
      SPLIT:   return ERROR;
      default: return ERROR;
     endcase
endfunction

function TLMBSize fromAhbSize(AhbSize size);
   return size;
endfunction

function Tuple2#(TLMBurstMode, UInt#(n)) fromAhbBurst(AhbBurst value, AhbTransfer trans);
   case (value)
      SINGLE:  return tuple2(INCR,  0);
      INCR4:   return tuple2(INCR,  3);
      INCR8:   return tuple2(INCR,  7);
      INCR16:  return tuple2(INCR, 15);
      WRAP4:   return tuple2(WRAP,  3);
      WRAP8:   return tuple2(WRAP,  7);
      WRAP16:  return tuple2(WRAP, 15);
//      INCR:    return tuple2(INCR,  1);  //// Mark it as from INCR
      INCR:    return tuple2(INCR,  0);
      default: return tuple2(INCR,  0);
   endcase
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AhbArbiter#(numeric type count, `TLM_PRM_DCL);
   interface Vector#(count, ArbiterClient_IFC) clients;
   (* always_ready, always_enabled *)
   method Maybe#(LBit#(count))                 hmaster;
   interface AhbResponseHandler                handler;
endinterface

interface AhbResponseHandler;
   method Action  hready_in(Bool    value);
   method Action  hresp_in (AhbResp value);
   method Bool    hready;
   method AhbResp hresp;
endinterface

instance Arbitable#(AhbMasterArbiter);
   module mkArbiterRequest#(AhbMasterArbiter ifc) (ArbiterRequest_IFC);

      Wire#(Bool) grant_wire <- mkDWire(False);

      rule every;
         ifc.hgrant(grant_wire);
      endrule

      method Bool request();
         return ifc.hbusreq;
      endmethod

      method Bool lock();
         return ifc.hlock;
      endmethod

      method Action grant();
         grant_wire <= True;
      endmethod
   endmodule
endinstance

instance Arbitable#(AhbXtorMaster#(`TLM_PRM));
   module mkArbiterRequest#(AhbXtorMaster#(`TLM_PRM) ifc) (ArbiterRequest_IFC);
      let _ifc <- mkArbiterRequest(ifc.arbiter);
      return _ifc;
   endmodule
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AhbSlaveMonitor#(`TLM_PRM_DCL);
   interface AhbXtorSlave#(`TLM_PRM) fabric;
   interface AhbInfo#(`TLM_PRM)      info;
endinterface

interface AhbMasterMonitor#(`TLM_PRM_DCL);
   interface AhbXtorMaster#(`TLM_PRM) fabric;
   interface AhbInfo#(`TLM_PRM)       info;
endinterface

(* always_ready *)
interface AhbInfo#(`TLM_PRM_DCL);
   method Bool update;
endinterface



////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

function AhbXtorSlaveWM#(`TLM_PRM) addAddrMatch(function Bool addr_match(AhbAddr#(`TLM_PRM) addr),
                                                AhbXtorSlave#(`TLM_PRM) ifc);
   let ifc_wm = (interface AhbXtorSlaveWM;
                    interface AhbSlave         bus      = ifc.bus;
                    interface AhbSlaveSelector selector = ifc.selector;
                    method addrMatch = addr_match;
                 endinterface);

   return ifc_wm;
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typeclass Convert#(type a, type b);
   function b  convert(a value);
endtypeclass

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance Convert#(AhbXtorSlaveWM#(`TLM_PRM), AhbXtorSlave#(`TLM_PRM));
   function AhbXtorSlave#(`TLM_PRM) convert(AhbXtorSlaveWM#(`TLM_PRM) ifc_wm);
      let ifc = (interface AhbXtorSlave;
                    interface AhbSlave         bus      = ifc_wm.bus;
                    interface AhbSlaveSelector selector = ifc_wm.selector;
                 endinterface);
      return ifc;
   endfunction
endinstance

instance Convert#(AhbSlaveXActorWM#(`TLM_XTR), AhbSlaveXActor#(`TLM_XTR));
   function AhbSlaveXActor#(`TLM_XTR) convert(AhbSlaveXActorWM#(`TLM_XTR) ifc_wm);
      let ifc = (interface AhbSlaveXActor;
                    interface TLMSendIFC          tlm      = ifc_wm.tlm;
                    interface AhbXtorSlave fabric;
                       interface AhbSlave         bus      = ifc_wm.fabric.bus;
                       interface AhbSlaveSelector selector = ifc_wm.fabric.selector;
                    endinterface
                 endinterface);
      return ifc;
   endfunction
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typedef struct {
                AhbWrite             command;
                AhbSize              size;
                AhbBurst             burst;
                AhbTransfer          transfer;
                AhbLength#(`TLM_PRM) length; // only used for INCR transfers.
                AhbProt              prot;
                AhbAddr#(`TLM_PRM)   addr;
                } AhbTbCtrl#(`TLM_PRM_DCL) deriving (Eq, Bits, Bounded);

function AhbTbCtrl#(`TLM_PRM) toAhbTbCtrl (AhbCtrl#(`TLM_PRM) ctrl);
   let value = AhbTbCtrl {command:  ctrl.command,
                          size:     ctrl.size,
                          burst:    ctrl.burst,
                          transfer: ctrl.transfer,
                          prot:     ctrl.prot,
                          addr:     ctrl.addr,
                          length:   0};
   return value;
endfunction

function AhbCtrl#(`TLM_PRM) fromAhbTbCtrl (AhbTbCtrl#(`TLM_PRM) ctrl);
   let value = AhbCtrl {command:  ctrl.command,
                        size:     ctrl.size,
                        burst:    ctrl.burst,
                        transfer: ctrl.transfer,
                        prot:     ctrl.prot,
                        addr:     ctrl.addr};
   return value;
endfunction

typedef struct {AhbTbCtrl#(`TLM_PRM) ctrl;
                AhbData#(`TLM_PRM) data;
                } AhbTbRequest#(`TLM_PRM_DCL) deriving (Bits,Eq);

instance FShow#(AhbTbRequest#(`TLM_PRM)) provisos (FShow#(AhbTbCtrl#(`TLM_PRM)));
   function Fmt fshow(AhbTbRequest#(`TLM_PRM) r);
      return ($format("<AhbTbRequest ") +
	      fshow(r.data) + fshow(" ") + +fshow(r.ctrl) + fshow(">"));
   endfunction
endinstance

typedef union tagged {AhbTbRequest#(`TLM_PRM) Descriptor;
                      AhbData#(`TLM_PRM)      Data;
                      } AhbXtorRequest#(`TLM_PRM_DCL) deriving(Eq, Bits, Bounded);

instance FShow#(AhbXtorRequest#(`TLM_PRM)) provisos (FShow#(AhbTbRequest#(`TLM_PRM)));
   function Fmt fshow(AhbXtorRequest#(`TLM_PRM) r);
      case (r) matches
         tagged Data .data : begin return ($format("Data ", fshow(data))); end
         tagged Descriptor .desc : begin return($format("Descriptor ",
                                                  fshow(desc))); end
      endcase
   endfunction
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typedef AhbResponse#(`TLM_PRM) AhbXtorResponse#(`TLM_PRM_DCL);

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance TLMRequestTC#(AhbXtorRequest#(`TLM_PRM), `TLM_PRM)
   provisos(DefaultValue#(RequestDescriptor#(`TLM_PRM)));
   function TLMRequest#(`TLM_PRM) toTLMRequest(AhbXtorRequest#(`TLM_PRM) value);
      case (value) matches
         tagged Descriptor .request:
            begin
               let desc = fromAhbCtrl(fromAhbTbCtrl(request.ctrl));
               if (request.ctrl.burst == INCR)
                  desc.b_length = request.ctrl.length;
               desc.data = request.data;
	       desc.byte_enable = tagged Calculate;
               return tagged Descriptor desc;
            end
         tagged Data .data:
            begin
               RequestData#(`TLM_PRM) request_data = ?;
               request_data.data = data;
               request_data.transaction_id = 0;
               return tagged Data request_data;
            end
      endcase
   endfunction

   function AhbXtorRequest#(`TLM_PRM) fromTLMRequest(TLMRequest#(`TLM_PRM) value);
      case (value) matches
         tagged Descriptor .desc:
            begin
               AhbTbCtrl#(`TLM_PRM) tb_ctrl = toAhbTbCtrl(getAhbCtrl(desc));
               if (tb_ctrl.burst == INCR)
                  tb_ctrl.length = desc.b_length;
               let request = AhbTbRequest { ctrl: tb_ctrl, data: desc.data};
               return tagged Descriptor request;
            end
         tagged Data .data:
            begin
               return tagged Data data.data;
            end
        endcase
   endfunction

endinstance

instance TLMResponseTC#(AhbResponse#(`TLM_PRM), `TLM_PRM)
   provisos(DefaultValue#(TLMResponse#(`TLM_PRM)));

   function TLMResponse#(`TLM_PRM) toTLMResponse(AhbResponse#(`TLM_PRM) value);
      TLMResponse#(`TLM_PRM) response = defaultValue;
      if (value.command matches tagged Valid .c)
         response.command = fromAhbWrite(c);
      case (value.status)
	 SPLIT: begin
		   TLMErrorCode code = SPLIT;
		   response.status = ERROR;
		   response.data   = extendNP(pack(code));
		end
	 RETRY: begin
		   TLMErrorCode code = RETRY;
		   response.status = ERROR;
		   response.data   = extendNP(pack(code));
		end
	 ERROR: begin
		   TLMErrorCode code = SLVERR;
		   response.status = ERROR;
		   response.data   = extendNP(pack(code));
		end
	 default: begin // OKAY
		  response.status = SUCCESS;
		  response.data   = value.data;
	       end
      endcase
      return response;
   endfunction

   function AhbResponse#(`TLM_PRM) fromTLMResponse(TLMResponse#(`TLM_PRM) value);
      AhbResponse#(`TLM_PRM) response;
      response.command = tagged Just getAhbWrite(value.command);
      if (value.status == ERROR)
	 begin
	    TLMErrorCode code = unpack(truncateNP(value.data));
	    case (code)
	       RETRY: begin
			 response.status = RETRY;
			 response.data   = 0;
		      end
	       SPLIT: begin
			 response.status = SPLIT;
			 response.data   = 0;
		      end
	       default: begin
			   response.status = ERROR;
			   response.data   = value.data;
			end
	    endcase
	 end
      else
	 begin
	    response.status = OKAY;
	    response.data   = value.data;
	 end
      return response;
   endfunction

endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

endpackage
