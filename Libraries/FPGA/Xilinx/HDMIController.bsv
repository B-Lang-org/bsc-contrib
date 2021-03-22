////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : HDMIController.bsv
//  Description   :
////////////////////////////////////////////////////////////////////////////////
package HDMIController;

// Notes :
// HDMI_D[0]      B23
// HDMI_D[1]      A23
// HDMI_D[2]      E23
// HDMI_D[3]      D23
// HDMI_D[4]      F25
// HDMI_D[5]      E25
// HDMI_D[6]      E24
// HDMI_D[7]      D24
// HDMI_D[8]      F26
// HDMI_D[9]      E26
// HDMI_D[10]     G23
// HDMI_D[11]     G24
// HDMI_D[12]     J19
// HDMI_D[13]     H19
// HDMI_D[14]     L17
// HDMI_D[15]     L18
// HDMI_D[16]     K19
// HDMI_D[17]     K20
// HDMI_DE        H17
// HDMI_SPDIF     J17
// HDMI_CLK       K18
// HDMI_VSYNC     H20
// HDMI_HSYNC     J18
// HDMI_INT       AH24
// HDMI_SPDIF_OUT G20


////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import Clocks            ::*;
import I2C               ::*;
import StmtFSM           ::*;
import Video             ::*;
import DefaultValue      ::*;
import GetPut            ::*;
import ClientServer      ::*;
import FIFO              ::*;

import XilinxCells       ::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// Types
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String           xilinxBoard;
   VideoTiming      timing;
   Clock            userClock;
   Reset            userReset;
} HDMIParams;

instance DefaultValue#(HDMIParams);
   defaultValue = HDMIParams {
      xilinxBoard:       "UNKNOWN",
      timing:            ?,
      userClock:         primMakeDisabledClock,
      userReset:         noReset
      };
