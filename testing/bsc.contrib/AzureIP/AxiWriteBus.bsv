package AxiWriteBus;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import Axi::*;
import Connectable::*;
import TLM2::*;
import Vector::*;

`include "Axi.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

(* synthesize *)
module sysAxiWriteBus ();

   Reg#(Bit#(16)) count <- mkReg(0);

   function Bool addrMatch0(AxiAddr#(`TLM_PRM) a);
      return (a[12] == 0);
   endfunction

   function Bool addrMatch1(AxiAddr#(`TLM_PRM) a);
      return (a[12] == 1);
   endfunction

   TLMSendIFC#(`AXI_RR_STD)           source_0 <- mkTLMSource(tagged Valid WRITE, True);
   TLMSendIFC#(`AXI_RR_STD)           source_1 <- mkTLMSource(tagged Valid WRITE, True);

   AxiWrMasterXActorIFC#(`AXI_XTR_STD) master_0 <- mkAxiWrMasterStd;
   AxiWrMasterXActorIFC#(`AXI_XTR_STD) master_1 <- mkAxiWrMasterStd;

   AxiWrSlaveXActorIFC#(`AXI_XTR_STD)  slave_0 <- mkAxiWrSlaveStd(addrMatch0);
   AxiWrSlaveXActorIFC#(`AXI_XTR_STD)  slave_1 <- mkAxiWrSlaveStd(addrMatch1);

   TLMRecvIFC#(`AXI_RR_STD)  mem_0   <- mkTLMRam(0, True);
   TLMRecvIFC#(`AXI_RR_STD)  mem_1   <- mkTLMRam(1, True);

   mkConnection(source_0, master_0.tlm);
   mkConnection(source_1, master_1.tlm);

   Vector#(2, AxiWrFabricMaster#(`AXI_PRM_STD)) masters = newVector;
   Vector#(2, AxiWrFabricSlave#(`AXI_PRM_STD))  slaves = newVector;

   masters[0] = master_0.fabric;
   masters[1] = master_1.fabric;
   slaves[0]  = slave_0.fabric;
   slaves[1]  = slave_1.fabric;

   mkAxiWrBus(masters, slaves);

   mkConnection(slave_0.tlm, mem_0);
   mkConnection(slave_1.tlm, mem_1);

/* -----\/----- EXCLUDED -----\/-----
   let monitor_m0 <- mkMonitor(master_0.fabric.bus);
   let monitor_m1 <- mkMonitor(master_1.fabric.bus);
   let monitor_s0 <- mkMonitor(slave_0.fabric.bus);
   let monitor_s1 <- mkMonitor(slave_1.fabric.bus);
 -----/\----- EXCLUDED -----/\----- */

   rule every;
      count <= count + 1;
      if (count == 500) $finish;
   endrule

endmodule

endpackage
