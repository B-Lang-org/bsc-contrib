// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

import Clocks::*;
import Connectable::*;
import Counter::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;

import DDR2Types::*;
import ML507_mig_33_wrapper::*;

interface DDR2;
    interface DDR2Wires wires;
    interface DDR2Server server;
endinterface

typedef 8 MaxPendingReads;

typedef struct {
    Bit#(3) cmd;
    Bit#(31) addr;
} DDR2LLReqCmd deriving(Bits, Eq);

typedef struct {
    Bit#(128) data;
    Bit#(16) be;
} DDR2LLReqData deriving(Bits, Eq);

typedef struct {
    Maybe#(DDR2LLReqCmd) cmd;
    Maybe#(DDR2LLReqData) data;
} DDR2LLReq deriving(Bits, Eq);

// Implementation of DDR2Server interface using real DDR2 with burst length of
// 4.
// Burst length of 4 means you read and write 4 64 bit words for each command
// given. When you issue a write command, the write will happen only as soon
// as four 64 bit data words have been provided via the data interface.
// When you issue a read command, you will get four 64 words as a result.

// Synthesis deferred to the Bridge package, to allow this package to compile
// for Bluesim in system build:
//(* synthesize *)
module mkDDR2Burst4(
        Clock clk0,
        Clock clk90,
        Clock clkdiv0,
        Clock clk200,
        Reset sys_rst_n,
        (* clocked_by="no_clock", reset_by="no_reset" *) Bool locked,
    DDR2 ifc);

    FIFO#(DDR2ReqCmd) cmds <- mkFIFO();
    FIFO#(DDR2ReqData) wdata <- mkFIFO();

    Clock clk <- exposeCurrentClock();
    Reset rst <- exposeCurrentReset();
    Mig33 mig33 <- mkMig33Wrapper(clk0, clk90, clkdiv0, clk200, sys_rst_n, locked);

    Marshaller#(DDR2Data) marshaller <- mkMarshaller();
    Demarshaller#(DDR2ReqData) demarshaller <- mkDemarshaller();
    Reg#(Bool) wdataprepped <- mkReg(False);
    Counter#(TAdd#(TLog#(MaxPendingReads), 1)) readspending <- mkCounter(0);

   SyncFIFOIfc#(DDR2LLReq) syncReq <- mkSyncFIFO(2, clk, rst, mig33.clk0_tb);
   FIFOF#(DDR2LLReq)    syncReqFastFIFO <- mkLFIFOF( clocked_by mig33.clk0_tb, reset_by mig33.rst0_tb);

   rule moveToFast ;
      syncReqFastFIFO.enq(syncReq.first);
      syncReq.deq;
   endrule


    // syncRData holds read data from the memory. This buffer must be large
    // enough to hold data from all outstanding requests.
    SyncFIFOIfc#(Bit#(128)) syncRData <- mkSyncFIFO(valueof(MaxPendingReads), mig33.clk0_tb, mig33.rst0_tb, clk);

    // Pass along a read command.
    rule passread (cmds.first().rnw && readspending.value() <= (fromInteger(valueof(MaxPendingReads)) - 2) );
        // Address format is:
        //             1      2      13    10
        // [ unused | chip | bank | row | col ]
        $display("passread");
        syncReq.enq(DDR2LLReq {
            cmd: tagged Valid DDR2LLReqCmd {
                cmd: 3'b001,
                addr: truncate(cmds.first().addr) },
            data: tagged Invalid
        });
        // Each read command results in 2 pairs of 64 bit numbers returned
        readspending.inc(2);
        cmds.deq();
    endrule

    // Demarshall write data requests.
    mkConnection(toGet(wdata), demarshaller.single);

    // We need to have all the write data available before we send the write
    // command. But we can (I think) send write data ahead of time.
    // Each write command needs 4 64 bits words sent in 2 cycles.
    // Prep sends in the first 2 64 bit words.
    // We give this rule less urgency than passread because if they can both
    // go, we asked for the read before the writes. I suppose the better way
    // would be to do both at the same time, but I didn't want to add that
    // complexity to the code just yet.
    (* descending_urgency="passread, prepwritedata" *)
    rule prepwritedata(!wdataprepped);
        $display("prepwdata");
        wdataprepped <= True;
        match {.f, .s} <- demarshaller.double.get();

        syncReq.enq(DDR2LLReq {
            cmd: tagged Invalid,
            data: tagged Valid DDR2LLReqData {
                data: {s.data, f.data},
                be: {s.be, f.be}
            }
        });
    endrule

    // Pass along write requests
    rule passwrite (!cmds.first().rnw && wdataprepped);
        $display("passwrite");
        wdataprepped <= False;
        match {.f, .s} <- demarshaller.double.get();

        syncReq.enq(DDR2LLReq {
            cmd: tagged Valid DDR2LLReqCmd {
                cmd: 3'b000,
                addr: truncate(cmds.first().addr)
            },
            data: tagged Valid DDR2LLReqData {
                data: {s.data, f.data},
                be: {s.be, f.be}
            }
        });
        cmds.deq();
    endrule

    // Interface with the mig33
    rule apply (True);
        $display("apply");
        if (syncReqFastFIFO.first().cmd matches tagged Valid .cmd) begin
            mig33.app.af(cmd.cmd, cmd.addr);
        end

        if (syncReqFastFIFO.first().data matches tagged Valid .data) begin
            // The mig interface data mask bits should be 0 to enable writing
            // and 1 to disable writing. This is opposite of what I think
            // makes sense, and the DDR2 Interface I've created, which says
            // byte enable of 1 enables the byte and 0 disables the byte.
            // So we inverte byte enable here.
            mig33.app.wdf(data.data, ~data.be);
        end
        syncReqFastFIFO.deq();
    endrule

    // Take read requests. We should always have enough space in syncRData,
    // otherwise this code is buggy.
    rule takeread (True);
        $display("takeread");
        syncRData.enq(mig33.app.data());
    endrule

    // Pass read data to marshaller.
    rule marshallread (True);
        // According to ug086, the two words coming back are arranged as
        // M1M0
        // Which, I assume, means M1 has the most significant bits.
        // Our marshaller assumes the first element of the tuple is M0 and the
        // second element M1, so the first element gets the least significant
        // bits.
        $display("marshallread");
        Bit#(128) data <- toGet(syncRData).get();
        marshaller.double.put(tuple2(data[63:0], data[127:64]));
        readspending.down();
    endrule

    interface DDR2Wires wires = mig33.ddr2;

    interface DDR2Server server;
        interface DDR2RequestServer request;
            interface Put command = toPut(cmds);
            interface Put data = toPut(wdata);
        endinterface

        interface Get response = marshaller.single;
    endinterface

