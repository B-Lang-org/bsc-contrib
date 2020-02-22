// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AhbBus;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import AhbDefines::*;
import AhbSlave::*;
import AhbArbiter::*;
import BUtils::*;
import Connectable::*;
import Vector::*;
import CBus::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAhbBus#(function Bit#(s2) select_slave(AhbAddr#(`TLM_PRM) addr))
		    (AhbBus#(m, s, `TLM_PRM))
   provisos(Add#(s, 1, s2));
   let _ifc <- mkAhbBusP(select_slave, False, mkAhbArbiter(False));
   return _ifc;
endmodule

module mkAhbBusEBT#(Bool terminate, function Bit#(s2) select_slave(AhbAddr#(`TLM_PRM) addr))
		    (AhbBus#(m, s, `TLM_PRM))
   provisos(Add#(s, 1, s2));
   let _ifc <- mkAhbBusP(select_slave, False, mkAhbArbiter(terminate));
   return _ifc;
endmodule

module mkAhbBusP#(function Bit#(s2) select_slave(AhbAddr#(`TLM_PRM) addr),
		  Bool dummy_on_idle,
		  function module#(AhbArbiter#(m, `TLM_PRM)) arbModule(AhbXtorMaster#(`TLM_PRM) master))
		     (AhbBus#(m, s, `TLM_PRM))
   provisos(Add#(s, 1, s2));
   function Bool addrMatch(Integer num, AhbAddr#(`TLM_PRM) addr);
      let value = select_slave(addr);
      return unpack(value[num]);
   endfunction

   let match_functions = map(addrMatch, tail(genList)); // numbering starts with 1;

   Vector#(m, AhbXtorMasterConnector#(`TLM_PRM)) master_connectors
   <- replicateM(mkAhbXtorMasterConnector);
   Vector#(s, AhbXtorSlaveConnector#(`TLM_PRM)) slave_connectors
   <- mapM(mkAhbXtorSlaveConnector, match_functions);

   function AhbXtorMasterDual#(`TLM_PRM)
      getAhbXtorMasterDual (AhbXtorMasterConnector#(`TLM_PRM) ifc);
      return ifc.dual;
   endfunction

   function AhbXtorSlaveDual#(`TLM_PRM)
      getAhbXtorSlaveDual (AhbXtorSlaveConnector#(`TLM_PRM) ifc);
      return ifc.dual;
   endfunction

   function AhbXtorMaster#(`TLM_PRM)
      getAhbXtorMaster (AhbXtorMasterConnector#(`TLM_PRM) ifc);
      return ifc.master;
   endfunction

   function AhbXtorSlaveWM#(`TLM_PRM)
      getAhbXtorSlave (AhbXtorSlaveConnector#(`TLM_PRM) ifc);
      return ifc.slave;
   endfunction

   let bus_masters = map(getAhbXtorMaster, master_connectors);
   let bus_slaves  = map(getAhbXtorSlave,   slave_connectors);

   mkAhbBusFabric(bus_masters, bus_slaves, dummy_on_idle, arbModule);

   interface masters = map(getAhbXtorMasterDual, master_connectors);
   interface slaves  = map(getAhbXtorSlaveDual,  slave_connectors);

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAhbXtorMasterConnector (AhbXtorMasterConnector#(`TLM_PRM));

   Wire#(AhbAddr#(`TLM_PRM))     haddr_wire  <- mkBypassWire;
   Wire#(AhbData#(`TLM_PRM))     hwdata_wire <- mkBypassWire;
   Wire#(AhbWrite)    hwrite_wire <- mkBypassWire;
   Wire#(AhbTransfer) htrans_wire <- mkBypassWire;
   Wire#(AhbBurst)    hburst_wire <- mkBypassWire;
   Wire#(AhbSize)     hsize_wire  <- mkBypassWire;
   Wire#(AhbProt)     hprot_wire  <- mkBypassWire;

   Wire#(AhbData#(`TLM_PRM))     hrdata_wire <- mkBypassWire;
   Wire#(Bool)        hready_wire <- mkBypassWire;
   Wire#(AhbResp)     hresp_wire  <- mkBypassWire;

   Wire#(Bool)        hbusreq_wire <- mkBypassWire;
   Wire#(Bool)        hlock_wire   <- mkBypassWire;
   Wire#(Bool)        hgrant_wire  <- mkBypassWire;

   interface AhbXtorMaster master;
      interface AhbMaster bus;
	  // outputs
	 method haddr  = haddr_wire;
	 method hwdata = hwdata_wire;
	 method hwrite = hwrite_wire;
	 method htrans = htrans_wire;
	 method hburst = hburst_wire;
	 method hsize  = hsize_wire;
	 method hprot  = hprot_wire;

	 // inputs
	 method hrdata = hrdata_wire._write;
	 method hready = hready_wire._write;
	 method hresp  = hresp_wire._write;
      endinterface
      interface AhbMasterArbiter arbiter;
	 method hbusreq = hbusreq_wire;
	 method hlock   = hlock_wire;
	 method hgrant  = hgrant_wire._write;
      endinterface
   endinterface

    interface AhbXtorMasterDual dual;
      interface AhbMasterDual bus;
	 // Inputs
	 method haddr  = haddr_wire._write;
	 method hwdata = hwdata_wire._write;
	 method hwrite = hwrite_wire._write;
	 method htrans = htrans_wire._write;
	 method hburst = hburst_wire._write;
	 method hsize  = hsize_wire._write;
	 method hprot  = hprot_wire._write;

	 // Outputs
	 method hrdata  = hrdata_wire;
	 method hready  = hready_wire;
	 method hresp   = hresp_wire;

      endinterface
      interface AhbMasterArbiterDual arbiter;
	 method hbusreq = hbusreq_wire._write;
	 method hlock   = hlock_wire._write;
	 method hgrant  = hgrant_wire;
      endinterface
   endinterface

endmodule

module mkAhbXtorSlaveConnector#(function Bool addr_match(AhbAddr#(`TLM_PRM) addr))
			       (AhbXtorSlaveConnector#(`TLM_PRM));

   Wire#(AhbAddr#(`TLM_PRM))              haddr_wire  <- mkBypassWire;
   Wire#(AhbData#(`TLM_PRM))              hwdata_wire <- mkBypassWire;
   Wire#(AhbWrite)             hwrite_wire <- mkBypassWire;
   Wire#(AhbTransfer)          htrans_wire <- mkBypassWire;
   Wire#(AhbBurst)             hburst_wire <- mkBypassWire;
   Wire#(AhbSize)              hsize_wire  <- mkBypassWire;
   Wire#(AhbProt)              hprot_wire  <- mkBypassWire;
   Wire#(Bool)                 hreadyin_wire <- mkBypassWire;

   Wire#(AhbData#(`TLM_PRM))              hrdata_wire <- mkBypassWire;
   Wire#(Bool)                 hready_wire <- mkBypassWire;
   Wire#(AhbResp)              hresp_wire  <- mkBypassWire;
   Wire#(AhbSplit)             hsplit_wire  <- mkBypassWire;
   Wire#(AhbSplit)             hmast_wire  <- mkBypassWire;

   Wire#(Bool)                 hsel_wire   <- mkBypassWire;

   interface AhbXtorSlaveWM slave;
      interface AhbSlave bus;
	  // Inputs
	 method haddr    = haddr_wire._write;
	 method hwdata   = hwdata_wire._write;
	 method hwrite   = hwrite_wire._write;
	 method htrans   = htrans_wire._write;
	 method hburst   = hburst_wire._write;
	 method hsize    = hsize_wire._write;
	 method hprot    = hprot_wire._write;
	 method hreadyin = hreadyin_wire._write;
	 method hmast    = hmast_wire._write;

	 // Outputs
	 method hrdata    = hrdata_wire;
	 method hready    = hready_wire;
	 method hresp     = hresp_wire;
	 method hsplit    = hsplit_wire;
      endinterface
      interface AhbSlaveSelector selector;
	 method select    = hsel_wire._write;
      endinterface
      method addrMatch = addr_match;
   endinterface

    interface AhbXtorSlaveDual dual;
      interface AhbSlaveDual bus;
	  // Outputs
	 method haddr    = haddr_wire;
	 method hwdata   = hwdata_wire;
	 method hwrite   = hwrite_wire;
	 method htrans   = htrans_wire;
	 method hburst   = hburst_wire;
	 method hsize    = hsize_wire;
	 method hprot    = hprot_wire;
	 method hreadyin = hreadyin_wire;
	 method hmast    = hmast_wire;

	 // Inputs
	 method hrdata = hrdata_wire._write;
	 method hready = hready_wire._write;
	 method hresp  = hresp_wire._write;
	 method hsplit = hsplit_wire._write;
      endinterface
      interface AhbSlaveSelectorDual selector;
         method select = hsel_wire;
      endinterface
   endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAhbBusFabric#(Vector#(master_count, AhbXtorMaster#(`TLM_PRM)) masters,
		       Vector#(slv_count, AhbXtorSlaveWM#(`TLM_PRM)) slvs,
		       Bool dummy_on_idle,
		       function module#(AhbArbiter#(master_count, `TLM_PRM)) arbModule(AhbXtorMaster#(`TLM_PRM) master)) (Empty)
   provisos(Add#(slv_count, 1, slave_count));

   Reg#(Bool)  first       <- mkReg(True);

   AhbXtorSlave#(`TLM_PRM) dummy <- mkAhbSlaveUnmapped;

   let slaves_wm = cons(addAddrMatch(?,dummy), slvs);
   let slaves    = cons(dummy, map(convert, slvs));

   rule start (first);
      first <= False;
   endrule

   Integer islave_count = valueOf(slave_count);
   Integer imaster_count = valueOf(master_count);

   ////////////////////////////////////////////////////////////////////////////////
   ///
   ////////////////////////////////////////////////////////////////////////////////

   Wire#(LBit#(master_count)) m_num_addr <- mkBypassWire;
   Reg#(LBit#(master_count))  m_num_data <- mkReg(0);

   let master_addr = masters[m_num_addr];
   let master_data = masters[m_num_data];

   let init = replicate(False);
   init[0] = True;

   Reg#(Vector#(slave_count, Bool)) s_all_data <- mkReg(init);
   let s_all_addr = getCurrentSlaveVector(master_addr, slaves_wm, dummy_on_idle);


//   Reg#(LBit#(slave_count)) s_num_data <- mkReg(0);

//   let slave_addr = slaves[s_num_addr];
//   let slave_data = slaves[s_num_data];

   function AhbResp            get_hresp  (AhbXtorSlave#(`TLM_PRM) slave) = slave.bus.hresp;
   function Bool               get_hready (AhbXtorSlave#(`TLM_PRM) slave) = slave.bus.hready;
   function AhbData#(`TLM_PRM) get_hrdata (AhbXtorSlave#(`TLM_PRM) slave) = slave.bus.hrdata;


   let hresp_in  = selectQualified(s_all_data, map(get_hresp, slaves));
   let hready_in = first || selectQualified(s_all_data, map(get_hready, slaves));

   ////////////////////////////////////////////////////////////////////////////////


   let hresp  = hresp_in;
   let hready = hready_in;

   if (imaster_count == 1)
      begin

	 ArbiterRequest_IFC request <- mkArbiterRequest(masters[0]);
	 rule every;
	    request.grant;
	 endrule

	 rule update_m_num_addr;
	    m_num_addr <= 0;
	 endrule
      end
   else
      begin

	 let arbiter <- arbModule(master_addr);

	 Vector#(master_count, ArbiterRequest_IFC) requests <- mapM(mkArbiterRequest, masters);
	 zipWithM(mkConnection, arbiter.clients, requests);

	 rule connect_handler_inputs;
	    arbiter.handler.hresp_in(hresp_in);
	    arbiter.handler.hready_in(hready_in);
	 endrule

	 hresp  = arbiter.handler.hresp;
	 hready = arbiter.handler.hready;
	 //   let hrdata = slave_data.bus.hrdata;

	 rule update_m_num_addr;
	    m_num_addr <= fromMaybe(0, arbiter.hmaster);
	 endrule

      end

   let hrdata = selectQualified(s_all_data, map(get_hrdata, slaves));

   rule hready_update (hready);
      m_num_data <= m_num_addr;
//      s_num_data <= s_num_addr;
      s_all_data <= s_all_addr;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule broadcast_to_slaves;
      for (Integer x = 0; x < islave_count; x = x + 1)
	 begin
	    let slavex  = slaves[x];
//	    Bool select = (fromInteger(x) == s_num_addr);
	    Bool select = s_all_addr[x];

	    let wdata   = master_data.bus.hwdata;

	    slavex.selector.select(select);

	    slavex.bus.haddr(master_addr.bus.haddr);
	    slavex.bus.hwdata(wdata);
	    slavex.bus.hsize(master_addr.bus.hsize);
	    slavex.bus.htrans(master_addr.bus.htrans);
	    slavex.bus.hwrite(master_addr.bus.hwrite);
	    slavex.bus.hburst(master_addr.bus.hburst);
	    slavex.bus.hprot(master_addr.bus.hprot);
	    slavex.bus.hmast(extendNP(m_num_addr));

	 end
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule broadcast_hready_to_slaves;
      for (Integer x = 0; x < islave_count; x = x + 1)
	 begin
	    let slavex = slaves[x];
	    slavex.bus.hreadyin(hready);
	 end
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule broadcast_to_masters;
      for (Integer x = 0; x < imaster_count; x = x + 1)
	 begin

	    let masterx = masters[x];

	    masterx.bus.hresp(hresp);
	    masterx.bus.hready(hready);
	    masterx.bus.hrdata(hrdata);

	 end

   endrule

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module getCurrentSlave#(AhbXtorMaster#(`TLM_PRM) master,
			Vector#(slave_count, AhbXtorSlaveWM#(`TLM_PRM)) slaves,
			Bool dummy_on_idle) (ReadOnly#(LBit#(slave_count)));

   Reg#(LBit#(slave_count)) current <- mkReg(0);

   let slave_num = selectSlave(slaves, master.bus.haddr);

   // dummy_on_idle True means that the dummy slave (slave 0)
   // should be selected whenever HTRANS is IDLE or BUSY.
   slave_num = (!dummy_on_idle || (master.bus.htrans == NONSEQ) || (master.bus.htrans == SEQ)) ? slave_num : 0;

   method LBit#(slave_count) _read;
      return slave_num;
   endmethod

endmodule

function Vector#(slave_count, Bool) getCurrentSlaveVector (AhbXtorMaster#(`TLM_PRM) master,
							   Vector#(slave_count, AhbXtorSlaveWM#(`TLM_PRM)) slaves,
							   Bool dummy_on_idle);
   AhbAddr#(`TLM_PRM) addr = master.bus.haddr;

   function Bool addrMatch(AhbAddr#(`TLM_PRM) address, AhbXtorSlaveWM#(`TLM_PRM) slave);
      return slave.addrMatch(address);
   endfunction

   Vector#(slave_count, Bool) x = map(addrMatch(addr), slaves);

   Bool idle =  !(master.bus.htrans == NONSEQ) && !(master.bus.htrans == SEQ);
   Bool select_dummy = (idle && dummy_on_idle) || ((pack(x) >> 1) == 0);

   if (select_dummy)
      begin
	 Vector#(slave_count, Bool) value = replicate(False);
	 value[0] = True;
	 return value;
      end
   else
      begin
	 x[0] = False;
	 return x;
      end

endfunction

function LBit#(slave_count) selectSlave (Vector#(slave_count, AhbXtorSlaveWM#(`TLM_PRM)) slaves,
					 AhbAddr#(`TLM_PRM) addr);

   let islave_count = valueOf(slave_count);

   Integer selected = 0; // the dummy slave
   Bool found = False;

   for (Integer x = 1; (x < islave_count) && !found ; x = x + 1)
	 begin
	    let slave = slaves[x];
	    if (slave.addrMatch(addr))
	       begin
		  selected = x;
		  found = True;
	       end
	 end
   return fromInteger(selected);
endfunction

function a selectQualified (Vector#(n, Bool) q_vector, Vector#(n, a) d_vector)
   provisos(Bits#(a, sa), Add#(1, ignore, n));

   function Bit#(sa) qual (Bool q, Bit#(sa) d);
      return (q) ? d : 0;
   endfunction

   return unpack(fold(\| , zipWith(qual, q_vector, map(pack, d_vector))));

endfunction

endpackage
