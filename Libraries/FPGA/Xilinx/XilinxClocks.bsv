////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : XilinxClocks.bsv
//  Description   :
////////////////////////////////////////////////////////////////////////////////
package XilinxClocks;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import DefaultValue      ::*;
import BUtils            ::*;
import GetPut            ::*;
import FIFO              ::*;
import DReg              ::*;
import ClientServer      ::*;
import XilinxCells       ::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// Types
////////////////////////////////////////////////////////////////////////////////
typedef enum {
   Restart,
   WaitLock,
   WaitStart,
   Address,
   Read,
   Modify,
   Write,
   WaitWriteReady
} State deriving (Bits, Eq);

typedef struct {
   Bool     rnw;
   Bit#(5)  addr;
   Bit#(16) data;
} XilinxClockRequest deriving (Bits, Eq);

typedef enum { NONE, E2, E3 } XilinxEType deriving(Bits, Eq);

typedef struct {
   XilinxEType e_type;
   Bool        clkout0_buffer;
   Bool        clkout0n_buffer;
   Bool        clkout1_buffer;
   Bool        clkout1n_buffer;
   Bool        clkout2_buffer;
   Bool        clkout2n_buffer;
   Bool        clkout3_buffer;
   Bool        clkout3n_buffer;
   Bool        clkout4_buffer;
   Bool        clkout5_buffer;
   Bool        clkout6_buffer;
   String      bandwidth;
   String      clkfbout_use_fine_ps;
   String      clkout0_use_fine_ps;
   String      clkout1_use_fine_ps;
   String      clkout2_use_fine_ps;
   String      clkout3_use_fine_ps;
   String      clkout4_cascade;
   String      clkout4_use_fine_ps;
   String      clkout5_use_fine_ps;
   String      clkout6_use_fine_ps;
   String      clock_hold;
   String      compensation;
   String      startup_wait;
   Real        clkfbout_mult_f;
   Real        clkfbout_phase;
   Real        clkin1_period;
   Real        clkin2_period;
   Integer     divclk_divide;
   Real        clkout0_divide_f;
   Real        clkout0_duty_cycle;
   Real        clkout0_phase;
   Integer     clkout1_divide;
   Real        clkout1_duty_cycle;
   Real        clkout1_phase;
   Integer     clkout2_divide;
   Real        clkout2_duty_cycle;
   Real        clkout2_phase;
   Integer     clkout3_divide;
   Real        clkout3_duty_cycle;
   Real        clkout3_phase;
   Integer     clkout4_divide;
   Real        clkout4_duty_cycle;
   Real        clkout4_phase;
   Integer     clkout5_divide;
   Real        clkout5_duty_cycle;
   Real        clkout5_phase;
   Integer     clkout6_divide;
   Real        clkout6_duty_cycle;
   Real        clkout6_phase;
   Real        ref_jitter1;
   Real        ref_jitter2;
} XilinxClockParams deriving (Bits, Eq);

instance DefaultValue#(XilinxClockParams);
   defaultValue = XilinxClockParams {
      e_type:                NONE,
      clkout0_buffer:        True,
      clkout0n_buffer:       True,
      clkout1_buffer:        True,
      clkout1n_buffer:       True,
      clkout2_buffer:        True,
      clkout2n_buffer:       True,
      clkout3_buffer:        True,
      clkout3n_buffer:       True,
      clkout4_buffer:        True,
      clkout5_buffer:        True,
      clkout6_buffer:        True,
      bandwidth:             "OPTIMIZED",
      clkfbout_use_fine_ps:  "FALSE",
      clkout0_use_fine_ps:   "FALSE",
      clkout1_use_fine_ps:   "FALSE",
      clkout2_use_fine_ps:   "FALSE",
      clkout3_use_fine_ps:   "FALSE",
      clkout4_cascade:       "FALSE",
      clkout4_use_fine_ps:   "FALSE",
      clkout5_use_fine_ps:   "FALSE",
      clkout6_use_fine_ps:   "FALSE",
      clock_hold:            "FALSE",
      compensation:          "ZHOLD",
      startup_wait:          "FALSE",
      clkfbout_mult_f:       5.000,
      clkfbout_phase:        0.000,
      clkin1_period:         5.000,
      clkin2_period:         0.000,
      divclk_divide:         1,
      clkout0_divide_f:      1.000,
      clkout0_duty_cycle:    0.500,
      clkout0_phase:         0.000,
      clkout1_divide:        10,
      clkout1_duty_cycle:    0.500,
      clkout1_phase:         0.000,
      clkout2_divide:        10,
      clkout2_duty_cycle:    0.500,
      clkout2_phase:         0.000,
      clkout3_divide:        10,
      clkout3_duty_cycle:    0.500,
      clkout3_phase:         0.000,
      clkout4_divide:        10,
      clkout4_duty_cycle:    0.500,
      clkout4_phase:         0.000,
      clkout5_divide:        10,
      clkout5_duty_cycle:    0.500,
      clkout5_phase:         0.000,
      clkout6_divide:        10,
      clkout6_duty_cycle:    0.500,
      clkout6_phase:         0.000,
      ref_jitter1:           0.010,
      ref_jitter2:           0.010
      };
endinstance

