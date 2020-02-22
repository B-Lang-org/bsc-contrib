// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

// DDR2 Wires
(* always_ready, always_enabled *)
interface DDR2Wires;
    interface Inout#(Bit#(64)) dq;
    method Bit#(13) a;
    method Bit#(2) ba;
    method Bit#(1) ras_n;
    method Bit#(1) cas_n;
    method Bit#(1) we_n;
    method Bit#(1) cs_n;
    method Bit#(1) odt;
    method Bit#(1) cke;
    method Bit#(8) dm;
    interface Inout#(Bit#(8)) dqs;
    interface Inout#(Bit#(8)) dqs_n;
    method Bit#(2) ck;
    method Bit#(2) ck_n;
endinterface

// Mig33 application interface.
interface Mig33App;
    // Request a read or write.
    // cmd: 3'b000 - write
    //      3'b001 - read
    // addr: - Address
    method Action af(Bit#(3) cmd, Bit#(31) addr);

    // Data to use for writes.
    // Takes two 64 bit words and 2 8 bit masks which select which bytes to
    // update.
    method Action wdf(Bit#(128) data, Bit#(16) mask);

    // Read data.
    // This is not buffered, so if there is data ready, you better grab it
    // that cycle, otherwise the data will be lost.
    method Bit#(128) data();
endinterface

interface Mig33;
    interface Clock clk0_tb;
    interface Reset rst0_tb;
    interface DDR2Wires ddr2;
    interface Mig33App app;
endinterface

import "BVI" mig_33_wrapper =
module mkMig33Wrapper#(
        Clock clk0,
        Clock clk90,
        Clock clkdiv0,
        Clock clk200,
        Reset sys_rst_n,
        Bool locked
    ) (Mig33);

    default_clock no_clock;
    default_reset no_reset;

    input_clock (clk0, (*inhigh*)g1) = clk0;
    input_clock (clk90, (*inhigh*)g1) = clk90;
    input_clock (clkdiv0, (*inhigh*)g1) = clkdiv0;
    input_clock (clk200, (*inhigh*)g1) = clk200;
    input_reset sys_rst_n(sys_rst_n) = sys_rst_n;

    port locked = locked;

    output_clock clk0_tb(clk0_tb);
    output_reset rst0_tb(rst0_tb_n) clocked_by (clk0_tb);

    interface DDR2Wires ddr2;
        ifc_inout dq(ddr2_dq);
        method ddr2_a       a;
        method ddr2_ba      ba;
        method ddr2_ras_n   ras_n;
        method ddr2_cas_n   cas_n;
        method ddr2_we_n    we_n;
        method ddr2_cs_n    cs_n;
        method ddr2_odt     odt;
        method ddr2_cke     cke;
        method ddr2_dm      dm;
        ifc_inout dqs(ddr2_dqs);
        ifc_inout dqs_n(ddr2_dqs_n);
        method ddr2_ck      ck;
        method ddr2_ck_n    ck_n;
    endinterface

    interface Mig33App app;
        method af(app_af_cmd, app_af_addr)
            enable(app_af_enable)
            ready(app_af_ready)
            clocked_by(clk0_tb)
            reset_by(rst0_tb);

        method wdf(app_wdf_data, app_wdf_mask_data)
            enable(app_wdf_enable)
            ready(app_wdf_ready)
            clocked_by(clk0_tb)
            reset_by(rst0_tb);

        method rd_data_out data
            ready(rd_data_ready)
            clocked_by(clk0_tb)
            reset_by(rst0_tb);

    endinterface

    // TODO: is this the right schedule? I'm worried...
    // Specifically: shouldn't af, and wdf be Conflicting with
    // themselves?
    schedule
    (
        ddr2_a, ddr2_ba, ddr2_ras_n, ddr2_cas_n, ddr2_we_n, ddr2_cs_n,
        ddr2_odt, ddr2_cke, ddr2_dm, ddr2_ck,
        ddr2_ck_n, app_af, app_wdf, app_data
    )
    CF
    (
        ddr2_a, ddr2_ba, ddr2_ras_n, ddr2_cas_n, ddr2_we_n, ddr2_cs_n,
        ddr2_odt, ddr2_cke, ddr2_dm, ddr2_ck,
        ddr2_ck_n, app_af, app_wdf, app_data
    );


endmodule