endmodule

interface Demarshaller#(type a);
    interface Put#(a) single;
    interface Get#(Tuple2#(a,a)) double;
endinterface

module mkDemarshaller(Demarshaller#(a))
   provisos (Bits#(a,_sa));

    FIFO#(a) incoming <- mkFIFO();
    FIFO#(Tuple2#(a,a)) outgoing <- mkFIFO();

    Reg#(Maybe#(a)) waiting <- mkReg(Invalid);

    rule prep(!isValid(waiting));
        waiting <= tagged Valid incoming.first();
        incoming.deq();
    endrule

    rule send(waiting matches tagged Valid .f);
        outgoing.enq(tuple2(f, incoming.first()));
        incoming.deq();
        waiting <= tagged Invalid;
    endrule

    interface Put single = toPut(incoming);
    interface Get double = toGet(outgoing);

endmodule

interface Marshaller#(type a);
    interface Put#(Tuple2#(a,a)) double;
    interface Get#(a) single;
endinterface

module mkMarshaller(Marshaller#(a))
   provisos (Bits#(a,_sa));

    FIFO#(Tuple2#(a,a)) incoming <- mkFIFO();
    FIFO#(a) outgoing <- mkFIFO();

    Reg#(Maybe#(a)) waiting <- mkReg(Invalid);

    rule first (!isValid(waiting));
        match {.f, .s} = incoming.first();
        incoming.deq();

        outgoing.enq(f);
        waiting <= tagged Valid s;
    endrule

    rule second (waiting matches tagged Valid .x);
        outgoing.enq(x);
        waiting <= tagged Invalid;
    endrule

    interface Put double = toPut(incoming);
    interface Get single = toGet(outgoing);

endmodule

