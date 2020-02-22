// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AhbSlave;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import AhbDefines::*;
import BUtils::*;
import CBus::*;
import DReg::*;
import DefaultValue::*;
import FIFO::*;
import FIFOF::*;
import FShow::*;
import GetPut::*;
import SpecialFIFOs::*;
import TLM3::*;
import TieOff::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AhbSlaveIFC#(`TLM_PRM_DCL);
   interface AhbSlave#(`TLM_PRM)              bus;
   interface Put#(AhbResponse#(`TLM_PRM))     response;
   interface Put#(AhbResponse#(`TLM_PRM))     response_noready;
   interface ReadOnly#(AhbRequest#(`TLM_PRM)) request;
   interface ReadOnly#(AhbSplit)              hmaster;
   interface ReadOnly#(Bool)                  readyin;
endinterface

module mkAhbSlaveIFC#(Bool selected) (AhbSlaveIFC#(`TLM_PRM));

   Wire#(AhbData#(`TLM_PRM)) wdata_wire    <- mkBypassWire;
   Wire#(AhbWrite)           write_wire    <- mkBypassWire;
   Wire#(AhbSize)            size_wire     <- mkBypassWire;
   Wire#(AhbBurst)           burst_wire    <- mkBypassWire;
   Wire#(AhbTransfer)        transfer_wire <- mkBypassWire;
   Wire#(AhbProt)            prot_wire     <- mkBypassWire;
   Wire#(AhbAddr#(`TLM_PRM)) addr_wire     <- mkBypassWire;
   Wire#(AhbSplit)           mast_wire     <- mkBypassWire;
   Wire#(Bool)               readyin_wire  <- mkBypassWire;

   let dflt = AhbResponse {status:  OKAY,
                                    data:    truncateNP(1024'h123),
                                    command: tagged Invalid};

   Wire#(AhbResponse#(`TLM_PRM)) response_wire <- mkDWire(dflt);
   Wire#(Bool)                   ready         <- mkDWire(False);

   Reg#(Bool)                    select_reg    <- mkReg(False);

   rule update_select (readyin_wire);
      select_reg <= selected;
   endrule

   interface Put response;
      method Action put (AhbResponse#(`TLM_PRM) value) if (select_reg);
         response_wire <= value;
         ready         <= True;
      endmethod
   endinterface

   interface Put response_noready;
      method Action put (AhbResponse#(`TLM_PRM) value) if (select_reg);
         response_wire <= value;
      endmethod
   endinterface

   interface ReadOnly request;
      method AhbRequest#(`TLM_PRM) _read;
         let ctrl = AhbCtrl {command:  write_wire,
                             size:     size_wire,
                             burst:    burst_wire,
                             transfer: transfer_wire,
                             prot:     prot_wire,
                             addr:     addr_wire};
         let value = AhbRequest {ctrl: ctrl, data: wdata_wire};
         return value;
      endmethod
   endinterface

   interface ReadOnly hmaster;
      method AhbSplit _read;
         return mast_wire;
      endmethod
   endinterface

   interface ReadOnly readyin;
      method _read = readyin_wire;
   endinterface

   interface AhbSlave bus;
      // Outputs
      method hrdata = response_wire.data;
      method hresp  = response_wire.status;
      method hsplit = 0;
//      method hready = ready;
      method hready = ready || !select_reg; // added by DB 8/26/2011 (to make assertions happy)
	                                    // I'm unsure why this is safe.

      // Inputs
      method haddr    = addr_wire._write;
      method hwdata   = wdata_wire._write;
      method hwrite   = write_wire._write;
      method hburst   = burst_wire._write;
      method htrans   = transfer_wire._write;
      method hsize    = size_wire._write;
      method hprot    = prot_wire._write;
      method hreadyin = readyin_wire._write;
      method hmast    = mast_wire._write;
   endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAhbSlaveWM#(function Bool addr_match(AhbAddr#(`TLM_PRM) addr)) (AhbSlaveXActorWM#(`TLM_XTR))
   provisos(Bits#(req_t, s0),
            Bits#(resp_t, s1),
            DefaultValue#(TLMResponse#(`TLM_PRM)),
            TLMRequestTC#(req_t, `TLM_PRM),
            TLMResponseTC#(resp_t, `TLM_PRM));

   let _ifc <- mkAhbSlave;

   interface TLMSendIFC     tlm    = _ifc.tlm;
   interface AhbXtorSlaveWM fabric;
      interface AhbSlave         bus      = _ifc.fabric.bus;
      interface AhbSlaveSelector selector = _ifc.fabric.selector;
      method addrMatch = addr_match;
   endinterface
endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAhbSlave (AhbSlaveXActor#(`TLM_XTR))
   provisos(Bits#(req_t, s0),
            Bits#(resp_t, s1),
            DefaultValue#(TLMResponse#(`TLM_PRM)),
            TLMRequestTC#(req_t, `TLM_PRM),
            TLMResponseTC#(resp_t, `TLM_PRM));
   FIFOF#(resp_t) fifo_rx <- mkSizedFIFOF(1);
   FIFOF#(req_t)  fifo_tx <- mkSizedFIFOF(1);
   let _ifc <- mkAhbSlaveP(True, True, False, False, fifo_rx, fifo_tx);
   return _ifc;
endmodule

module mkAhbSlaveKB (AhbSlaveXActor#(`TLM_XTR))
   provisos(Bits#(req_t, s0),
            Bits#(resp_t, s1),
            DefaultValue#(TLMResponse#(`TLM_PRM)),
            TLMRequestTC#(req_t, `TLM_PRM),
            TLMResponseTC#(resp_t, `TLM_PRM));
   FIFOF#(resp_t) fifo_rx <- mkSizedBypassFIFOF(1);
   FIFOF#(req_t)  fifo_tx <- mkSizedBypassFIFOF(1);
   let _ifc <- mkAhbSlaveP(True, True, True, False, fifo_rx, fifo_tx);
   return _ifc;
endmodule

module mkAhbSlaveP#(Bool bypass_write_response,
		    Bool allow_early_reads,
		    Bool keep_bursts,
		    Bool big_endian,
                    FIFOF#(resp_t) fifo_rx,
                    FIFOF#(req_t)  fifo_tx) (AhbSlaveXActor#(`TLM_XTR))
   provisos(Bits#(resp_t, s0),
            DefaultValue#(TLMResponse#(`TLM_PRM)),
            TLMRequestTC#(req_t, `TLM_PRM),
            TLMResponseTC#(resp_t, `TLM_PRM));

   Reg#(Maybe#(AhbMastCtrl#(`TLM_PRM))) ctrl_reg    <- mkReg(Invalid);

   Wire#(Bool)             select_wire <- mkBypassWire;
   Reg#(Bool)              select_reg  <- mkReg(False);

//   FIFOF#(Bit#(0))         fifo_op     <- mkLFIFOF;
   MFIFO2#(TLMBLength#(`TLM_PRM), AhbSplit) fifo_op     <- mkMFIFO2;

   PulseWire                sampling    <- mkPulseWire;

   Reg#(TLMBLength#(`TLM_PRM))     count          <- mkReg(0);
   Reg#(Bool)               first_request  <- mkReg(True);
   Reg#(Bool)               first_response <- mkReg(True);

   let ifc <- mkAhbSlaveIFC(select_wire);

   let request = ifc.request;
   let ctrl_current = toAhbMastCtrl(request.ctrl);
   ctrl_current.mast = ifc.hmaster;


   let fifo_rx_write   = fifo_rx;
   let fifo_op_bypass  = ?;

   if (bypass_write_response)
      begin
         FIFOF#(resp_t)         fifo_write      <- mkFIFOF;
	 MFIFO#(TLMBLength#(`TLM_PRM)) fifo_op_bypass_ <- mkBypassMFIFO;

         fifo_rx_write   = fifo_write;
         fifo_op_bypass  = fifo_op_bypass_;
      end

   rule update_select (ifc.readyin);
      select_reg <= select_wire;
   endrule

   rule grab_response (ctrl_reg matches tagged Valid .ctrl_prev &&&
                       ((ctrl_prev.transfer == SEQ) || (ctrl_prev.transfer == NONSEQ)));
      let tlm_response = toTLMResponse(fifo_rx.first);
      AhbResponse#(`TLM_PRM) ahb_response = fromTLMResponse(tlm_response);
      if (tlm_response.status == ERROR && first_response)
	 begin
	    first_response <= False;
	    ifc.response_noready.put(ahb_response);
	 end
      else
	 begin
	    first_response <= True;
	    ifc.response.put(ahb_response);
	    fifo_rx.deq;
	    let early = fifo_op.first;
	    ctrl_reg <= (select_wire) ? tagged Valid ctrl_current : tagged Invalid;
	    fifo_op.deq;
	    sampling.send;
	    TLMErrorCode code = unpack(truncateNP(tlm_response.data));
	    if (tlm_response.status == ERROR && code == SPLIT)
	       $display("(%0d) MASTER IS: ", $time, fifo_op.first);
	 end
   endrule

   if (bypass_write_response) begin

      (* preempts = "grab_response, grab_write_bypass_response" *)
      rule grab_write_bypass_response (ctrl_reg matches tagged Valid .ctrl_prev &&&
                                 ((ctrl_prev.transfer == SEQ) || (ctrl_prev.transfer == NONSEQ)));
         let ahb_response = AhbResponse {status:  OKAY,
                                         data:    0,
                                         command: tagged Invalid};
         ifc.response.put(ahb_response);
         ctrl_reg <= (select_wire) ? tagged Valid ctrl_current : tagged Invalid;
         fifo_op_bypass.deq;
      endrule

      rule grab_write_delayed_response;
         TLMResponse#(`TLM_PRM) response = toTLMResponse(fifo_rx_write.first);
/*if (response.status != SUCCESS )
	    $display("ERROR: unexpected error in WRITE response."); */
         fifo_rx_write.deq;
      endrule

   end

   rule send_read_request (ctrl_reg matches tagged Valid .ctrl_prev &&&
                           ctrl_prev.command == READ &&&
                           select_reg &&&
                           ((ctrl_prev.transfer == SEQ) || (ctrl_prev.transfer == NONSEQ)));

      let desc = fromAhbCtrl(fromAhbMastCtrl(ctrl_prev));
      desc.data = request.data;
      let remaining = (count == 0) ? desc.b_length : (count - 1);
      count <= remaining;
      let keep = desc.b_length != 0 && keep_bursts;
      let is_last = remaining == 0;
      first_request <= is_last;
      desc.transaction_id = extendNP(ctrl_prev.mast);
      //	 do_incr.send;
      fifo_op.enq(1, ctrl_prev.mast);
      if (!keep)
	 begin
	    desc.b_length     = 0;
	    desc.byte_enable  = tagged Specify getTLMByteEn(big_endian, desc);
	    desc.mark = (is_last) ? LAST : NOT_LAST;
	    fifo_tx.enq(fromTLMRequest(tagged Descriptor desc));

	    //	    fifo_op.enq(ctrl_prev.mast);
	 end
      else
	 begin
	    desc.transaction_id = extendNP(ctrl_prev.mast);
	    desc.mark = OPEN;
	    if (first_request)
	       fifo_tx.enq(fromTLMRequest(tagged Descriptor desc));
	 end
   endrule

   rule send_write_request (ctrl_reg matches tagged Valid .ctrl_prev &&&
                            ctrl_prev.command == WRITE &&&
			    select_reg &&&
                            ((ctrl_prev.transfer == SEQ) || (ctrl_prev.transfer == NONSEQ)));
      let desc = fromAhbCtrl(fromAhbMastCtrl(ctrl_prev));
      let keep = desc.b_length != 1 && keep_bursts;
      desc.data = request.data;
      desc.burst_mode   = INCR;
      desc.transaction_id = extendNP(ctrl_prev.mast);
      if (!keep)
	 begin
	    desc.b_length = 0;
	    desc.byte_enable  = tagged Specify getTLMByteEn(big_endian, desc);
	 end
      RequestData#(`TLM_PRM) data = ?;
      data.data = request.data;
      data.transaction_id = desc.transaction_id;
      if (count == 0)
	 begin

	    count <= desc.b_length;
	    fifo_tx.enq(fromTLMRequest(tagged Descriptor desc));
	 end
      else
	 begin
	    count <= count - 1;
	    if (keep)
	       fifo_tx.enq(fromTLMRequest(tagged Data data));
	    else
	       fifo_tx.enq(fromTLMRequest(tagged Descriptor desc));
	 end
      if (bypass_write_response)
	 fifo_op_bypass.enq(1);
      else
         fifo_op.enq(1, ctrl_prev.mast);
   endrule

   rule default_response (ctrl_reg matches tagged Valid .ctrl_prev &&&
			  ((ctrl_prev.transfer == IDLE) || (ctrl_prev.transfer == BUSY)));

      let ahb_response = AhbResponse {status:  OKAY,
                                      data:    truncateNP(1024'h123),
                                      command: tagged Invalid};
      ifc.response.put(ahb_response);
      ctrl_reg <= (select_wire) ? tagged Valid ctrl_current : tagged Invalid;
      sampling.send;
   endrule

   rule grab_ctrl (ctrl_reg matches tagged Invalid);
      ctrl_reg <= (select_wire) ? tagged Valid ctrl_current : tagged Invalid;
   endrule

   if (allow_early_reads) begin

      (* preempts = "(send_write_request, send_read_request), first_early_read" *)
      rule first_early_read (ctrl_current.command == READ &&&
                             select_wire &&&
                             !select_reg &&&
                             ifc.readyin &&&
                             ((ctrl_current.transfer == SEQ) || (ctrl_current.transfer == NONSEQ)));

	 let desc = fromAhbCtrl(fromAhbMastCtrl(ctrl_current));
         desc.data = request.data;
	 let remaining = (count == 0) ? desc.b_length : (count - 1);
	 count <= remaining;
         desc.b_length     = 0;
	 desc.byte_enable  = tagged Specify getTLMByteEn(big_endian, desc);
	 desc.transaction_id = extendNP(ctrl_current.mast);
	 desc.mark = (remaining == 0) ? LAST : NOT_LAST;
         fifo_tx.enq(fromTLMRequest(tagged Descriptor desc));
         fifo_op.enq(1, ctrl_current.mast);
      endrule

      (* preempts = "(send_write_request, send_read_request), early_read_request" *)
      rule early_read_request (ctrl_current.command == READ &&&
			       select_wire &&&
			       select_reg &&&
			       sampling   &&&
			       ((ctrl_current.transfer == SEQ) || (ctrl_current.transfer == NONSEQ)));

	 let desc = fromAhbCtrl(fromAhbMastCtrl(ctrl_current));
         desc.data = request.data;
	 let remaining = (count == 0) ? desc.b_length : (count - 1);
	 count <= remaining;
         desc.b_length     = 0;
	 desc.byte_enable  = tagged Specify getTLMByteEn(big_endian, desc);
	 desc.transaction_id = extendNP(ctrl_current.mast);
	 desc.mark = (remaining == 0) ? LAST : NOT_LAST;
         fifo_tx.enq(fromTLMRequest(tagged Descriptor desc));
         fifo_op.enq(1, ctrl_current.mast);
      endrule
   end

   interface TLMSendIFC tlm;
      interface Get tx = toGet(fifo_tx);
      interface Put rx;
         method Action put (value);
            let response = toTLMResponse(value);
            case (response.command)
               READ:    fifo_rx.enq(value);
               WRITE:   fifo_rx_write.enq(value);
               UNKNOWN: $display("(%0d) mkAhbSlave (%m): Unhandled case.", $time);
            endcase
         endmethod
      endinterface
   endinterface

   interface AhbXtorSlave fabric;
      interface AhbSlave bus = ifc.bus;
      interface AhbSlaveSelector selector;
         method select = select_wire._write;
      endinterface
   endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAhbSlaveUnmapped (AhbXtorSlave#(`TLM_PRM));
   let _ifc <- mkAhbSlaveDummy;


   interface AhbSlave bus;

      // Outputs
      method hrdata = (_ifc.bus.hresp == ERROR) ? extendNP(pack(UNMAPPED)) : _ifc.bus.hrdata;
      method hresp  = _ifc.bus.hresp;
      method hsplit = _ifc.bus.hsplit;

      method hready = _ifc.bus.hready;

      // Inputs
      method haddr    = _ifc.bus.haddr;
      method hwdata   = _ifc.bus.hwdata;
      method hwrite   = _ifc.bus.hwrite;
      method hburst   = _ifc.bus.hburst;
      method htrans   = _ifc.bus.htrans;
      method hsize    = _ifc.bus.hsize;
      method hprot    = _ifc.bus.hprot;
      method hreadyin = _ifc.bus.hreadyin;
      method hmast    = _ifc.bus.hmast;
   endinterface

   interface selector = _ifc.selector;

endmodule

module mkAhbSlaveDummy (AhbXtorSlave#(`TLM_PRM));

   Wire#(AhbTransfer) transfer_wire <- mkBypassWire;

   Wire#(Bool)        select_wire   <- mkBypassWire;
   Wire#(Bool)        readyin_wire  <- mkBypassWire;

   Reg#(Bool)         ready_prev    <- mkReg(False);
   Reg#(AhbTransfer)  transfer_reg  <- mkReg(IDLE);
   Reg#(Bool)         select_reg    <- mkReg(False);

   rule update_select (readyin_wire);
      transfer_reg <= transfer_wire;
      select_reg <= select_wire;
   endrule

   let resp =  (transfer_reg == IDLE || !select_reg) ? OKAY : ERROR;
   let ready_value = select_reg && ((resp == OKAY) || !ready_prev);

   rule update_ready;
      ready_prev <= ready_value;
   endrule

   function Action noop (a ignore);
      return noAction;
   endfunction

   interface AhbSlave bus;

      // Outputs
      method hrdata = truncateNP(1024'h567);
      method hresp  = resp;
      method hsplit = 0;

      method hready = ready_value;

      // Inputs
      method haddr    = noop;
      method hwdata   = noop;
      method hwrite   = noop;
      method hburst   = noop;
      method Action htrans (value);
         transfer_wire <= value;
      endmethod
      method hsize    = noop;
      method hprot    = noop;
      method hreadyin = readyin_wire._write;
      method hmast    = noop;
   endinterface

   interface AhbSlaveSelector selector;
      method Action select (value);
         select_wire <= value;
      endmethod
   endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
/// Only for for testing purposes (a slave that never sends READY back);
////////////////////////////////////////////////////////////////////////////////

module mkAhbSlaveDead (AhbXtorSlave#(`TLM_PRM));

   let resp = OKAY;
   let ready_value = False;

   function Action noop (a ignore);
      return noAction;
   endfunction

   interface AhbSlave bus;

      // Outputs
      method hrdata = truncateNP(1024'h567);
      method hresp  = OKAY;
      method hsplit = 0;

      method hready = False;

      // Inputs
      method haddr    = noop;
      method hwdata   = noop;
      method hwrite   = noop;
      method hburst   = noop;
      method htrans   = noop;
      method hsize    = noop;
      method hprot    = noop;
      method hreadyin = noop;
      method hmast    = noop;
   endinterface

   interface AhbSlaveSelector selector;
      method select = noop;
   endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface MFIFO#(type a);
   method Action  enq (a value);
   method Action  deq;
   method Bit#(0) first;
   method Action  clear;
endinterface


module mkMFIFO (MFIFO#(a))
   provisos(Bits#(a, sa), Arith#(a), Eq#(a));

   Reg#(a)   count    <- mkReg(0);
   Wire#(a)  enq_wire <- mkWire;
   PulseWire deq_pw   <- mkPulseWire;
   PulseWire clear_pw <- mkPulseWire;

   (* preempts="do_clear, do_enq" *)
   (* preempts="do_clear, do_deq" *)
   rule do_clear (clear_pw);
      count <= 0;
   endrule

   (* preempts="do_enq, do_deq" *)
   rule do_enq;
      count <= enq_wire;
   endrule

   rule do_deq (deq_pw);
      count <= count - 1;
   endrule

   method Action enq (a value) if (count == 0 || (count == 1 && deq_pw));
      enq_wire <= value;
   endmethod

   method Action deq if (count != 0);
      deq_pw.send;
   endmethod

   method Bit#(0) first if (count != 0);
      return 0;
   endmethod

   method Action clear;
      clear_pw.send;
   endmethod

endmodule

module mkBypassMFIFO (MFIFO#(a))
   provisos(Bits#(a, sa), Arith#(a), Eq#(a), Ord#(a));

   Reg#(a)   count    <- mkReg(0);
   Wire#(a)  enq_wire <- mkDWire(0);
   PulseWire deq_pw   <- mkPulseWire;
   PulseWire clear_pw <- mkPulseWire;

   (* preempts="do_clear, update_count" *)
   rule do_clear (clear_pw);
      count <= 0;
   endrule

   rule update_count;
      let offset = (deq_pw) ? 1 : 0;
      count <= count + enq_wire - offset;
   endrule

   method Action enq (a value) if (count == 0);
      enq_wire <= value;
   endmethod

   method Action deq if ((count > 0) || ((count == 0) && (enq_wire > 0)));
      deq_pw.send;
   endmethod

   method Bit#(0) first if ((count > 0) || ((count == 0) && (enq_wire > 0)));
      return 0;
   endmethod

   method Action clear;
      clear_pw.send;
   endmethod

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface MFIFO2#(type a, type b);
   method Action  enq (a v_a, b v_b);
   method Action  deq;
   method b       first;
   method Action  clear;
endinterface


module mkMFIFO2 (MFIFO2#(a, b))
   provisos(Bits#(a, sa), Bits#(b, sb), Arith#(a), Eq#(a));

   Reg#(a)   count    <- mkReg(0);
   Wire#(a)  enq_wire <- mkWire;
   PulseWire deq_pw   <- mkPulseWire;
   PulseWire clear_pw <- mkPulseWire;
   Reg#(b)   current  <- mkReg(?);

   (* preempts="do_clear, do_enq" *)
   (* preempts="do_clear, do_deq" *)
   rule do_clear (clear_pw);
      count <= 0;
   endrule

   (* preempts="do_enq, do_deq" *)
   rule do_enq;
      count <= enq_wire;
   endrule

   rule do_deq (deq_pw);
      count <= count - 1;
   endrule

   method Action enq (a v_a, b v_b) if (count == 0 || (count == 1 && deq_pw));
      enq_wire <= v_a;
      current <= v_b;
   endmethod

   method Action deq if (count != 0);
      deq_pw.send;
   endmethod

   method b first if (count != 0);
      return current;
   endmethod

   method Action clear;
      clear_pw.send;
   endmethod

endmodule


endpackage
