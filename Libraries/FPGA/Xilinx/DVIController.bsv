////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : DVIController.bsv
//  Description   :
////////////////////////////////////////////////////////////////////////////////
package DVIController;

// Notes :
//  - The pixel clock is provided as an argument to the DVI controller interface
//    specified in MHz.  This clock is assumed to be the clock driving the
//    mkDVIController module.  Pixels are provided to the DVI_User interface one
//    at a time.

// NET    "DVI_data[0]"                                       LOC = AJ19 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_data[1]"                                       LOC = AH19 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_data[2]"                                       LOC = AM17 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_data[3]"                                       LOC = AM16 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_data[4]"                                       LOC = AD17 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_data[5]"                                       LOC = AE17 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_data[6]"                                       LOC = AK18 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_data[7]"                                       LOC = AK17 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_data[8]"                                       LOC = AE18 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_data[9]"                                       LOC = AF18 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_data[10]"                                      LOC = AL16 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_data[11]"                                      LOC = AK16 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_de"                                            LOC = AD16 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_hsync_n"                                       LOC = AN17 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "RST_N_DVI_rst_n"                                   LOC = AP17 | IOSTANDARD = LVCMOS25 ;
// NET    "DVI_vsync_n"                                       LOC = AD15 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "CLK_DVI_xclk_p"                                    LOC = AC18 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "CLK_DVI_xclk_n"                                    LOC = AC17 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 8;
// NET    "DVI_I2C_sda"                                       LOC = AP10 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 24 | PULLUP | TIG;
// NET    "DVI_I2C_scl"                                       LOC = AN10 | IOSTANDARD = LVCMOS25 | SLEW = FAST | DRIVE = 24 | PULLUP | TIG;

// NET "CLK_DVI_pclk_p*" TNM_NET = FFS pclk_p_flops;
// NET "CLK_DVI_pclk_n*" TNM_NET = FFS pclk_n_flops;

// TIMESPEC TS_sync_pclk_p2n = FROM pclk_p_flops TO pclk_n_flops TIG;
// TIMESPEC TS_sync_pclk_n2p = FROM pclk_n_flops TO pclk_p_flops TIG;


////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import GetPut            ::*;
import ClientServer      ::*;
import BRAM              ::*;
import Vector            ::*;
import Clocks            ::*;
import StmtFSM           ::*;
import FIFO              ::*;
import FIFOF             ::*;
import SpecialFIFOs      ::*;
import Counter           ::*;
import I2C               ::*;
import DefaultValue      ::*;
import DummyDriver       ::*;
import Video             ::*;

import XilinxCells       ::*;

////////////////////////////////////////////////////////////////////////////////
/// Types
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
(* always_enabled, always_ready *)
interface DVI_Pins;
   interface Reset       rst_n;
   interface Clock       xclk_p;
   interface Clock       xclk_n;
   method    Bool        hsync_n;
   method    Bool        vsync_n;
   method    Bool        de;
   method    Bit#(12)    data;
   interface Clock       pclk_p;
   interface Clock       pclk_n;
endinterface

interface DVI_User;
   interface Put#(RGB888)   pixel;
   method    Bool           hsync_n;
   method    Bool           vsync_n;
endinterface

