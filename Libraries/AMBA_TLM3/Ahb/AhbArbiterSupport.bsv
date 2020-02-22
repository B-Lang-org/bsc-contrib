// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AhbArbiterSupport;

import AhbDefines::*;
import Arbiter::*;
import BUtils::*;
import Vector::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAhbArbiter#(Bool terminate, AhbXtorMaster#(`TLM_PRM) master) (AhbArbiter#(count, `TLM_PRM));

   let icount = valueOf(count);

   // Initially, priority is given to client 0
   Vector#(count, Bool) all_false = replicate(False);
   Vector#(count, Bool) init_value = replicate(False);
   init_value[0] = True;
   Reg#(Vector#(count, Bool)) priority_vector      <- mkReg(init_value);


   Reg#(Vector#(count, Bool))       grant_vector_reg  <- mkReg(all_false);
   Wire#(Vector#(count, Bool))      grant_vector_wire <- mkBypassWire;
   Reg#(Maybe#(LBit#(count)))       hmaster_reg       <- mkReg(Invalid);
   Reg#(Maybe#(LBit#(count)))       hmaster_wire      <- mkBypassWire;
   Reg#(Maybe#(LBit#(count)))       hmaster_addr      <- mkReg(Invalid);
   Vector#(count, PulseWire)        request_vector    <- replicateM(mkPulseWire);
   Vector#(count, PulseWire)        lock_vector       <- replicateM(mkPulseWire);
   PulseWire                        update_wire       <- mkPulseWire;

   Reg#(Vector#(count, Bool))       dgrant_vector_reg  <- mkReg(all_false);
   Wire#(Vector#(count, Bool))      dgrant_vector_wire <- mkBypassWire;


   ////////////////////////////////////////////////////////////////////////////////
   ///
   ////////////////////////////////////////////////////////////////////////////////

   let max_idle = 65535;
   let resp_handler <- mkAhbResponseHandler(max_idle);

   let hready = resp_handler.hready;
   let hresp  = resp_handler.hresp;

   ////////////////////////////////////////////////////////////////////////////////
   /// Add a monitor module (to know when the transfer is over).
   ////////////////////////////////////////////////////////////////////////////////

   AhbMonitor monitor <- mkAhbMasterMonitor(master);

   rule monitor_hready;
      monitor.hready_in(hready);
   endrule

   rule monitor_hresp;
      monitor.hresp_in(hresp);
   endrule


   rule update_grant (!isValid(hmaster_addr) || monitor.update || terminate);
      update_wire.send;
   endrule

   rule hready_update(hready);
      hmaster_addr <= hmaster_wire;
   endrule

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
      (hready) ? grant_vector_wire : zipWith(band, grant_vector_wire, dgrant_vector_reg);
      dgrant_vector_reg <=
      (hready) ? grant_vector_wire : zipWith(band, grant_vector_wire, dgrant_vector_reg);

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
   method    hmaster    =  hmaster_addr;
   interface handler     = resp_handler;

endmodule

///////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AhbMonitor;
   method Bool update;
   method Action hready_in(Bool value);
   method Action hresp_in(AhbResp value);
endinterface

module mkAhbMasterMonitor#(AhbXtorMaster#(`TLM_PRM) master) (AhbMonitor);

   Reg#(Bit#(5)) remaining_reg   <- mkReg(0);
   PulseWire     update_wire     <- mkPulseWire;

   let transfer = master.bus.htrans;
   let burst    = master.bus.hburst;
   let command  = master.bus.hwrite;
   let addr     = master.bus.haddr;
   let request  = master.arbiter.hbusreq;

   Wire#(Bool)    hready <- mkBypassWire;
   Wire#(AhbResp) hresp  <- mkBypassWire;

   Reg#(Bool)        request_prev  <- mkReg(False);
   Reg#(Bool)        started       <- mkReg(False);
   Reg#(AhbResp)     hresp_prev      <- mkReg(?);
   Reg#(AhbResp)     hresp_prev_prev <- mkReg(?);

   let update_value = (burst == INCR)
                      ? (request_prev && !request && started)
		      : (remaining_reg == 1 && transfer == SEQ) ||
                        (remaining_reg == 1 && transfer == IDLE) ||
			(transfer == NONSEQ && burst == SINGLE);

   rule track_hresp;
      hresp_prev <= hresp;
      hresp_prev_prev <= hresp_prev;
   endrule

   Bool zow = (hresp_prev == RETRY || hresp_prev == SPLIT) && hresp_prev != hresp_prev_prev;

   rule send_update (hready && update_value || zow);
      update_wire.send;
   endrule

   rule update_started (hready);
      if (isFirst(transfer) && !update_value)
	 started <= True;
      else if (update_value)
	 started <= False;
   endrule

   rule sample (hready);
      request_prev  <= request;
      Bit#(5) remaining = 0;
      if (transfer == IDLE)
	 begin
	    remaining = 1;
	 end
      else if (isFirst(transfer))
	 remaining = (burst == SINGLE) ? 1: fromInteger(getAhbCycleCount(burst)) - 1;
      else if (transfer == SEQ)
	 remaining = remaining_reg - 1;
      else
	 remaining = remaining_reg;
      if ((burst == INCR) && (transfer != IDLE) && request)
	 remaining = 1;
      remaining_reg <= remaining;
   endrule

   method update = update_wire;
   method Action hready_in(Bool value);
      hready <= value;
   endmethod
   method Action hresp_in(AhbResp value);
      hresp <= value;
   endmethod

endmodule

function Bool isFirst (AhbTransfer transfer);
   return (transfer == IDLE || transfer == NONSEQ);
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

(* synthesize *)
(* always_ready, always_enabled *)
module mkAhbResponseHandler#(parameter UInt#(16) max_idle) (AhbResponseHandler);

   Wire#(Bool)    hready_wire <- mkBypassWire;
   Wire#(AhbResp) hresp_wire  <- mkBypassWire;

   Reg#(Bool)     running     <- mkReg(True);
   Reg#(UInt#(16)) idle_count <- mkReg(1);

   let do_timeout = (idle_count == max_idle);

   rule idle_reset (hready_wire && running);
      idle_count <= 1;
   endrule

   rule idle_incr (!hready_wire && running);
      if (do_timeout)
	 begin
	    idle_count <= 1;
	    running <= False;
	 end
      else
	 idle_count <= idle_count + 1;
   endrule

   rule idle_restart (!running);
      running <= True;
   endrule

   rule timeout (do_timeout);
      $display("(%0d) WARNING: (%m) No HREADYOUT in %0d cycles.\n(%0d) WARNING: Sending ERROR response.", $time, max_idle, $time);
   endrule

   method hready_in = hready_wire._write;
   method hresp_in  = hresp_wire._write;

   method Bool hready;
      if (running)
	 return (do_timeout) ? False : hready_wire;
      else
	 return True;
   endmethod

   method AhbResp hresp;
      if (running)
	 return (do_timeout) ? ERROR : hresp_wire;
      else
	 return ERROR;
   endmethod
//   method Bool timeout = do_timeout;

endmodule

endpackage





