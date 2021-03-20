////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : Si570Controller.bsv
//  Description   :
////////////////////////////////////////////////////////////////////////////////
package Si570Controller;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import DefaultValue      ::*;
import FIFO              ::*;
import StmtFSM           ::*;
import GetPut            ::*;

import I2C               ::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
/// Types
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   Bool        rnw;
   Bit#(38)    rfreq;
   Bit#(3)     hsdiv;
   Bit#(7)     n1;
} Si570Request deriving (Bits, Eq);

typedef struct {
   Bit#(38)    rfreq;
   Bit#(3)     hsdiv;
   Bit#(7)     n1;
} Si570Response deriving (Bits, Eq);


////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
interface Si570Controller;
   method

   method    Action                      requestValues();
   method    ActionValue#(Si570Params)   getValues();
   method    Action                      setValues(Si570Params x);
   (* prefix = "" *)
   interface I2C_Pins                    i2c;
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkSi570Controller(Si570Controller);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   I2C                        mI2C           <- mkI2C(1024);

   Reg#(Bit#(3))              rHSDIV         <- mkReg(0);
   Reg#(Bit#(7))              rN1            <- mkReg(0);
   Reg#(Bit#(38))             rRFREQ         <- mkReg(0);

   FIFO#(Si570Params)         fResponse      <- mkFIFO;
   FIFO#(Si570Params)         fWrRequest     <- mkFIFO;

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   Stmt read_si570 =
   seq
      // enable I2C communication with the Si570
      mI2C.user.short_request(True, 'h74, 'h01);

      // read out the current values
      mI2C.user.request(False, 'h5D, 7, 'h00);
      action
	 let response <- mI2C.user.response();
	 rHSDIV <= response[7:5];
	 rN1    <= { response[4:0], 2'd0 };
      endaction

      mI2C.user.request(False, 'h5D, 8, 'h00);
      action
	 let response <- mI2C.user.response();
	 rN1    <= { rN1[6:2], response[7:6] };
	 rRFREQ <= { response[5:0], 32'd0 };
      endaction

      mI2C.user.request(False, 'h5D, 9, 'h00);
      action
	 let response <- mI2C.user.response();
	 rRFREQ <= { rRFREQ[37:32], response[7:0], 24'd0 };
      endaction

      mI2C.user.request(False, 'h5D, 10, 'h00);
      action
	 let response <- mI2C.user.response();
	 rRFREQ <= { rRFREQ[37:24], response[7:0], 16'd0 };
      endaction

      mI2C.user.request(False, 'h5D, 11, 'h00);
      action
	 let response <- mI2C.user.response();
	 rRFREQ <= { rRFREQ[37:16], response[7:0], 8'd0 };
      endaction

      mI2C.user.request(False, 'h5D, 12, 'h00);
      action
	 let response <- mI2C.user.response();
	 rRFREQ <= { rRFREQ[37:8], response[7:0] };
      endaction

      fResponse.enq(Si570Params { rfreq: rRFREQ, hsdiv: rHSDIV, n1: rN1 });
   endseq;

   Stmt write_si570 =
   seq
      action
	 let request <- toGet(fWrRequest).get;
	 rRFREQ <= request.rfreq;
	 rHSDIV <= request.hsdiv;
	 rN1    <= request.n1;
      endaction

      // enable I2C communication with the Si570
      mI2C.user.short_request(True, 'h74, 'h01);

      // update
      mI2C.user.request(True, 'h5D, 137, 'h80);
      mI2C.user.request(True, 'h5D,  7, { rHSDIV[2:0], rN1[6:2] });
      mI2C.user.request(True, 'h5D,  8, { rN1[1:0], rRFREQ[37:32] });
      mI2C.user.request(True, 'h5D,  9, rRFREQ[31:24] );
      mI2C.user.request(True, 'h5D, 10, rRFREQ[23:16] );
      mI2C.user.request(True, 'h5D, 11, rRFREQ[15:8] );
      mI2C.user.request(True, 'h5D, 12, rRFREQ[7:0] );
      mI2C.user.request(True, 'h5D, 137, 'h00);
      mI2C.user.request(True, 'h5D, 135, 'h40);
   endseq;

   FSM                        fsmRead             <- mkFSM(read_si570);
   FSM                        fsmWrite            <- mkFSMWithPred(write_si570, fsmRead.done);

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   method Action requestValues() if (fsmRead.done);
      fsmRead.start();
   endmethod

   method ActionValue#(Si570Params) getValues() if (fsmRead.done);
      fResponse.deq;
      return fResponse.first;
   endmethod

   method Action setValues(Si570Params x) if (fsmWrite.done);
      fWrRequest.enq(x);
      fsmWrite.start();
   endmethod

   interface i2c = mI2C.i2c;

endmodule



endpackage: Si570Controller

