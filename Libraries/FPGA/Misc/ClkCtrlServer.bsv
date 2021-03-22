// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package ClkCtrlServer;

import Clocks::*;
import FIFO::*;
import GetPut::*;

// ===========================================================================

typedef Bit#(64) ClkCtrlCycleStamp;

function Bit#(32) getCycleStampMSB (ClkCtrlCycleStamp cycle);
   return truncateLSB(cycle);
endfunction

function Bit#(32) getCycleStampLSB (ClkCtrlCycleStamp cycle);
   return truncate(cycle);
endfunction

typedef Bit#(30) EdgeCount;

typedef union tagged {
   EdgeCount Edges;
   void      Query;
   void      Stop;
   void      Resume;
} ClkCtrlReq deriving (Eq, Bits, FShow);

typedef struct {
   ClkCtrlCycleStamp cycle;
   Bool              running;
   Bool              free_running;
   EdgeCount         edges;
} ClkCtrlResp deriving (Eq, Bits, FShow);

// -------------------------

interface ClkCtrlServerCore;
   interface Put#(ClkCtrlReq)  cmd;
   interface GetS#(ClkCtrlResp) status;

   (* always_enabled *)
   method Action preedge(Bool val);
   (* always_ready *)
   method Bool allow_edge();
endinterface

interface ClkCtrlServerWithCClk;
   interface Put#(Bit#(32)) rx;
   interface Get#(Bit#(32)) tx;

   (* always_enabled *)
   method Action preedge(Bool val);
   (* always_ready *)
   method Bool allow_edge();
endinterface

interface ClkCtrlServer;
   interface Put#(Bit#(32)) rx;
   interface Get#(Bit#(32)) tx;

   interface Clock cclk;
   interface Reset crst;
endinterface

// -------------------------

(* synthesize *)
module mkClkCtrlServer (ClkCtrlServer);

   MakeClockIfc#(Bit#(1)) cclkgen <- mkUngatedClock(0);
   Clock cclock = cclkgen.new_clk;

   Reset creset <- mkAsyncResetFromCR(1, cclock);

   PulseWire rising_cclk_pw <- mkPulseWire;

   ClkCtrlServerWithCClk _server <- mkClkCtrlServerWithCClk(cclock, creset);

   Reg#(Bool) initDone <- mkReg(False);

   rule toggle_cclk_reset (! initDone);
      let new_value = ~cclkgen.getClockValue();
      cclkgen.setClockValue(new_value);
      initDone <= True;
   endrule

   rule toggle_cclk_pos (initDone && (cclkgen.getClockValue == 0) && _server.allow_edge);
      let new_value = ~cclkgen.getClockValue();
      cclkgen.setClockValue(new_value);
      rising_cclk_pw.send();
   endrule

   rule toggle_cclk_neg (initDone && (cclkgen.getClockValue == 1));
      let new_value = ~cclkgen.getClockValue();
      cclkgen.setClockValue(new_value);
   endrule

   rule send_preedge;
      _server.preedge(rising_cclk_pw);
   endrule

   interface rx = _server.rx;
   interface tx = _server.tx;

   interface cclk = cclock;
   interface crst = creset;
endmodule: mkClkCtrlServer

// -------------------------

module mkClkCtrlServerWithCClk
	  ( Clock                 cclock
	  , Reset                 creset
	  , ClkCtrlServerWithCClk ifc
	  );

   ClkCtrlServerCore core <- mkClkCtrlServerCore(cclock, creset);

   // Is a FIFO necessary?
   FIFO#(Bit#(32)) fTx <- mkFIFO;

   // Status messages are sent in 3 beats
   Reg#(Bit#(2)) status_beat_count <- mkReg(0);

   rule tx_status;
      let s = core.status.first;
      Bit#(32) val;
      if (status_beat_count == 0) begin
         val = getCycleStampMSB(s.cycle);
         status_beat_count <= status_beat_count + 1;
      end
      else if (status_beat_count == 1) begin
         val = getCycleStampLSB(s.cycle);
         status_beat_count <= status_beat_count + 1;
      end
      else begin
         val = { pack(s.running), pack(s.free_running), pack(s.edges) };
         status_beat_count <= 0;
	 core.status.deq;
      end
      fTx.enq(val);
   endrule

   // ---------------

   interface Put rx;
      method put(x) = core.cmd.put(unpack(x));
   endinterface

   interface tx = toGet(fTx);

   method preedge = core.preedge;
   method allow_edge = core.allow_edge;

