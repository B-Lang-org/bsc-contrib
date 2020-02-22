// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AHBBus;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import AHBArbiter::*;
import AHBDefines::*;
import AHBSlave::*;
import Connectable::*;
import Vector::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAHBBus#(Vector#(master_count, AHBFabricMaster#(`TLM_PRM)) masters,
		 Vector#(slv_count, AHBFabricSlave#(`TLM_PRM)) slvs) (Empty)
   provisos(Add#(slv_count, 1, slave_count));

   AHBFabricSlave#(`TLM_PRM) dummy <- mkAHBSlaveDummy;
   let slaves = cons(dummy, slvs);

   Reg#(Maybe#(LBit#(master_count))) hmaster_addr <- mkReg(Invalid);
   Reg#(Maybe#(LBit#(master_count))) hmaster_data <- mkReg(Invalid);

   let m_num_addr = fromMaybe(0, hmaster_addr);
   let m_num_data = fromMaybe(0, hmaster_data);

   ////////////////////////////////////////////////////////////////////////////////
   /// Add a monitor module (to know when the transfer is over).
   ////////////////////////////////////////////////////////////////////////////////

   AHBMasterMonitor#(`TLM_PRM) monitor <- mkAHBMasterMonitor(masters[m_num_addr]);

   ////////////////////////////////////////////////////////////////////////////////
   ///
   ////////////////////////////////////////////////////////////////////////////////

   let master_addr = monitor.fabric;
   let master_data = masters[m_num_data];

   let             s_num_addr <- getCurrentSlave(master_addr, slaves);
   Reg#(LBit#(slave_count))  s_num_data <- mkReg(0);

   let slave_addr = slaves[s_num_addr];
   let slave_data = slaves[s_num_data];

   ////////////////////////////////////////////////////////////////////////////////
   ///
   ////////////////////////////////////////////////////////////////////////////////

   Vector#(master_count, ArbiterRequest_IFC) requests <- mapM(mkArbiterRequest, masters);
   AHBArbiter#(master_count) arbiter <- mkAHBArbiter(slave_data.bus.hREADY);

   zipWithM(mkConnection, arbiter.clients, requests);

   rule update_grant (!isValid(hmaster_addr) || monitor.info.update);
      arbiter.update;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   ///
   ////////////////////////////////////////////////////////////////////////////////

   Vector#(master_count,  AHBFabricSlave#(`TLM_PRM)) dummys <- replicateM(mkAHBSlaveDummy);

   ////////////////////////////////////////////////////////////////////////////////
   ///
   ////////////////////////////////////////////////////////////////////////////////

   Integer islave_count = valueOf(slave_count);
   Integer imaster_count = valueOf(master_count);

   function AHBFabricSlave#(`TLM_PRM)
            getSlaveIfc (Integer n, Wire#(Maybe#(LBit#(slave_count))) s_num);
      case (s_num) matches
	 tagged Valid .s: return slaves[s];
	 tagged Invalid:  return dummys[n];
	 default:         return dummys[n];
      endcase
   endfunction

   function Bool getReady (Integer n, Wire#(Maybe#(LBit#(slave_count))) s_num);
      let ifc = getSlaveIfc(n, s_num);
      return ifc.bus.hREADY;
   endfunction

   Vector#(master_count, Wire#(Maybe#(LBit#(slave_count)))) s_map_addr
   <- replicateM(mkBypassWire);
   Vector#(master_count, Reg#(Maybe#(LBit#(slave_count))))  s_map_data
   <- replicateM(mkReg(Invalid));
   Vector#(master_count, Bool) readys = zipWith(getReady, genList, s_map_data);

   for (Integer x = 0; x < imaster_count; x = x + 1)
      rule s_map_addr_update (readys[x]);
	 s_map_data[x] <= s_map_addr[x];
      endrule


   ////////////////////////////////////////////////////////////////////////////////
   ///
   ////////////////////////////////////////////////////////////////////////////////

   rule hready_update (slave_data.bus.hREADY);
      hmaster_addr <= arbiter.hmaster;
      hmaster_data <= hmaster_addr;
      s_num_data   <= s_num_addr;
   endrule


   (* fire_when_enabled, no_implicit_conditions *)
   rule broadcast_to_slaves;
      for (Integer x = 0; x < islave_count; x = x + 1)
	 begin
	    let slavex = slaves[x];
	    Bool select  = (fromInteger(x) == s_num_addr);

	    let wdata = (select) ? master_addr.bus.hWDATA : master_data.bus.hWDATA;

	    slavex.bus.hADDR(master_addr.bus.hADDR);
	    slavex.bus.hWDATA(wdata);
	    slavex.selector.select(select);
	    slavex.bus.hSIZE(master_addr.bus.hSIZE);
	    slavex.bus.hTRANS(master_addr.bus.hTRANS);
	    slavex.bus.hWRITE(master_addr.bus.hWRITE);
	    slavex.bus.hBURST(master_addr.bus.hBURST);
	    slavex.bus.hPROT(master_addr.bus.hPROT);

	 end
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule broadcast_to_dummys;
      for (Integer x = 0; x < imaster_count; x = x + 1)
	 begin
	    let  dummyx  = dummys[x];
	    let  masterx = (fromInteger(x) == m_num_addr) ? master_addr : masters[x];
	    Bool select  = (fromInteger(x) != m_num_addr);

	    dummyx.bus.hADDR(masterx.bus.hADDR);
	    dummyx.bus.hWDATA(masterx.bus.hWDATA);
	    dummyx.selector.select(select);
	    dummyx.bus.hSIZE(masterx.bus.hSIZE);
	    dummyx.bus.hTRANS(masterx.bus.hTRANS);
	    dummyx.bus.hWRITE(masterx.bus.hWRITE);
	    dummyx.bus.hBURST(masterx.bus.hBURST);
	    dummyx.bus.hPROT(masterx.bus.hPROT);

	 end
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule broadcast_to_masters;
      for (Integer x = 0; x < imaster_count; x = x + 1)
	 begin

	    let select_addr = (fromInteger(x) == m_num_addr);
	    let masterx     = (fromInteger(x) == m_num_addr) ? master_addr : masters[x];

	    s_map_addr[x] <= (select_addr) ? tagged Valid s_num_addr : tagged Invalid;

	    let ifc = getSlaveIfc(x,s_map_data[x]);

	    let response = ifc.bus.hRESP;
	    let ready    = ifc.bus.hREADY;
	    let rdata    = ifc.bus.hRDATA;

	    masterx.bus.hRESP(response);
	    masterx.bus.hREADY(ready);
	    masterx.bus.hRDATA(rdata);
	 end
   endrule

endmodule


////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AHBSlaveMonitor#(`TLM_PRM_DCL);
   interface AHBFabricSlave#(`TLM_PRM) fabric;
   interface AHBInfo#(`TLM_PRM)        info;
endinterface

interface AHBMasterMonitor#(`TLM_PRM_DCL);
   interface AHBFabricMaster#(`TLM_PRM) fabric;
   interface AHBInfo#(`TLM_PRM)        info;
endinterface

(* always_ready *)
interface AHBInfo#(`TLM_PRM_DCL);
   method Bool update;
endinterface

module mkAHBMasterMonitor#(AHBFabricMaster#(`TLM_PRM) master)
                          (AHBMasterMonitor#(`TLM_PRM));

   Reg#(Bit#(5)) remaining_reg   <- mkReg(0);
   PulseWire     update_wire     <- mkPulseWire;

   let transfer = master.bus.hTRANS;
   let burst    = master.bus.hBURST;
   let command  = master.bus.hWRITE;
   let addr     = master.bus.hADDR;
   let request  = master.arbiter.hBUSREQ;

//   Could be a mkBypassWire but compiler doesn't know its always enabled.
//   Wire#(Bool) hready <- mkBypassWire;
   Wire#(Bool) hready <- mkDWire(False);

   Reg#(Bool)        hready_prev   <- mkReg(False);
   Reg#(Bool)        request_prev  <- mkReg(False);
   Reg#(AHBTransfer) transfer_prev <- mkReg(IDLE);
   Reg#(Bool)        started       <- mkReg(False);

   let update_value = (burst == INCR)
                      ? (request_prev && !request && started)
                      : (started && hready_prev && (remaining_reg == 1) && (transfer_prev != IDLE));

   rule every;
      hready_prev   <= hready;
      request_prev  <= request;
      transfer_prev <= transfer;
   endrule

   rule send_update;
      if (update_value) update_wire.send;
   endrule

   rule update_started;
      if (hready && isFirst(transfer))
	 started <= True;
      else if (update_value)
	 started <= False;
   endrule

   rule sample (hready);
      Bit#(5) remaining = 0;
      if (transfer == IDLE)
	 begin
	    remaining = 1;
	 end
      else if (isFirst(transfer))
	 begin
	    remaining = (transfer == IDLE) ? 0
	                                   : fromInteger(getAHBCycleCount(burst)) - 1;
	 end
      else if (transfer == SEQ)
	 begin
	    remaining = remaining_reg - 1;
	 end
      else
	 remaining = remaining_reg;
      if ((burst == INCR) && (transfer != IDLE) && request)
	 begin
	    remaining = 1;
	 end
      remaining_reg <= remaining;
   endrule

   interface AHBFabricMaster fabric;
      interface AHBMaster bus;
	 // Inputs
	 method hRDATA = master.bus.hRDATA;
	 method hRESP  = master.bus.hRESP;
	 method Action hREADY (value);
	    hready <= value;
	    master.bus.hREADY(value);
	 endmethod

	 // Outputs
	 method hADDR  = master.bus.hADDR;
	 method hWDATA = master.bus.hWDATA;
	 method hWRITE = master.bus.hWRITE;
	 method hBURST = master.bus.hBURST;

	 method hTRANS = master.bus.hTRANS;
	 method hSIZE  = master.bus.hSIZE;
	 method hPROT  = master.bus.hPROT;
      endinterface
      interface AHBMasterArbiter arbiter;
	 method hBUSREQ = master.arbiter.hBUSREQ;
	 method hLOCK   = master.arbiter.hLOCK;
	 method hGRANT  = master.arbiter.hGRANT;
      endinterface
   endinterface

   interface AHBInfo info;
      method update    = update_wire;
   endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

function Bool isFirst (AHBTransfer transfer);
   return (transfer == IDLE || transfer == NONSEQ);
endfunction

module getCurrentSlave#(AHBFabricMaster#(`TLM_PRM) master,
			Vector#(slave_count, AHBFabricSlave#(`TLM_PRM)) slaves) (ReadOnly#(LBit#(slave_count)));

   Reg#(LBit#(slave_count)) current <- mkReg(0);

   let slave_num = (master.bus.hTRANS == IDLE) ? 0 :
   selectSlave(slaves, master.bus.hADDR);

   method LBit#(slave_count) _read;
      return slave_num;
   endmethod

endmodule

function LBit#(slave_count) selectSlave (Vector#(slave_count, AHBFabricSlave#(`TLM_PRM)) slaves,
					 AHBAddr#(`TLM_PRM) addr);

   let islave_count = valueOf(slave_count);

   Integer selected = 0; // the dummy slave
   Bool found = False;

   for (Integer x = 1; (x < islave_count) && !found ; x = x + 1)
	 begin
	    let slave = slaves[x];
	    if (slave.selector.addrMatch(addr))
	       begin
		  selected = x;
		  found = True;
	       end
	 end
   return fromInteger(selected);
endfunction

endpackage