interface DVIController#(numeric type clockMHz);
   (* prefix = "" *)
   interface DVI_User user;
   (* prefix = "" *)
   interface DVI_Pins dvi;
   interface Client#(I2CRequest, I2CResponse) i2c;
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation of DVI Controller
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkDVIController#(VideoTiming timing)(DVIController#(clockMHz));

   let clockrate     = valueof(clockMHz);
   Bool greater65MHz = (clockrate > 65);

   Bit#(8) reg33h    = (greater65MHz) ? 'h06 : 'h08;
   Bit#(8) reg34h    = (greater65MHz) ? 'h26 : 'h16;
   Bit#(8) reg36h    = (greater65MHz) ? 'hA0 : 'h60;

   ////////////////////////////////////////////////////////////////////////////////
   /// Clocks & Reset
   ////////////////////////////////////////////////////////////////////////////////
   Clock                           clk                 <- exposeCurrentClock;
   Reset                           rstN                <- exposeCurrentReset;
   Clock                           clkN                <- invertCurrentClock;
   Reset                           rstN_delayed        <- mkAsyncReset( 100, rstN, clkN );

   Clock                           xClkP               <- mkClockODDR(defaultValue, 1, 0);
   Clock                           xClkN               <- mkClockODDR(defaultValue, 0, 1);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Reg#(Bool)                      rInitialized        <- mkReg(False);
   SyncGenerator                   mHSyncGen           <- mkSyncGenerator(timing.h);
   SyncGenerator                   mVSyncGen           <- mkSyncGenerator(timing.v);

   FIFO#(I2CRequest)               fI2CRequest         <- mkFIFO;
   FIFO#(I2CResponse)              fI2CResponse        <- mkFIFO;

   ODDR#(Bit#(12))                 rDataOut            <- mkODDR(defaultValue);

   ReadOnly#(Bool)                 wHSyncN_clkN        <- mkNullCrossingWire(clkN, mHSyncGen.out_n);
   ReadOnly#(Bool)                 wVSyncN_clkN        <- mkNullCrossingWire(clkN, mVSyncGen.out_n);
   ReadOnly#(Bool)                 wHDE_clkN           <- mkNullCrossingWire(clkN, mHSyncGen.active);
   ReadOnly#(Bool)                 wVDE_clkN           <- mkNullCrossingWire(clkN, mVSyncGen.active);

   Reg#(Bool)                      rHSyncN             <- mkReg(True, clocked_by clkN, reset_by rstN_delayed);
   Reg#(Bool)                      rVSyncN             <- mkReg(True, clocked_by clkN, reset_by rstN_delayed);
   Reg#(Bool)                      rActive             <- mkReg(False, clocked_by clkN, reset_by rstN_delayed);

   FIFO#(RGB888)                   fPixelData          <- mkLSizedFIFO(4);
   Wire#(RGB888)                   wPixelData          <- mkDWire(unpack(0));

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   Stmt init_dvi =
   seq
      fI2CRequest.enq(I2CRequest { write: True, slaveaddr: 'h76, address: 'h49, data: 'hC0 });
      fI2CRequest.enq(I2CRequest { write: True, slaveaddr: 'h76, address: 'h21, data: 'h09 });
      fI2CRequest.enq(I2CRequest { write: True, slaveaddr: 'h76, address: 'h33, data: reg33h });
      fI2CRequest.enq(I2CRequest { write: True, slaveaddr: 'h76, address: 'h34, data: reg34h });
      fI2CRequest.enq(I2CRequest { write: True, slaveaddr: 'h76, address: 'h36, data: reg36h });
      rInitialized <= True;
   endseq;

   FSM                             fsmInitDVI          <- mkFSM(init_dvi);

   rule initialize_dvi(!rInitialized && fsmInitDVI.done);
      fsmInitDVI.start;
   endrule

   (* no_implicit_conditions, fire_when_enabled *)
   rule connect_hsync_gen;
      mHSyncGen.tick();
   endrule

   (* no_implicit_conditions, fire_when_enabled *)
   rule connect_vsync_gen(mHSyncGen.preedge);
      mVSyncGen.tick();
   endrule

   (* no_implicit_conditions, fire_when_enabled *)
   rule connect_sync_generator_outputs;
      rHSyncN <= wHSyncN_clkN;
      rVSyncN <= wVSyncN_clkN;
      rActive <= wHDE_clkN && wVDE_clkN;
   endrule

   (* no_implicit_conditions, fire_when_enabled *)
   rule connect_data_out;
      rDataOut.ce(True);
      rDataOut.s(False);
   endrule

   rule get_next_pixel(mHSyncGen.active && mVSyncGen.active);
      let data = fPixelData.first; fPixelData.deq;
      wPixelData <= data;
   endrule

   (* no_implicit_conditions, fire_when_enabled *)
   rule connect_pixel_out_to_data_out;
      let { hi, lo } = split(pack(wPixelData));
      rDataOut.d1(hi);
      rDataOut.d2(lo);
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface DVI_User user;
      interface pixel    = toPut(fPixelData);
      method    hsync_n  = mHSyncGen.out_n;
      method    vsync_n  = mVSyncGen.out_n;
   endinterface

   interface DVI_Pins dvi;
      interface rst_n    = rstN_delayed;
      interface xclk_p   = xClkP;
      interface xclk_n   = xClkN;
      method    hsync_n  = rHSyncN;
      method    vsync_n  = rVSyncN;
      method    de       = rActive;
      method    data     = rDataOut.q;
      interface pclk_p   = clk;
      interface pclk_n   = clkN;
   endinterface

   interface Client i2c;
      interface request  = toGet(fI2CRequest);
      interface response = toPut(fI2CResponse);
   endinterface
endmodule

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Stubs for DVI Controller
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
instance DummyDriver#(DVI_User);
   module mkStub(DVI_User ifc);
      interface Put pixel;
	 method Action put(RGB888 x) if (False);
	    noAction;
	 endmethod
      endinterface
      method Bool hsync_n = True;
      method Bool vsync_n = True;
   endmodule
endinstance

instance DummyDriver#(DVI_Pins);
   module mkStub(DVI_Pins ifc);
      interface Reset    rst_n   = noReset;
      interface Clock    xclk_p  = primMakeDisabledClock;
      interface Clock    xclk_n  = primMakeDisabledClock;
      method 	Bool     hsync_n = True;
      method 	Bool     vsync_n = True;
      method 	Bool     de      = False;
      method 	Bit#(12) data    = 0;
      interface Clock    pclk_p  = primMakeDisabledClock;
      interface Clock    pclk_n  = primMakeDisabledClock;
   endmodule
endinstance

endpackage: DVIController

