////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : ApbBus.bsv
//  Description   : APB Bus Collection
////////////////////////////////////////////////////////////////////////////////
package ApbBus;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import ApbDefines        ::*;
import ApbSlave          ::*;

import Connectable       ::*;
import Vector            ::*;
import BUtils            ::*;
import TLM3              ::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkApbBusFabric#( ApbXtorMaster#(`TLM_PRM) master
                      , Vector#(slv_count, ApbXtorSlaveWM#(`TLM_PRM)) slvs
                      , Bool error_on_idle
                      )(Empty)
   provisos(Add#(slv_count, 1, slave_count));

   Integer islave_count = valueOf(slave_count);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   ApbXtorSlave#(`TLM_PRM)                   err_slave           <- mkApbErrorSlave;
   let                                       slaves_wm            = cons(addAddrMatch(?,err_slave), slvs);
   let                                       slaves               = cons(err_slave, map(convert, slvs));

   let                                       init                 = replicate(False);
   init[0] = True;

   Reg#(Vector#(slave_count, Bool))          s_all_data          <- mkReg(init);
   let                                       s_all_addr           = getCurrentSlaveVector(master, slaves_wm, error_on_idle);

   function Bool                             get_pready  (ApbXtorSlave#(`TLM_PRM) slave) = slave.bus.pready;
   function ApbData#(`TLM_PRM)               get_prdata  (ApbXtorSlave#(`TLM_PRM) slave) = slave.bus.prdata;
   function Bool                             get_pslverr (ApbXtorSlave#(`TLM_PRM) slave) = slave.bus.pslverr;

   let                                       prdata               = selectQualified(s_all_addr, map(get_prdata, slaves));
   let                                       pslverr              = selectQualified(s_all_addr, map(get_pslverr, slaves));
   let                                       pready               = selectQualified(s_all_addr, map(get_pready, slaves));

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* fire_when_enabled, no_implicit_conditions *)
   rule broadcast_to_slaves;
      for(Integer x = 0; x < islave_count; x = x + 1) begin
         let slavex  = slaves[x];
         Bool select = s_all_addr[x] && master.bus.psel;

         slavex.bus.psel(select);
         slavex.bus.paddr(master.bus.paddr);
	 slavex.bus.pprot(master.bus.pprot);
         slavex.bus.penable(master.bus.penable);
         slavex.bus.pwrite(master.bus.pwrite);
         slavex.bus.pwdata(master.bus.pwdata);
	 slavex.bus.pstrb(master.bus.pstrb);
      end
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule broadcast_to_master;
      master.bus.pready(pready);
      master.bus.prdata(prdata);
      master.bus.pslverr(pslverr);
   endrule
endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////
function Vector#(slave_count, Bool) getCurrentSlaveVector( ApbXtorMaster#(`TLM_PRM) master
                                                         , Vector#(slave_count, ApbXtorSlaveWM#(`TLM_PRM)) slaves
                                                         , Bool error_on_idle
                                                         );
   function Bool addrMatch(ApbAddr#(`TLM_PRM) address, ApbXtorSlaveWM#(`TLM_PRM) slave);
      return slave.addrMatch(address);
   endfunction

   ApbAddr#(`TLM_PRM) addr      = master.bus.paddr;
   Vector#(slave_count, Bool) x = map(addrMatch(addr), slaves);

   Bool select_error = ((pack(x)>>1) == 0);

   if (select_error) begin
      Vector#(slave_count, Bool) value = replicate(False);
      value[0] = True;
      return value;
   end
   else begin
      x[0] = False;
      return x;
   end
endfunction

function a selectQualified(Vector#(n, Bool) q_vector, Vector#(n, a) d_vector)
   provisos(Bits#(a, sa), Add#(1, ignore, n));

   function Bit#(sa) qual (Bool q, Bit#(sa) d);
      return (q) ? d : 0;
   endfunction

   return unpack(fold(\| , zipWith(qual, q_vector, map(pack, d_vector))));
endfunction

endpackage: ApbBus