endmodule: mkClkCtrlServerWithCClk

// -------------------------

(* synthesize *)
module mkClkCtrlServerCore
	  ( Clock             cclock
	  , Reset             creset
	  , ClkCtrlServerCore ifc
	  );

   Clock uclock <- exposeCurrentClock;

   FIFO#(ClkCtrlReq)        fCmd           <- mkFIFO;
   FIFO#(ClkCtrlResp)       fStatus        <- mkFIFO;

   Wire#(Bool)              detected_edge  <- mkBypassWire;

   Reg#(Bool)               stopped        <- mkReg(True);

   Reg#(EdgeCount)          edges_to_allow [2] <- mkCReg(2, 0);
   Reg#(Bool)               free_running   [2] <- mkCReg(2, False);

   // ---------------

   CrossingReg#(ClkCtrlCycleStamp)  stamp
     <- mkNullCrossingRegA(uclock, unpack(0), clocked_by cclock, reset_by creset);

   rule update_cycle;
      stamp <= stamp + 1;
   endrule

   // ---------------

   Bool active = !stopped && (edges_to_allow[0] != 0);

   rule decr_edges if (active && detected_edge);
      // If it is free running then count down to 1
      // and then let edges allowed go back up to max
      if (free_running[0] && edges_to_allow[0] == 1)
         edges_to_allow[0] <= maxBound;
      else begin
         edges_to_allow[0] <= edges_to_allow[0] - 1;
      end
      // XXX If we want, we can send a status when the edges get to 0
      // if (edges_to_allow[0] == 1)  send_status();
   endrule

   // ---------------

   function Action send_status();
    action
      let resp = ClkCtrlResp {
                    cycle:        stamp.crossed,
		    running:      !stopped,
		    free_running: free_running[1],
		    edges:        edges_to_allow[1]
		 };
      // When the free running mode is stopped,
      // clear the model and edge counter after sending the response
      if ( stopped && free_running[1] ) begin
         free_running[1]   <= False;
         edges_to_allow[1] <= 0;
      end
      fStatus.enq(resp);
    endaction
   endfunction

   // ---------------

   rule handle_query_request if (fCmd.first matches tagged Query);
      fCmd.deq;
      send_status();
   endrule

   // In response to some commands, we save time by sending a status message
   // XXX If the host sw does not use this message, then it will need
   // XXX to drain these accumulated messages before making a request for
   // XXX which it does need the response

   rule handle_edge_request if (fCmd.first matches tagged Edges .numedges);
      //
      // If the number of edges received is 'h1FFFFFFF
      // the simulation will be free_running mode (nonstop)
      //
      fCmd.deq;
      stopped           <= False;
      free_running[1]   <= (numedges == maxBound);
      edges_to_allow[1] <= numedges;
   endrule

   (* descending_urgency = "handle_stop_request, decr_edges" *)
   rule handle_stop_request if (fCmd.first matches tagged Stop);
      fCmd.deq;
      send_status();
      stopped           <= True;
   endrule

   rule handle_resume_request if (fCmd.first matches Resume);
      fCmd.deq;
      send_status();
      stopped           <= False;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////

   interface cmd    = toPut(fCmd);
   interface status = fifoToGetS(fStatus);

   method preedge = detected_edge._write;
   method allow_edge = active;

endmodule: mkClkCtrlServerCore

// ===========================================================================

endpackage: ClkCtrlServer
