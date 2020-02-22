// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

import GetPut::*;
import FIFO::*;

import DDR2Types::*;


// Module adapts a non-bursting DDR2Client to a 4-burst DRR2Client.
// Non-bursting means for each command there is one 64 bit data word read or
// written. 4-burst means for each command there are four 64 bit data words
// read or written.
module mkDDR2FakeBurst#(DDR2Client nb) (DDR2Client);

    FIFO#(DDR2ReqData) wdata <- mkFIFO();
    FIFO#(DDR2Data) rdata <- mkFIFO();

    Reg#(Bit#(2)) wcount <- mkReg(0);
    Reg#(Bit#(2)) rcount <- mkReg(0);

    rule write (True);
        if (wcount == 0) begin
            let x <- nb.request.data.get();
            wdata.enq(x);
        end else begin
            wdata.enq(DDR2ReqData { data: ?, be: 8'h00 });
        end
        wcount <= wcount+1;
    endrule

    rule read (True);
        if (rcount == 0) begin
            nb.response.put(rdata.first());
        end
        rcount <= rcount+1;
        rdata.deq();
    endrule

    interface DDR2RequestClient request;
        interface Get command = nb.request.command;
        interface Get data = toGet(wdata);
    endinterface

    interface Put response = toPut(rdata);

endmodule