typedef Server#(XilinxClockRequest, Bit#(16)) XilinxClockCSR;

typedef Client#(Bit#(32), Bit#(32)) XilinxClkClient;
typedef Server#(Bit#(32), Bit#(32)) XilinxClkServer;

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
(* always_ready, always_enabled *)
interface VMMCM_ADV;
   interface Clock     clkout0;
   interface Clock     clkout0_n;
   interface Clock     clkout1;
   interface Clock     clkout1_n;
   interface Clock     clkout2;
   interface Clock     clkout2_n;
   interface Clock     clkout3;
   interface Clock     clkout3_n;
   interface Clock     clkout4;
   interface Clock     clkout5;
   interface Clock     clkout6;
   interface Clock     clkfbout;
   interface Clock     clkfbout_n;
   method    Action    clkfbin(Bool clk);
   method    Action    rst(Bool i);
   method    Bool      locked();
   method    Action    daddr(Bit#(7) i);
   method    Action    dsel(Bool i);
   method    Action    di(Bit#(16) i);
   method    Action    dwe(Bool i);
   method    Bit#(16)  dout();
   method    Bool      drdy();
endinterface

interface XilinxClockController;
   interface Clock     	    clkout0;
   interface Clock     	    clkout0_n;
   interface Clock     	    clkout1;
   interface Clock     	    clkout1_n;
   interface Clock     	    clkout2;
   interface Clock     	    clkout2_n;
   interface Clock     	    clkout3;
   interface Clock     	    clkout3_n;
   interface Clock     	    clkout4;
   interface Clock     	    clkout5;
   interface Clock     	    clkout6;
   method    Bool      	    locked();
   interface XilinxClockCSR csr;
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkXilinxClockController#(XilinxClockParams params, Clock refclk)(XilinxClockController);

   ////////////////////////////////////////////////////////////////////////////////
   /// Clocks & Resets
   ////////////////////////////////////////////////////////////////////////////////
   MMCMParams                      mmcm_params          = defaultValue;
   mmcm_params.divclk_divide   	  = params.divclk_divide;
   mmcm_params.clkfbout_mult_f 	  = params.clkfbout_mult_f;
   mmcm_params.clkfbout_phase  	  = params.clkfbout_phase;
   mmcm_params.clkin1_period   	  = params.clkin1_period;
   mmcm_params.clkout0_divide_f   = params.clkout0_divide_f;
   mmcm_params.clkout0_duty_cycle = params.clkout0_duty_cycle;
   mmcm_params.clkout0_phase      = params.clkout0_phase;

   VMMCM_ADV                       mmcm                 = ?;

   case (params.e_type)
      E3:      mmcm <- vMMCME3_ADV(mmcm_params, refclk);
      E2:      mmcm <- vMMCME2_ADV(mmcm_params, refclk);
      default: mmcm <- vMMCM_ADV(mmcm_params, refclk);
   endcase

   ReadOnly#(Bool)                 clkfbbuf            <- mkClockBitBUFG(clocked_by mmcm.clkfbout);

   Clock                           clkout0_buf          = ?;
   Clock                           clkout0n_buf         = ?;
   Clock                           clkout1_buf          = ?;
   Clock                           clkout1n_buf         = ?;
   Clock                           clkout2_buf          = ?;
   Clock                           clkout2n_buf         = ?;
   Clock                           clkout3_buf          = ?;
   Clock                           clkout3n_buf         = ?;
   Clock                           clkout4_buf          = ?;
   Clock                           clkout5_buf          = ?;
   Clock                           clkout6_buf          = ?;

   if (params.clkout0_buffer) begin
      Clock clkout0buf <- mkClockBUFG(clocked_by mmcm.clkout0);
      clkout0_buf = clkout0buf;
   end
   else begin
      clkout0_buf = mmcm.clkout0;
   end

   if (params.clkout0n_buffer) begin
      Clock clkout0nbuffer <- mkClockBUFG(clocked_by mmcm.clkout0_n);
      clkout0n_buf = clkout0nbuffer;
   end
   else begin
      clkout0n_buf = mmcm.clkout0_n;
   end

   if (params.clkout1_buffer) begin
      Clock clkout1buffer <- mkClockBUFG(clocked_by mmcm.clkout1);
      clkout1_buf = clkout1buffer;
   end
   else begin
      clkout1_buf = mmcm.clkout1;
   end

   if (params.clkout1n_buffer) begin
      Clock clkout1nbuffer <- mkClockBUFG(clocked_by mmcm.clkout1_n);
      clkout1n_buf = clkout1nbuffer;
   end
   else begin
      clkout1n_buf = mmcm.clkout1_n;
   end

   if (params.clkout2_buffer) begin
      Clock clkout2buffer <- mkClockBUFG(clocked_by mmcm.clkout2);
      clkout2_buf = clkout2buffer;
   end
   else begin
      clkout2_buf = mmcm.clkout2;
   end

   if (params.clkout2n_buffer) begin
      Clock clkout2nbuffer <- mkClockBUFG(clocked_by mmcm.clkout2_n);
      clkout2n_buf = clkout2nbuffer;
   end
   else begin
      clkout2n_buf = mmcm.clkout2_n;
   end

   if (params.clkout3_buffer) begin
      Clock clkout3buffer <- mkClockBUFG(clocked_by mmcm.clkout3);
      clkout3_buf = clkout3buffer;
   end
   else begin
      clkout3_buf = mmcm.clkout3;
   end

   if (params.clkout3n_buffer) begin
      Clock clkout3nbuffer <- mkClockBUFG(clocked_by mmcm.clkout3_n);
      clkout3n_buf = clkout3nbuffer;
   end
   else begin
      clkout3n_buf = mmcm.clkout3_n;
   end

   if (params.clkout4_buffer) begin
      Clock clkout4buffer <- mkClockBUFG(clocked_by mmcm.clkout4);
      clkout4_buf = clkout4buffer;
   end
   else begin
      clkout4_buf = mmcm.clkout4;
   end

   if (params.clkout5_buffer) begin
      Clock clkout5buffer <- mkClockBUFG(clocked_by mmcm.clkout5);
      clkout5_buf = clkout5buffer;
   end
   else begin
      clkout5_buf = mmcm.clkout5;
   end

   if (params.clkout6_buffer) begin
      Clock clkout6buffer <- mkClockBUFG(clocked_by mmcm.clkout6);
      clkout6_buf = clkout6buffer;
   end
   else begin
      clkout6_buf = mmcm.clkout6;
   end

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   FIFO#(XilinxClockRequest)       fRequest            <- mkFIFO;
   FIFO#(Bit#(16))                 fResponse           <- mkFIFO;

   // MMCM State
   Reg#(Bool)                      rMMCM_swrst         <- mkReg(False);
   Reg#(Bool)                      rMMCM_start         <- mkReg(False);
   Reg#(Bool)                      rMMCM_start_d1      <- mkReg(False);
   Reg#(Bit#(16))                  rMMCM_clkout0_1     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clkout0_2     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clkout1_1     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clkout1_2     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clkout2_1     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clkout2_2     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clkout3_1     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clkout3_2     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clkout4_1     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clkout4_2     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clkout5_1     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clkout5_2     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clkout6_1     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clkout6_2     <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clk_div       <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clk_fb_1      <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_clk_fb_2      <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_lock_1        <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_lock_2        <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_lock_3        <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_filter_1      <- mkReg(0);
   Reg#(Bit#(16))                  rMMCM_filter_2      <- mkReg(0);

   // DRP interface
   Reg#(Bool)                      rReset              <- mkReg(True);
   Reg#(Bit#(7))                   rAddress            <- mkReg(0);
   Reg#(Bool)                      rSel                <- mkDReg(False);
   Reg#(Bit#(16))                  rWrData             <- mkReg(0);
   Reg#(Bool)                      rWrEn               <- mkDReg(False);
   Reg#(Bit#(5))                   rCount              <- mkReg(0);
   Reg#(State)                     rState              <- mkReg(Restart);

   Wire#(Bool)                     wRdReady            <- mkBypassWire;
   Wire#(Bit#(16))                 wRdData             <- mkBypassWire;
   Wire#(Bool)                     wLocked             <- mkBypassWire;

   ////////////////////////////////////////////////////////////////////////////////
   /// Functions
   ////////////////////////////////////////////////////////////////////////////////
   function Tuple3#(Bit#(7), Bit#(16), Bit#(16)) fnCountMMCMDataSel(Bit#(5) count);
      case (count)
	 22: return tuple3(7'h28, 16'h0000, 16'hFFFF);
	 21: return tuple3(7'h08, 16'h1000, rMMCM_clkout0_1);
	 20: return tuple3(7'h09, 16'hfc00, rMMCM_clkout0_2);
	 19: return tuple3(7'h0a, 16'h1000, rMMCM_clkout1_1);
	 18: return tuple3(7'h0b, 16'hfc00, rMMCM_clkout1_2);
	 17: return tuple3(7'h0c, 16'h1000, rMMCM_clkout2_1);
	 16: return tuple3(7'h0d, 16'hfc00, rMMCM_clkout2_2);
	 15: return tuple3(7'h0e, 16'h1000, rMMCM_clkout3_1);
	 14: return tuple3(7'h0f, 16'hfc00, rMMCM_clkout3_2);
	 13: return tuple3(7'h10, 16'h1000, rMMCM_clkout4_1);
	 12: return tuple3(7'h11, 16'hfc00, rMMCM_clkout4_2);
	 11: return tuple3(7'h06, 16'h1000, rMMCM_clkout5_1);
	 10: return tuple3(7'h07, 16'hfc00, rMMCM_clkout5_2);
	 9:  return tuple3(7'h12, 16'h1000, rMMCM_clkout6_1);
	 8:  return tuple3(7'h13, 16'hfc00, rMMCM_clkout6_2);
	 7:  return tuple3(7'h16, 16'hc000, rMMCM_clk_div);
	 6:  return tuple3(7'h14, 16'h1000, rMMCM_clk_fb_1);
	 5:  return tuple3(7'h15, 16'hfc00, rMMCM_clk_fb_2);
	 4:  return tuple3(7'h18, 16'hfc00, rMMCM_lock_1);
	 3:  return tuple3(7'h19, 16'h8000, rMMCM_lock_2);
	 2:  return tuple3(7'h1a, 16'h8000, rMMCM_lock_3);
	 1:  return tuple3(7'h4e, 16'h66ff, rMMCM_filter_1);
	 0:  return tuple3(7'h4f, 16'h666f, rMMCM_filter_2);
	 default: return tuple3(7'h00, 16'h0000, 16'h0000);
      endcase
   endfunction

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   rule process_read_request if (fRequest.first.rnw);
      let req <- toGet(fRequest).get;
      case(req.addr)
	 5'h00:   fResponse.enq(16'h0100);
	 5'h01:   fResponse.enq(cExtend({ pack(rMMCM_swrst), pack(rMMCM_start) }));
	 5'h02:   fResponse.enq(rMMCM_clkout0_1);
	 5'h03:   fResponse.enq(rMMCM_clkout0_2);
	 5'h04:   fResponse.enq(rMMCM_clkout1_1);
	 5'h05:   fResponse.enq(rMMCM_clkout1_2);
	 5'h06:   fResponse.enq(rMMCM_clkout2_1);
	 5'h07:   fResponse.enq(rMMCM_clkout2_2);
	 5'h08:   fResponse.enq(rMMCM_clkout3_1);
	 5'h09:   fResponse.enq(rMMCM_clkout3_2);
	 5'h0a:   fResponse.enq(rMMCM_clkout4_1);
	 5'h0b:   fResponse.enq(rMMCM_clkout4_2);
	 5'h0c:   fResponse.enq(rMMCM_clkout5_1);
	 5'h0d:   fResponse.enq(rMMCM_clkout5_2);
	 5'h0e:   fResponse.enq(rMMCM_clkout6_1);
	 5'h0f:   fResponse.enq(rMMCM_clkout6_2);
	 5'h10:   fResponse.enq(rMMCM_clk_div);
	 5'h11:   fResponse.enq(rMMCM_clk_fb_1);
	 5'h12:   fResponse.enq(rMMCM_clk_fb_2);
	 5'h13:   fResponse.enq(rMMCM_lock_1);
	 5'h14:   fResponse.enq(rMMCM_lock_2);
	 5'h15:   fResponse.enq(rMMCM_lock_3);
	 5'h16:   fResponse.enq(rMMCM_filter_1);
	 5'h17:   fResponse.enq(rMMCM_filter_2);
	 5'h1f:   fResponse.enq(cExtend({ pack(rReset), pack(wLocked) }));
	 default: fResponse.enq(0);
      endcase
   endrule

   rule process_write_request if (!fRequest.first.rnw);
      let req <- toGet(fRequest).get;
      case(req.addr)
	 5'h01: begin
		   rMMCM_swrst <= unpack(req.data[1]);
		   rMMCM_start <= unpack(req.data[0]);
		end
	 5'h02: rMMCM_clkout0_1 <= req.data;
	 5'h03: rMMCM_clkout0_2 <= req.data;
	 5'h04: rMMCM_clkout1_1 <= req.data;
	 5'h05: rMMCM_clkout1_2 <= req.data;
	 5'h06: rMMCM_clkout2_1 <= req.data;
	 5'h07: rMMCM_clkout2_2 <= req.data;
	 5'h08: rMMCM_clkout3_1 <= req.data;
	 5'h09: rMMCM_clkout3_2 <= req.data;
	 5'h0a: rMMCM_clkout4_1 <= req.data;
	 5'h0b: rMMCM_clkout4_2 <= req.data;
	 5'h0c: rMMCM_clkout5_1 <= req.data;
	 5'h0d: rMMCM_clkout5_2 <= req.data;
	 5'h0e: rMMCM_clkout6_1 <= req.data;
	 5'h0f: rMMCM_clkout6_2 <= req.data;
	 5'h10: rMMCM_clk_div   <= req.data;
	 5'h11: rMMCM_clk_fb_1  <= req.data;
	 5'h12: rMMCM_clk_fb_2  <= req.data;
	 5'h13: rMMCM_lock_1    <= req.data;
	 5'h14: rMMCM_lock_2    <= req.data;
	 5'h15: rMMCM_lock_3    <= req.data;
	 5'h16: rMMCM_filter_1  <= req.data;
	 5'h17: rMMCM_filter_2  <= req.data;
	 default: noAction;
      endcase
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule process_start_delay;
      rMMCM_start_d1 <= rMMCM_start;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// DRP Connection Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* fire_when_enabled, no_implicit_conditions *)
   rule mmcm_drp_outputs;
      wLocked    <= mmcm.locked();
      wRdData    <= mmcm.dout();
      wRdReady   <= mmcm.drdy();
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule mmcm_feedback;
      mmcm.clkfbin(clkfbbuf);
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule mmcm_drp_inputs;
      mmcm.rst(rReset);
      mmcm.dwe(rWrEn);
      mmcm.daddr(rAddress);
      mmcm.di(rWrData);
      mmcm.dsel(rSel);
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// DRP State Machine
   ////////////////////////////////////////////////////////////////////////////////
   rule restart_state if (rState == Restart);
      rReset     <= True;
      rAddress   <= 0;
      rSel       <= False;
      rWrData    <= 0;
      rWrEn      <= False;
      rCount     <= 0;
      rState     <= WaitLock;
   endrule

   rule wait_lock_state if (rState == WaitLock);
      rReset     <= False;
      rCount     <= 22;

      if (wLocked) begin
	 rState  <= WaitStart;
      end
   endrule

   rule wait_start_state if (rState == WaitStart && rMMCM_start && !rMMCM_start_d1);
      rState     <= Address;
   endrule

   rule address_state if (rState == Address);
      match { .addr, .*, .* } = fnCountMMCMDataSel(rCount);
      rReset     <= True;
      rSel       <= True;
      rAddress   <= addr;
      rState     <= Read;
   endrule

   rule read_state if (rState == Read && wRdReady);
      rState     <= Modify;
   endrule

   rule modify_state if (rState == Modify);
      match { .*, .mask, .data } = fnCountMMCMDataSel(rCount);
      rWrData    <= (mask & wRdData) | (~mask & data);
      rState     <= Write;
   endrule

   rule write_state if (rState == Write);
      rSel       <= True;
      rWrEn      <= True;
      rState     <= WaitWriteReady;
   endrule

   rule wait_write_ready if (rState == WaitWriteReady && wRdReady);
      rCount     <= rCount - 1;
      if (rCount > 0)
	 rState  <= Address;
      else
	 rState  <= WaitLock;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface Clock          clkout0   = clkout0_buf;
   interface Clock          clkout0_n = clkout0n_buf;
   interface Clock          clkout1   = clkout1_buf;
   interface Clock          clkout1_n = clkout1n_buf;
   interface Clock          clkout2   = clkout2_buf;
   interface Clock          clkout2_n = clkout2n_buf;
   interface Clock          clkout3   = clkout3_buf;
   interface Clock          clkout3_n = clkout3n_buf;
   interface Clock          clkout4   = clkout4_buf;
   interface Clock          clkout5   = clkout5_buf;
   interface Clock          clkout6   = clkout6_buf;
   method    Bool           locked    = wLocked;
   interface XilinxClockCSR csr       = toGPServer(toPut(fRequest), toGet(fResponse));

endmodule: mkXilinxClockController

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
///
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
import "BVI" MMCME3_ADV =
module vMMCME3_ADV#(MMCMParams params, Clock refclk)(VMMCM_ADV);
   default_clock dclk(DCLK);
   default_reset no_reset;

   input_clock clk1(CLKIN1) = refclk;

   parameter BANDWIDTH            = params.bandwidth;
   parameter CLKFBOUT_USE_FINE_PS = params.clkfbout_use_fine_ps;
   parameter CLKOUT0_USE_FINE_PS  = params.clkout0_use_fine_ps;
   parameter CLKOUT1_USE_FINE_PS  = params.clkout1_use_fine_ps;
   parameter CLKOUT2_USE_FINE_PS  = params.clkout2_use_fine_ps;
   parameter CLKOUT3_USE_FINE_PS  = params.clkout3_use_fine_ps;
   parameter CLKOUT4_CASCADE      = params.clkout4_cascade;
   parameter CLKOUT4_USE_FINE_PS  = params.clkout4_use_fine_ps;
   parameter CLKOUT5_USE_FINE_PS  = params.clkout5_use_fine_ps;
   parameter CLKOUT6_USE_FINE_PS  = params.clkout6_use_fine_ps;
   parameter COMPENSATION         = params.compensation;
   parameter STARTUP_WAIT         = params.startup_wait;
   parameter CLKFBOUT_MULT_F      = params.clkfbout_mult_f;
   parameter CLKFBOUT_PHASE       = params.clkfbout_phase;
   parameter CLKIN1_PERIOD        = params.clkin1_period;
   parameter CLKIN2_PERIOD        = params.clkin2_period;
   parameter DIVCLK_DIVIDE        = params.divclk_divide;
   parameter CLKOUT0_DIVIDE_F     = params.clkout0_divide_f;
   parameter CLKOUT0_DUTY_CYCLE   = params.clkout0_duty_cycle;
   parameter CLKOUT0_PHASE        = params.clkout0_phase;
   parameter CLKOUT1_DIVIDE       = params.clkout1_divide;
   parameter CLKOUT1_DUTY_CYCLE   = params.clkout1_duty_cycle;
   parameter CLKOUT1_PHASE        = params.clkout1_phase;
   parameter CLKOUT2_DIVIDE       = params.clkout2_divide;
   parameter CLKOUT2_DUTY_CYCLE   = params.clkout2_duty_cycle;
   parameter CLKOUT2_PHASE        = params.clkout2_phase;
   parameter CLKOUT3_DIVIDE       = params.clkout3_divide;
   parameter CLKOUT3_DUTY_CYCLE   = params.clkout3_duty_cycle;
   parameter CLKOUT3_PHASE        = params.clkout3_phase;
   parameter CLKOUT4_DIVIDE       = params.clkout4_divide;
   parameter CLKOUT4_DUTY_CYCLE   = params.clkout4_duty_cycle;
   parameter CLKOUT4_PHASE        = params.clkout4_phase;
   parameter CLKOUT5_DIVIDE       = params.clkout5_divide;
   parameter CLKOUT5_DUTY_CYCLE   = params.clkout5_duty_cycle;
   parameter CLKOUT5_PHASE        = params.clkout5_phase;
   parameter CLKOUT6_DIVIDE       = params.clkout6_divide;
   parameter CLKOUT6_DUTY_CYCLE   = params.clkout6_duty_cycle;
   parameter CLKOUT6_PHASE        = params.clkout6_phase;
   parameter REF_JITTER1          = params.ref_jitter1;
   parameter REF_JITTER2          = params.ref_jitter2;

   port      CLKIN2               = Bit#(1)'(0);
   port      CLKINSEL             = Bit#(1)'(1);
   port      PSCLK                = Bit#(1)'(0);
   port      PSEN                 = Bit#(1)'(0);
   port      PSINCDEC             = Bit#(1)'(0);
   port      PWRDWN               = Bit#(1)'(0);

   output_clock clkfbout(CLKFBOUT);
   output_clock clkfbout_n(CLKFBOUTB);
   output_clock clkout0(CLKOUT0);
   output_clock clkout0_n(CLKOUT0B);
   output_clock clkout1(CLKOUT1);
   output_clock clkout1_n(CLKOUT1B);
   output_clock clkout2(CLKOUT2);
   output_clock clkout2_n(CLKOUT2B);
   output_clock clkout3(CLKOUT3);
   output_clock clkout3_n(CLKOUT3B);
   output_clock clkout4(CLKOUT4);
   output_clock clkout5(CLKOUT5);
   output_clock clkout6(CLKOUT6);

   same_family(clk1, clkfbout);
   same_family(clk1, clkfbout_n);
   same_family(clk1, clkout0);
   same_family(clk1, clkout0_n);
   same_family(clk1, clkout1);
   same_family(clk1, clkout1_n);
   same_family(clk1, clkout2);
   same_family(clk1, clkout2_n);
   same_family(clk1, clkout3);
   same_family(clk1, clkout3_n);
   same_family(clk1, clkout4);
   same_family(clk1, clkout5);
   same_family(clk1, clkout6);

   method              clkfbin(CLKFBIN) enable((*inhigh*)en1) clocked_by(clkfbout) reset_by(no_reset);

   method LOCKED       locked()        clocked_by(no_clock) reset_by(no_reset);

   method              daddr(DADDR)     enable((*inhigh*)en2) clocked_by(dclk) reset_by(no_reset);
   method              dsel(DEN)        enable((*inhigh*)en3) clocked_by(dclk) reset_by(no_reset);
   method              di(DI)           enable((*inhigh*)en4) clocked_by(dclk) reset_by(no_reset);
   method              rst(RST)         enable((*inhigh*)en5) clocked_by(dclk) reset_by(no_reset);
   method DO           dout()           clocked_by(dclk) reset_by(no_reset);
   method DRDY         drdy()           clocked_by(dclk) reset_by(no_reset);
   method              dwe(DWE)         enable((*inhigh*)en6) clocked_by(dclk) reset_by(no_reset);

   schedule clkfbin C clkfbin;
   schedule locked CF locked;
   schedule (daddr, dsel, di, dout, drdy, dwe, rst) CF (daddr, dsel, di, dout, drdy, dwe, rst);

endmodule: vMMCME3_ADV

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////
import "BVI" MMCME2_ADV =
module vMMCME2_ADV#(MMCMParams params, Clock refclk)(VMMCM_ADV);
   default_clock dclk(DCLK);
   default_reset no_reset;

   input_clock clk1(CLKIN1) = refclk;

   parameter BANDWIDTH            = params.bandwidth;
   parameter CLKFBOUT_USE_FINE_PS = params.clkfbout_use_fine_ps;
   parameter CLKOUT0_USE_FINE_PS  = params.clkout0_use_fine_ps;
   parameter CLKOUT1_USE_FINE_PS  = params.clkout1_use_fine_ps;
   parameter CLKOUT2_USE_FINE_PS  = params.clkout2_use_fine_ps;
   parameter CLKOUT3_USE_FINE_PS  = params.clkout3_use_fine_ps;
   parameter CLKOUT4_CASCADE      = params.clkout4_cascade;
   parameter CLKOUT4_USE_FINE_PS  = params.clkout4_use_fine_ps;
   parameter CLKOUT5_USE_FINE_PS  = params.clkout5_use_fine_ps;
   parameter CLKOUT6_USE_FINE_PS  = params.clkout6_use_fine_ps;
   parameter COMPENSATION         = params.compensation;
   parameter STARTUP_WAIT         = params.startup_wait;
   parameter CLKFBOUT_MULT_F      = params.clkfbout_mult_f;
   parameter CLKFBOUT_PHASE       = params.clkfbout_phase;
   parameter CLKIN1_PERIOD        = params.clkin1_period;
   parameter CLKIN2_PERIOD        = params.clkin2_period;
   parameter DIVCLK_DIVIDE        = params.divclk_divide;
   parameter CLKOUT0_DIVIDE_F     = params.clkout0_divide_f;
   parameter CLKOUT0_DUTY_CYCLE   = params.clkout0_duty_cycle;
   parameter CLKOUT0_PHASE        = params.clkout0_phase;
   parameter CLKOUT1_DIVIDE       = params.clkout1_divide;
   parameter CLKOUT1_DUTY_CYCLE   = params.clkout1_duty_cycle;
   parameter CLKOUT1_PHASE        = params.clkout1_phase;
   parameter CLKOUT2_DIVIDE       = params.clkout2_divide;
   parameter CLKOUT2_DUTY_CYCLE   = params.clkout2_duty_cycle;
   parameter CLKOUT2_PHASE        = params.clkout2_phase;
   parameter CLKOUT3_DIVIDE       = params.clkout3_divide;
   parameter CLKOUT3_DUTY_CYCLE   = params.clkout3_duty_cycle;
   parameter CLKOUT3_PHASE        = params.clkout3_phase;
   parameter CLKOUT4_DIVIDE       = params.clkout4_divide;
   parameter CLKOUT4_DUTY_CYCLE   = params.clkout4_duty_cycle;
   parameter CLKOUT4_PHASE        = params.clkout4_phase;
   parameter CLKOUT5_DIVIDE       = params.clkout5_divide;
   parameter CLKOUT5_DUTY_CYCLE   = params.clkout5_duty_cycle;
   parameter CLKOUT5_PHASE        = params.clkout5_phase;
   parameter CLKOUT6_DIVIDE       = params.clkout6_divide;
   parameter CLKOUT6_DUTY_CYCLE   = params.clkout6_duty_cycle;
   parameter CLKOUT6_PHASE        = params.clkout6_phase;
   parameter REF_JITTER1          = params.ref_jitter1;
   parameter REF_JITTER2          = params.ref_jitter2;

   port      CLKIN2               = Bit#(1)'(0);
   port      CLKINSEL             = Bit#(1)'(1);
   port      PSCLK                = Bit#(1)'(0);
   port      PSEN                 = Bit#(1)'(0);
   port      PSINCDEC             = Bit#(1)'(0);
   port      PWRDWN               = Bit#(1)'(0);

   output_clock clkfbout(CLKFBOUT);
   output_clock clkfbout_n(CLKFBOUTB);
   output_clock clkout0(CLKOUT0);
   output_clock clkout0_n(CLKOUT0B);
   output_clock clkout1(CLKOUT1);
   output_clock clkout1_n(CLKOUT1B);
   output_clock clkout2(CLKOUT2);
   output_clock clkout2_n(CLKOUT2B);
   output_clock clkout3(CLKOUT3);
   output_clock clkout3_n(CLKOUT3B);
   output_clock clkout4(CLKOUT4);
   output_clock clkout5(CLKOUT5);
   output_clock clkout6(CLKOUT6);

   same_family(clk1, clkfbout);
   same_family(clk1, clkfbout_n);
   same_family(clk1, clkout0);
   same_family(clk1, clkout0_n);
   same_family(clk1, clkout1);
   same_family(clk1, clkout1_n);
   same_family(clk1, clkout2);
   same_family(clk1, clkout2_n);
   same_family(clk1, clkout3);
   same_family(clk1, clkout3_n);
   same_family(clk1, clkout4);
   same_family(clk1, clkout5);
   same_family(clk1, clkout6);

   method              clkfbin(CLKFBIN) enable((*inhigh*)en1) clocked_by(clkfbout) reset_by(no_reset);

   method LOCKED       locked()        clocked_by(no_clock) reset_by(no_reset);

   method              daddr(DADDR)     enable((*inhigh*)en2) clocked_by(dclk) reset_by(no_reset);
   method              dsel(DEN)        enable((*inhigh*)en3) clocked_by(dclk) reset_by(no_reset);
   method              di(DI)           enable((*inhigh*)en4) clocked_by(dclk) reset_by(no_reset);
   method              rst(RST)         enable((*inhigh*)en5) clocked_by(dclk) reset_by(no_reset);
   method DO           dout()           clocked_by(dclk) reset_by(no_reset);
   method DRDY         drdy()           clocked_by(dclk) reset_by(no_reset);
   method              dwe(DWE)         enable((*inhigh*)en6) clocked_by(dclk) reset_by(no_reset);

   schedule clkfbin C clkfbin;
   schedule locked CF locked;
   schedule (daddr, dsel, di, dout, drdy, dwe, rst) CF (daddr, dsel, di, dout, drdy, dwe, rst);

endmodule: vMMCME2_ADV

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////
import "BVI" MMCM_ADV =
module vMMCM_ADV#(MMCMParams params, Clock refclk)(VMMCM_ADV);
   default_clock dclk(DCLK);
   default_reset no_reset;

   input_clock clk1(CLKIN1) = refclk;

   parameter BANDWIDTH            = params.bandwidth;
   parameter CLKFBOUT_USE_FINE_PS = params.clkfbout_use_fine_ps;
   parameter CLKOUT0_USE_FINE_PS  = params.clkout0_use_fine_ps;
   parameter CLKOUT1_USE_FINE_PS  = params.clkout1_use_fine_ps;
   parameter CLKOUT2_USE_FINE_PS  = params.clkout2_use_fine_ps;
   parameter CLKOUT3_USE_FINE_PS  = params.clkout3_use_fine_ps;
   parameter CLKOUT4_CASCADE      = params.clkout4_cascade;
   parameter CLKOUT4_USE_FINE_PS  = params.clkout4_use_fine_ps;
   parameter CLKOUT5_USE_FINE_PS  = params.clkout5_use_fine_ps;
   parameter CLKOUT6_USE_FINE_PS  = params.clkout6_use_fine_ps;
   parameter COMPENSATION         = params.compensation;
   parameter STARTUP_WAIT         = params.startup_wait;
   parameter CLKFBOUT_MULT_F      = params.clkfbout_mult_f;
   parameter CLKFBOUT_PHASE       = params.clkfbout_phase;
   parameter CLKIN1_PERIOD        = params.clkin1_period;
   parameter CLKIN2_PERIOD        = params.clkin2_period;
   parameter DIVCLK_DIVIDE        = params.divclk_divide;
   parameter CLKOUT0_DIVIDE_F     = params.clkout0_divide_f;
   parameter CLKOUT0_DUTY_CYCLE   = params.clkout0_duty_cycle;
   parameter CLKOUT0_PHASE        = params.clkout0_phase;
   parameter CLKOUT1_DIVIDE       = params.clkout1_divide;
   parameter CLKOUT1_DUTY_CYCLE   = params.clkout1_duty_cycle;
   parameter CLKOUT1_PHASE        = params.clkout1_phase;
   parameter CLKOUT2_DIVIDE       = params.clkout2_divide;
   parameter CLKOUT2_DUTY_CYCLE   = params.clkout2_duty_cycle;
   parameter CLKOUT2_PHASE        = params.clkout2_phase;
   parameter CLKOUT3_DIVIDE       = params.clkout3_divide;
   parameter CLKOUT3_DUTY_CYCLE   = params.clkout3_duty_cycle;
   parameter CLKOUT3_PHASE        = params.clkout3_phase;
   parameter CLKOUT4_DIVIDE       = params.clkout4_divide;
   parameter CLKOUT4_DUTY_CYCLE   = params.clkout4_duty_cycle;
   parameter CLKOUT4_PHASE        = params.clkout4_phase;
   parameter CLKOUT5_DIVIDE       = params.clkout5_divide;
   parameter CLKOUT5_DUTY_CYCLE   = params.clkout5_duty_cycle;
   parameter CLKOUT5_PHASE        = params.clkout5_phase;
   parameter CLKOUT6_DIVIDE       = params.clkout6_divide;
   parameter CLKOUT6_DUTY_CYCLE   = params.clkout6_duty_cycle;
   parameter CLKOUT6_PHASE        = params.clkout6_phase;
   parameter REF_JITTER1          = params.ref_jitter1;
   parameter REF_JITTER2          = params.ref_jitter2;

   port      CLKIN2               = Bit#(1)'(0);
   port      CLKINSEL             = Bit#(1)'(1);
   port      PSCLK                = Bit#(1)'(0);
   port      PSEN                 = Bit#(1)'(0);
   port      PSINCDEC             = Bit#(1)'(0);
   port      PWRDWN               = Bit#(1)'(0);

   output_clock clkfbout(CLKFBOUT);
   output_clock clkfbout_n(CLKFBOUTB);
   output_clock clkout0(CLKOUT0);
   output_clock clkout0_n(CLKOUT0B);
   output_clock clkout1(CLKOUT1);
   output_clock clkout1_n(CLKOUT1B);
   output_clock clkout2(CLKOUT2);
   output_clock clkout2_n(CLKOUT2B);
   output_clock clkout3(CLKOUT3);
   output_clock clkout3_n(CLKOUT3B);
   output_clock clkout4(CLKOUT4);
   output_clock clkout5(CLKOUT5);
   output_clock clkout6(CLKOUT6);

   same_family(clk1, clkfbout);
   same_family(clk1, clkfbout_n);
   same_family(clk1, clkout0);
   same_family(clk1, clkout0_n);
   same_family(clk1, clkout1);
   same_family(clk1, clkout1_n);
   same_family(clk1, clkout2);
   same_family(clk1, clkout2_n);
   same_family(clk1, clkout3);
   same_family(clk1, clkout3_n);
   same_family(clk1, clkout4);
   same_family(clk1, clkout5);
   same_family(clk1, clkout6);

   method              clkfbin(CLKFBIN) enable((*inhigh*)en1) clocked_by(clkfbout) reset_by(no_reset);

   method LOCKED       locked()        clocked_by(no_clock) reset_by(no_reset);

   method              daddr(DADDR)     enable((*inhigh*)en2) clocked_by(dclk) reset_by(no_reset);
   method              dsel(DEN)         enable((*inhigh*)en3) clocked_by(dclk) reset_by(no_reset);
   method              di(DI)           enable((*inhigh*)en4) clocked_by(dclk) reset_by(no_reset);
   method              rst(RST)         enable((*inhigh*)en5) clocked_by(dclk) reset_by(no_reset);
   method DO           dout()           clocked_by(dclk) reset_by(no_reset);
   method DRDY         drdy()           clocked_by(dclk) reset_by(no_reset);
   method              dwe(DWE)         enable((*inhigh*)en6) clocked_by(dclk) reset_by(no_reset);

   schedule clkfbin C clkfbin;
   schedule locked CF locked;
   schedule (daddr, dsel, di, dout, drdy, dwe, rst) CF (daddr, dsel, di, dout, drdy, dwe, rst);

endmodule: vMMCM_ADV

endpackage: XilinxClocks

