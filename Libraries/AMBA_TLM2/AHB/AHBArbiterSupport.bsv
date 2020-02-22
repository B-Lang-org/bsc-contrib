// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AHBArbiterSupport;

import Arbiter::*;
import Connectable::*;
import Probe::*;
import Vector::*;

typedef Bit#(TSub#(TAdd#(TLog#(m), 1), TDiv#(TLog#(m), m))) LBit#(numeric type m);

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AHBArbiter#(numeric type count);
   interface Vector#(count, ArbiterClient_IFC) clients;
   method    Maybe#(LBit#(count))              hmaster;
   method    Action                            update;
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typeclass Arbitable#(type a);
   module mkArbiterRequest#(a ifc) (ArbiterRequest_IFC);
endtypeclass

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAHBArbiter#(Bool ready) (AHBArbiter#(count));

   let icount = valueOf(count);

   // Initially, priority is given to client 0
   Vector#(count, Bool) all_false = replicate(False);
   Vector#(count, Bool) init_value = replicate(False);
   init_value[0] = True;
   Reg#(Vector#(count, Bool)) priority_vector      <- mkReg(init_value);


   Reg#(Vector#(count, Bool))       grant_vector_reg  <- mkReg(all_false);
   Wire#(Vector#(count, Bool))      grant_vector_wire <- mkBypassWire;
   Reg#(Maybe#(LBit#(count)))       hmaster_reg      <- mkReg(Invalid);
   Reg#(Maybe#(LBit#(count)))       hmaster_wire     <- mkBypassWire;
   Vector#(count, PulseWire)        request_vector    <- replicateM(mkPulseWire);
   Vector#(count, PulseWire)        lock_vector       <- replicateM(mkPulseWire);
   PulseWire                        update_wire       <- mkPulseWire;

   Reg#(Vector#(count, Bool))       dgrant_vector_reg  <- mkReg(all_false);
   Wire#(Vector#(count, Bool))      dgrant_vector_wire <- mkBypassWire;

   rule every;

      // calculate the grant_vector
      Vector#(count, Bool) zow                  = all_false;
      Vector#(count, Bool) grant_vector_local   = all_false;
      Maybe#(LBit#(count)) hmaster_local = tagged Invalid;

      Bool found = True;

      for (Integer x = 0; x < (2 * icount); x = x + 1)

	 begin

	    Integer y = (x % icount);

	    if (priority_vector[y]) found = False;

	    let a_request = request_vector[y];
	    zow[y] = a_request;

	    if (!found && a_request)
	       begin
		  grant_vector_local[y] = True;
		  hmaster_local        = tagged Valid fromInteger(y);
		  found = True;
	       end
	 end

      hmaster_reg       <= (update_wire) ? hmaster_local     : hmaster_reg;
      hmaster_wire      <= (update_wire) ? hmaster_local     : hmaster_reg;
      grant_vector_reg  <= (update_wire) ? grant_vector_local : grant_vector_reg;
      grant_vector_wire <= (update_wire) ? grant_vector_local : grant_vector_reg;

      // If a new grant was given, update the priority vector so that
      // client now has lowest priority.
      if (any(id, grant_vector_local) && update_wire)

	 priority_vector <= rotateR(grant_vector_local);

/* -----\/----- EXCLUDED -----\/-----

      $display("  priority vector %b", priority_vector, $time);
      $display("   request vector %b", zow, $time);
      $display("     Grant vector %b", grant_vector_local, $time);
      $display("Grant vector prev %b", grant_vector_reg, $time);
      -----/\----- EXCLUDED -----/\----- */
   endrule

   rule delay_grant;
      function band (a, b);
	 return a && b;
      endfunction

      dgrant_vector_wire <=
      (ready) ? grant_vector_wire : zipWith(band, grant_vector_wire, dgrant_vector_reg);
      dgrant_vector_reg <=
      (ready) ? grant_vector_wire : zipWith(band, grant_vector_wire, dgrant_vector_reg);

   endrule

   // Now create the vector of interfaces
   Vector#(count, ArbiterClient_IFC) client_vector = newVector;

   for (Integer x = 0; x < icount; x = x + 1)

      client_vector[x] = (interface ArbiterClient_IFC

			     method Action request();
				request_vector[x].send();
			     endmethod

			     method Action lock();
				dummyAction;
			     endmethod

			     method grant ();
				return dgrant_vector_wire[x];
			     endmethod
			  endinterface);

   interface clients     = client_vector;
   method    hmaster    =  hmaster_wire;
   method    update      = update_wire.send;

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

function Action dummyAction ();
   action
      $write("");
   endaction
endfunction

endpackage