endinstance

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
(* always_enabled, always_ready *)
interface HDMI_Pins;
   interface Clock        clk;
   method    Bit#(18)     data();
   method    Bit#(1)      de();
   method    Bit#(1)      hsync();
   method    Bit#(1)      vsync();
   method    Bit#(1)      spdif();
   method    Action       interrupt(Bit#(1) i);
   method    Action       spdif_in(Bit#(1) i);
endinterface

interface HDMIController;
   (* prefix = "" *)
   interface HDMI_Pins hdmi;
   interface Client#(I2CRequest, I2CResponse) i2c;
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkHDMIController#(HDMIParams params)(HDMIController);

   ////////////////////////////////////////////////////////////////////////////////
   /// Clocks & Resets
   ////////////////////////////////////////////////////////////////////////////////
   Clock                           pixelClock          <- exposeCurrentClock;

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Reg#(Bool)                      rInitialized        <- mkReg(False);
   Reg#(Bit#(8))                   rTemp               <- mkReg(0);
   SyncGenerator                   mHSyncGen           <- mkSyncGenerator(params.timing.h);
   SyncGenerator                   mVSyncGen           <- mkSyncGenerator(params.timing.v);

   Reg#(Bit#(1))                   rInterrupt          <- mkReg(0);
   Reg#(Bit#(18))                  rDataOut            <- mkReg(18'h06480);

   FIFO#(I2CRequest)               fI2CRequest         <- mkFIFO;
   FIFO#(I2CResponse)              fI2CResponse        <- mkFIFO;

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   Stmt init_hdmi =
   seq
      // KC705, VC707, and possibly others/futures require initialization of an I2C bus
      // switch before the HDMI controller can be accessed via I2C.

      // enable the HDMI switch position only
      fI2CRequest.enq(I2CRequest { write: True, slaveaddr: 'h74, address: 'h20, data: 'h20 });

      // Wait for HPD
      while ((rTemp & 'h80) != 'h80) seq
	 fI2CRequest.enq(I2CRequest { write: False, slaveaddr: 'h39, address: 'h96, data: 'h00 });
	 action
	    let response <- toGet(fI2CResponse).get;
	    rTemp <= pack(response);
	 endaction
      endseq

      // Monitor/Device connected...  Program the controller now!

      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h01, data: 'h00 }); // 20-bit N used with CTS to regenerate the audio
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h02, data: 'h18 }); // clock in the receiver.
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h03, data: 'h00 });

      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h15, data: 'h01 }); // I2S sampling frequency (do not use)
                                                                                            // InputID 16,20,24 bit YCbCr 4:2:2 (separate syncs)

      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h16, data: 'hB5 }); // Output Format: 4:2:2
                                                 					    // Color Depth for Input Video (8-bit)
                                                 					    // Style-2 input pin assignments
                                                 					    // Output Colorspace for Black image/Range Clipping (YCbCr)

      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h18, data: 'h46 }); // CSC Enable (Disabled)
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h40, data: 'h80 }); // GC Packet Enable (Enabled)
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h41, data: 'h10 }); // Powered Up, No Sync Adjustment.
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h48, data: 'h08 }); // Bit Justification (right justified)
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h49, data: 'hA8 }); // Bit Trimming Mode (Truncate)
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h4C, data: 'h00 }); // Pixel Packing (GC Packet) Color Depth (none indicated)
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h55, data: 'h20 }); // Y1Y0 = YCbCr 4:2:2
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h56, data: 'h08 }); // Active Format Aspect Ratio (Same as Aspect Ratio)
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h96, data: 'h20 }); // VSync Interrupt (interrupt detected)
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h98, data: 'h03 }); // Required to be 0x03
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h99, data: 'h02 }); // Required to be 0x02
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h9a, data: 'he0 }); // Required to be 0xe0
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h9c, data: 'h30 }); // Required to be 0x30
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h9d, data: 'h61 }); // Required to be 0x61 (Input clock not divided)
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'ha2, data: 'ha4 }); // Required to be 0xa4
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'ha3, data: 'ha4 }); // Required to be 0xa4
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'ha5, data: 'h44 }); // Required to be 0x44*
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'hab, data: 'h40 }); // Required to be 0x40
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'haf, data: 'h06 }); // HDCP Disabled, No Frame Encryption, HDMI mode
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'hba, data: 'h00 }); // No Clock Delay/external eeprom/don't show AKSV/HDCP Ri standard
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'hd0, data: 'h3c }); // No DDR Neg-Edge Delay/No Sync Pulse generation
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'hd1, data: 'hff }); // Required to be 0xFF
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'hde, data: 'h9c }); // ???
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'he0, data: 'hd0 }); // Required to be 0XD0
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'he4, data: 'h60 }); // Required to be 0x60
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'hf9, data: 'h00 }); // I2C address (not sure why set to 0x00)
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'hfa, data: 'h00 }); // HSync placement/adjustment (none)
      fI2CRequest.enq(I2CRequest{ write: True, slaveaddr: 'h39, address: 'h17, data: 'h02 }); // VSync=High Polarity/HSync=High Polarity/16:9 aspect ratio/No DE generation
/*
      fI2CRequest.enq(I2CRequest{ write: False, slaveaddr: 'h39, address: 'h42, data: 'h01 });
      fI2CRequest.enq(I2CRequest{ write: False, slaveaddr: 'h39, address: 'hc8, data: 'h01 });
      fI2CRequest.enq(I2CRequest{ write: False, slaveaddr: 'h39, address: 'h9e, data: 'h01 });
      fI2CRequest.enq(I2CRequest{ write: False, slaveaddr: 'h39, address: 'h96, data: 'h01 });
      fI2CRequest.enq(I2CRequest{ write: False, slaveaddr: 'h39, address: 'h3e, data: 'h01 });
      fI2CRequest.enq(I2CRequest{ write: False, slaveaddr: 'h39, address: 'h3d, data: 'h01 });
      fI2CRequest.enq(I2CRequest{ write: False, slaveaddr: 'h39, address: 'h3c, data: 'h01 });
*/
      rInitialized <= True;
   endseq;

   FSM                                       fsmInitHDMI    <- mkFSM(init_hdmi);

   rule initialize_hdmi(!rInitialized && fsmInitHDMI.done);
      fsmInitHDMI.start;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface HDMI_Pins hdmi;
      interface clk          = pixelClock;
      method    data         = rDataOut;
      method    de           = pack(mHSyncGen.active() && mVSyncGen.active());
      method    hsync        = pack(mHSyncGen.out());
      method    vsync        = pack(mVSyncGen.out());
      method    spdif        = 0;
      method    interrupt(x) = rInterrupt._write(x);
      method    spdif_in(x)  = noAction;
   endinterface

   interface Client i2c;
      interface request  = toGet(fI2CRequest);
      interface response = toPut(fI2CResponse);
   endinterface

endmodule: mkHDMIController

endpackage: HDMIController

