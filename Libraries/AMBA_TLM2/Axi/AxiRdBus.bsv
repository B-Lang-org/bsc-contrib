// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AxiRdBus;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import Arbiter::*;
import AxiDefines::*;
import AxiMaster::*;
import AxiSlave::*;
import Bus::*;
import Connectable::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import TLM2::*;
import BUtils::*;
import List::*;
import Vector::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAxiRdBus#(Vector#(master_count, AxiRdFabricMaster#(`TLM_PRM)) masters,
		   Vector#(slv_count,  AxiRdFabricSlave#(`TLM_PRM))  slvs) (Empty)
   provisos(Log#(master_count, size_m),
	    Add#(slv_count, 1, slave_count),
	    Log#(slave_count, size_s),
	    Add#(ignore0, size_m, id_size),
	    Add#(ignore1, size_s, id_size));

   Wire#(Bool) fixed <- mkDWire(True);

   function AxiRdMaster#(`TLM_PRM) master_bus_ifc(AxiRdFabricMaster#(`TLM_PRM) ifc) = ifc.bus;
   function AxiRdSlave#(`TLM_PRM)  slave_bus_ifc(AxiRdFabricSlave#(`TLM_PRM) ifc)   = ifc.bus;

   AxiRdFabricSlave#(`TLM_PRM) dummy <- mkAxiRdSlaveDummy;
   let slaves  = cons(dummy, slvs);

   let master_vector <- mapM(mkAxiRdBusMasterIFC, map(master_bus_ifc, masters));
   let slave_vector  <- mapM(mkAxiRdBusSlaveIFC,  map(slave_bus_ifc, slaves));

   Arbiter_IFC#(master_count) arbiter <- mkArbiter(fixed);
   Vector#(master_count, ArbiterRequest_IFC) requests <- mapM(mkArbiterRequest, master_vector);

   zipWithM(mkConnection, arbiter.clients, requests);

   FIFOF#(BusSwitchPath#(`TLM_PRM)) addr_path_fifo <- mkBypassFIFOF;
   FIFO#(BusSwitchPath#(`TLM_PRM))  resp_path_fifo <- mkBypassFIFO;

   ////////////////////////////////////////////////////////////////////////////////
   /// A switch for the address phase.
   ////////////////////////////////////////////////////////////////////////////////

   let addr_sends = map(getAxiRdMasterAddr, master_vector);
   let addr_recvs = map(getAxiRdSlaveAddr,  slave_vector);

   BusSwitch#(`TLM_PRM) addr_switch <- mkBusSwitch(addr_sends, addr_recvs, False);

   ////////////////////////////////////////////////////////////////////////////////
   /// A switch for the response phase.
   ////////////////////////////////////////////////////////////////////////////////

   let resp_recvs = map(getAxiRdMasterResp, master_vector);
   let resp_sends = map(getAxiRdSlaveResp,  slave_vector);

   BusSwitch#(`TLM_PRM)  resp_switch <- mkBusSwitch(resp_sends, resp_recvs, False);

   let requests_pending = (pack(map(getRequest, requests)) != 0);

   rule pre_select_path (requests_pending && addr_path_fifo.notFull);
      fixed <= False;
   endrule

   rule select_path (requests_pending);
      let master_port = arbiter.grant_id;
      let master      = master_vector[master_port];
      let addr        = master.addr.data.addr;
      let zow         = map(addrMatch(addr), slaves);
      let slave_port  = getIndex(map(addrMatch(addr), slaves));
      let path = BusSwitchPath {send_port: zExtend(master_port),
				recv_port: {0, slave_port},
				send_id:   getId(master.addr.data),
				recv_id:   getId(master.addr.data)};
      addr_path_fifo.enq(path);
   endrule

   rule set_addr_path;
      addr_switch.set_path(addr_path_fifo.first);
   endrule

   rule set_resp_path;
      resp_switch.set_path(resp_path_fifo.first);
   endrule

   rule finish_addr (addr_switch.done);
      addr_switch.ack;
      let resp_path = reverseBusSwitchPath(addr_path_fifo.first);
      resp_path_fifo.enq(resp_path);
      addr_path_fifo.deq;
   endrule

   rule finish_resp (resp_switch.done);
      resp_switch.ack;
      resp_path_fifo.deq;
   endrule

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

function BusSend#(AxiAddrCmd#(`TLM_PRM)) getAxiRdMasterAddr (AxiRdBusMaster#(`TLM_PRM) master);
   return master.addr;
endfunction

function BusRecv#(AxiRdResp#(`TLM_PRM)) getAxiRdMasterResp (AxiRdBusMaster#(`TLM_PRM) master);
   return master.resp;
endfunction

function BusRecv#(AxiAddrCmd#(`TLM_PRM)) getAxiRdSlaveAddr (AxiRdBusSlave#(`TLM_PRM) slave);
   return slave.addr;
endfunction

function BusSend#(AxiRdResp#(`TLM_PRM)) getAxiRdSlaveResp (AxiRdBusSlave#(`TLM_PRM) slave);
   return slave.resp;
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

function Bool getRequest(ArbiterRequest_IFC ifc);
   return ifc.request;
endfunction

function Bool getGrant(ArbiterClient_IFC ifc);
   return ifc.grant;
endfunction

function Bool addrMatch(AxiAddr#(`TLM_PRM) addr, AxiRdFabricSlave#(`TLM_PRM) ifc);
   return ifc.addrMatch(addr);
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

endpackage
