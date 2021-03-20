////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : GPIOController.bsv
//  Description   :
////////////////////////////////////////////////////////////////////////////////
package GPIOController;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import Clocks            ::*;
import TriState          ::*;
import Vector            ::*;
import DummyDriver       ::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////
export GPIO(..), GPIOController(..), mkGPIOController;
export getGPIO, gpioToInout, inoutToGPIO;

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
// This is the interface that connects external to the FPGA
interface GPIO;
   interface Inout#(Bit#(1))   gpio;
endinterface

// This is the main controller interface
interface GPIOController;
   // Set the value of the GPIO signal
   (* always_ready *)
   method Action _write(Bit#(1) i);
   // Specify drive direction of the GPIO signal
   // 0 - input
   // 1 - output
   (* always_ready *)
   method Action drive_out(Bool i);
   // Read the drive direction of the GPIO signal
   // 0 - input
   // 1 - output
   (* always_ready *)
   method Bool read_drive_out();
   // Return the current status of the GPIO signal
   (* always_ready *)
   method Bit#(1) _read();
   // The interface for connecting to the FPGA pin
   (* prefix = "" *)
   interface GPIO ifc;
endinterface: GPIOController

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation of GPIO controller
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkGPIOController#(parameter Bool bInitOutEn)(GPIOController);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Reg#(Bit#(1))        rDataOut     <- mkReg(0);
   Reg#(Bool)           rOutEn       <- mkReg(bInitOutEn);
   Reg#(Bit#(1))        rDataIn      <- mkRegU;

   TriState#(Bit#(1))   tGPIO        <- mkTriState(rOutEn, rDataOut);

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* fire_when_enabled, no_implicit_conditions *)
   rule update_input_register;
      rDataIn <= tGPIO;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   method Action _write(Bit#(1) i);
      rDataOut <= i;
   endmethod

   method Action drive_out(Bool i);
      rOutEn <= i;
   endmethod

   method Bool read_drive_out();
      return rOutEn;
   endmethod

   method Bit#(1) _read();
      return rDataIn;
   endmethod

   interface GPIO ifc;
      interface gpio = tGPIO.io;
   endinterface

endmodule: mkGPIOController

// A utility function to get the inout interface from the GPIO controller
function GPIO getGPIO(GPIOController ctrl);
   return ctrl.ifc;
endfunction: getGPIO

// A utility function to get the inout interface from the GPIO controller
function Inout#(Bit#(1)) gpioToInout(GPIO gpio);
   return gpio.gpio;
endfunction: gpioToInout

// A utility function to create a GPIO interface from Inouts
function GPIO inoutToGPIO(Inout#(Bit#(1)) ifc);
   return (interface GPIO;
	      interface gpio = ifc;
	   endinterface);
endfunction: inoutToGPIO

instance DummyDriver#(GPIO);
   module mkStub(GPIO ifc);

      TriState#(Bit#(1)) t <- mkTriState(False, 0);
      interface gpio = t.io;
   endmodule
endinstance

endpackage: GPIOController

