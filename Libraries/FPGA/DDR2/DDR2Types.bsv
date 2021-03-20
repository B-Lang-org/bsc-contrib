// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

import Clocks::*;
import Connectable::*;
import GetPut::*;

typedef Bit#(32) DDR2Address;
typedef Bit#(64) DDR2Data;

// DDR2ReqCmd
// A request command.
// You specify read or write and a memory address.
// For write requests, the data to be written is supplied separately.
typedef struct {
    Bool rnw;
    DDR2Address addr;
} DDR2ReqCmd deriving(Bits, Eq);

// Write request data.
// The data to write to memory when you've sent a write request command.
// be - byte enable, it specifies which bytes to in the data should be
//      written.
// data - The data to write.
typedef struct {
    Bit#(8) be;
    DDR2Data data;
} DDR2ReqData deriving(Bits, Eq);


// DDR2Client interface.
// For reads the server will take the request command and put the data read
// some number of cycles later.
// For writes the server will take the request command and the request data.
// No response is given to writes.
interface DDR2RequestClient;
    interface Get#(DDR2ReqCmd) command;
    interface Get#(DDR2ReqData) data;
endinterface

interface DDR2Client;
    interface DDR2RequestClient request;
    interface Put#(DDR2Data) response;
endinterface

interface DDR2RequestServer;
    interface Put#(DDR2ReqCmd) command;
    interface Put#(DDR2ReqData) data;
endinterface

interface DDR2Server;
    interface DDR2RequestServer request;
    interface Get#(DDR2Data) response;
endinterface

instance Connectable#(DDR2RequestClient, DDR2RequestServer);
    module mkConnection#(DDR2RequestClient client, DDR2RequestServer server)(Empty);
        mkConnection(client.command, server.command);
        mkConnection(client.data, server.data);
    endmodule
endinstance

instance Connectable#(DDR2RequestServer, DDR2RequestClient);
    module mkConnection#(DDR2RequestServer server, DDR2RequestClient client)(Empty);
        mkConnection(client, server);
    endmodule
endinstance

instance Connectable#(DDR2Client, DDR2Server);
    module mkConnection#(DDR2Client client, DDR2Server server)(Empty);
        mkConnection(client.request, server.request);
        mkConnection(client.response, server.response);
    endmodule
endinstance

instance Connectable#(DDR2Server, DDR2Client);
    module mkConnection#(DDR2Server server, DDR2Client client)(Empty);
        mkConnection(client, server);
    endmodule
endinstance

// Brings a DDR2Client from one clock domain to another.
module mkDDR2ClientSync#(DDR2Client ddr2,
    Clock sclk, Reset srst, Clock dclk, Reset drst
    ) (DDR2Client);

    SyncFIFOIfc#(DDR2ReqCmd) cmds <- mkSyncFIFO(2, sclk, srst, dclk);
    SyncFIFOIfc#(DDR2ReqData) wdata <- mkSyncFIFO(2, sclk, srst, dclk);
    SyncFIFOIfc#(DDR2Data) rdata <- mkSyncFIFO(2, dclk, drst, sclk);

    mkConnection(toPut(cmds), toGet(ddr2.request.command));
    mkConnection(toPut(wdata), toGet(ddr2.request.data));
    mkConnection(toGet(rdata), toPut(ddr2.response));

    interface DDR2RequestClient request;
        interface Get command = toGet(cmds);
        interface Get data = toGet(wdata);
    endinterface

    interface Put response = toPut(rdata);
endmodule


interface SimpleMemory;
   method Action request ( Bool write, UInt#(31) addr, Bit#(256) data, Bit#(32) be);
   interface Get#(Bit#(256)) readData;
endinterface




