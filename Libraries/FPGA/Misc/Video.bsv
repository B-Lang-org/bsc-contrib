////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : Video.bsv
//  Description   : General Video related modules/types
////////////////////////////////////////////////////////////////////////////////
package Video;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import GetPut            ::*;
import StmtFSM           ::*;
import Counter           ::*;
import Connectable       ::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// Types
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   Bit#(8)     red;
   Bit#(8)     green;
   Bit#(8)     blue;
} RGB888 deriving (Bits, Eq);

typedef struct {
   Bit#(8)     cr;
   Bit#(8)     y;
   Bit#(8)     cb;
} CrYCb444 deriving (Bits, Eq);

typedef struct {
   Bit#(8)     c;
   Bit#(8)     y;
} CrYCbY422 deriving (Bits, Eq);

typedef struct {
   Integer     active;
   Integer     fporch;
   Integer     sync;
   Integer     bporch;
} SyncDescriptor;

typedef struct {
   SyncDescriptor h;
   SyncDescriptor v;
} VideoTiming;

// 25 MHz pixel clock
VideoTiming vga640x480x60 = VideoTiming {
   h: SyncDescriptor {
       active: 640,
       fporch:  16,
       sync:    96,
       bporch:  48
       },
   v: SyncDescriptor {
       active: 480,
       fporch:  10,
       sync:     2,
       bporch:  33
       }
};

// 40 MHz pixel clock
VideoTiming vesa800x600x60 = VideoTiming {
   h: SyncDescriptor {
       active: 800,
       fporch:  40,
       sync:   128,
       bporch:  88
       },
   v: SyncDescriptor {
       active: 600,
       fporch:   1,
       sync:     4,
       bporch:  23
       }
};

// 65 MHz pixel clock
VideoTiming vesa1024x768x60 = VideoTiming {
   h: SyncDescriptor {
       active: 1024,
       fporch:   24,
       sync:    136,
       bporch:  160
       },
   v: SyncDescriptor {
       active:  768,
       fporch:    3,
       sync:      6,
       bporch:   29
       }
};

// 108 MHz pixel clock
VideoTiming vesa1280x1024x60 = VideoTiming {
   h: SyncDescriptor {
       active: 1280,
       fporch:   48,
       sync:    112,
       bporch:  248
       },
   v: SyncDescriptor {
       active: 1024,
       fporch:    1,
       sync:      3,
       bporch:   38
       }
};

// 162 MHz pixel clock
VideoTiming vesa1600x1200x60 = VideoTiming {
   h: SyncDescriptor {
       active: 1600,
       fporch:   64,
       sync:    192,
       bporch:  304
       },
   v: SyncDescriptor {
       active: 1200,
       fporch:    1,
       sync:      3,
       bporch:   46
       }
};

//
VideoTiming hdtv_480p = VideoTiming {
   h: SyncDescriptor {
      active:  720,
      fporch:   24,
      sync:     64,
      bporch:   88
      },
   v: SyncDescriptor {
      active:  480,
      fporch:    3,
      sync:     10,
      bporch:    7
      }
};

// 74.25 MHz pixel clock
VideoTiming hdtv_720p = VideoTiming {
   h: SyncDescriptor {
      active: 1280,
      fporch:  110,
      sync:     40,
      bporch:  220
      },
   v: SyncDescriptor {
      active:  720,
      fporch:    5,
      sync:      5,
      bporch:   20
      }
};

// 148.50 MHz pixel clock
VideoTiming hdtv_1080p = VideoTiming {
   h: SyncDescriptor {
      active: 1920,
      fporch:   88,
      sync:     44,
      bporch:  148
      },
   v: SyncDescriptor {
      active: 1080,
      fporch:    4,
      sync:      5,
      bporch:   36
      }
};

typedef struct {
   Bit#(1)     vsync;
   Bit#(1)     hsync;
   Bit#(1)     dataen;
   d           data;
} PixelData#(type d) deriving (Bits, Eq);

typedef PixelData#(Bit#(0)) SyncData;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   Bit#(25)     a;
   Bit#(25)     b;
   Bit#(25)     c;
   Bit#(25)     d;
   SyncData     sync;
} CSAdderIn deriving (Bits, Eq);

(* always_ready, always_enabled *)
interface CSAdder;
   interface Put#(CSAdderIn)           in;
   interface Get#(PixelData#(Bit#(8))) out;
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
///
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
(* synthesize *)
module mkCSAdder(CSAdder);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Reg#(CSAdderIn)            rData_S1       <- mkReg(unpack(0));

   Reg#(SyncData)             rSync_S2       <- mkReg(unpack(0));
   Reg#(Bit#(25))             rData0_S2      <- mkReg(unpack(0));
   Reg#(Bit#(25))             rData1_S2      <- mkReg(unpack(0));

   Reg#(SyncData)             rSync_S3       <- mkReg(unpack(0));
   Reg#(Bit#(25))             rData_S3       <- mkReg(unpack(0));

   Reg#(PixelData#(Bit#(8)))  rData_S4       <- mkReg(unpack(0));

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* fire_when_enabled, no_implicit_conditions *)
   rule stage1_to_stage2;
      rSync_S2  <= rData_S1.sync;
      rData0_S2 <= rData_S1.a + rData_S1.b;
      rData1_S2 <= rData_S1.c + rData_S1.d;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule stage2_to_stage3;
      rSync_S3 <= rSync_S2;
      rData_S3 <= rData0_S2 + rData1_S2;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule stage3_to_stage4;
      let data = PixelData {
	 vsync:  rSync_S3.vsync,
	 hsync:  rSync_S3.hsync,
	 dataen: rSync_S3.dataen,
	 data:   ?
	 };

      if (msb(rData_S3) == 1)
	 data.data = 0;
      else if (rData_S3[23:20] == 0)
	 data.data = rData_S3[19:12];
      else
	 data.data = '1;

      rData_S4 <= data;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface Put in;
      method Action put(CSAdderIn x);
	 rData_S1 <= CSAdderIn {
	    a: ((msb(x.a) == 1) ? (~x.a + 1) : x.a),
	    b: ((msb(x.b) == 1) ? (~x.b + 1) : x.b),
	    c: ((msb(x.c) == 1) ? (~x.c + 1) : x.c),
	    d: ((msb(x.d) == 1) ? (~x.d + 1) : x.d),
	    sync: x.sync
	    };
      endmethod
   endinterface

   interface Get out;
      method ActionValue#(PixelData#(Bit#(8))) get();
	 return rData_S4;
      endmethod
   endinterface

endmodule: mkCSAdder

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   Bit#(17)    a;
   Bit#(8)     b;
   SyncData    sync;
} CSMultIn deriving (Bits, Eq);

(* always_ready, always_enabled *)
interface CSMult;
   interface Put#(CSMultIn)             in;
   interface Get#(PixelData#(Bit#(25))) out;
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
///
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
(* synthesize *)
module mkCSMult(CSMult);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Reg#(Bit#(1))              rSign_S1       <- mkReg(unpack(0));
   Reg#(SyncData)             rSync_S1       <- mkReg(unpack(0));
   Reg#(Bit#(24))             rData0_S1      <- mkReg(unpack(0));
   Reg#(Bit#(24))             rData1_S1      <- mkReg(unpack(0));
   Reg#(Bit#(24))             rData2_S1      <- mkReg(unpack(0));
   Reg#(Bit#(24))             rData3_S1      <- mkReg(unpack(0));
   Reg#(Bit#(24))             rData4_S1      <- mkReg(unpack(0));

   Reg#(Bit#(1))              rSign_S2       <- mkReg(unpack(0));
   Reg#(SyncData)             rSync_S2       <- mkReg(unpack(0));
   Reg#(Bit#(24))             rData0_S2      <- mkReg(unpack(0));
   Reg#(Bit#(24))             rData1_S2      <- mkReg(unpack(0));

   Reg#(Bit#(1))              rSign_S3       <- mkReg(unpack(0));
   Reg#(SyncData)             rSync_S3       <- mkReg(unpack(0));
   Reg#(Bit#(24))             rData_S3       <- mkReg(unpack(0));

   Reg#(PixelData#(Bit#(25))) rData_S4       <- mkReg(unpack(0));

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* fire_when_enabled, no_implicit_conditions *)
   rule stage1_to_stage2;
      rSign_S2  <= rSign_S1;
      rSync_S2  <= rSync_S1;
      rData0_S2 <= rData0_S1 + rData1_S1 + rData4_S1;
      rData1_S2 <= rData2_S1 + rData3_S1;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule stage2_to_stage3;
      rSign_S3 <= rSign_S2;
      rSync_S3 <= rSync_S2;
      rData_S3 <= rData0_S2 + rData1_S2;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule stage3_to_stage4;
      let data = PixelData {
	 vsync:  rSync_S3.vsync,
	 hsync:  rSync_S3.hsync,
	 dataen: rSync_S3.dataen,
	 data:   ?
	 };

      data.data = { rSign_S3, rData_S3 };

      rData_S4 <= data;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface Put in;
      method Action put(CSMultIn x);
	 Bit#(17) x_a_1p_17 = { 1'b0, x.a[15:0] };
	 Bit#(17) x_a_1n_17 = ~x_a_1p_17 + 1;

	 Bit#(24) x_a_1p = pack(signExtend(x_a_1p_17));
	 Bit#(24) x_a_1n = pack(signExtend(x_a_1n_17));
	 Bit#(24) x_a_2p = pack(signExtend({x_a_1p_17,1'b0}));
	 Bit#(24) x_a_2n = pack(signExtend({x_a_1n_17,1'b0}));

	 rSign_S1 <= msb(x.a);
	 rSync_S1 <= x.sync;
	 case(x.b[1:0])
	    2'b11:   rData0_S1 <= x_a_1n;
	    2'b10:   rData0_S1 <= x_a_2n;
	    2'b01:   rData0_S1 <= x_a_1p;
	    default: rData0_S1 <= 0;
	 endcase
	 case(x.b[3:1])
	    3'b011:  rData1_S1 <= {x_a_2p[21:0], 2'b00};
	    3'b100:  rData1_S1 <= {x_a_2n[21:0], 2'b00};
	    3'b001:  rData1_S1 <= {x_a_1p[21:0], 2'b00};
	    3'b010:  rData1_S1 <= {x_a_1p[21:0], 2'b00};
	    3'b101:  rData1_S1 <= {x_a_1n[21:0], 2'b00};
	    3'b110:  rData1_S1 <= {x_a_1n[21:0], 2'b00};
	    default: rData1_S1 <= 0;
	 endcase
	 case(x.b[5:3])
	    3'b011:  rData2_S1 <= {x_a_2p[19:0], 4'd0};
	    3'b100:  rData2_S1 <= {x_a_2n[19:0], 4'd0};
	    3'b001:  rData2_S1 <= {x_a_1p[19:0], 4'd0};
	    3'b010:  rData2_S1 <= {x_a_1p[19:0], 4'd0};
	    3'b101:  rData2_S1 <= {x_a_1n[19:0], 4'd0};
	    3'b110:  rData2_S1 <= {x_a_1n[19:0], 4'd0};
	    default: rData2_S1 <= 0;
	 endcase
	 case(x.b[7:5])
	    3'b011:  rData3_S1 <= {x_a_2p[17:0], 6'd0};
	    3'b100:  rData3_S1 <= {x_a_2n[17:0], 6'd0};
	    3'b001:  rData3_S1 <= {x_a_1p[17:0], 6'd0};
	    3'b010:  rData3_S1 <= {x_a_1p[17:0], 6'd0};
	    3'b101:  rData3_S1 <= {x_a_1n[17:0], 6'd0};
	    3'b110:  rData3_S1 <= {x_a_1n[17:0], 6'd0};
	    default: rData3_S1 <= 0;
	 endcase
	 case(x.b[7])
	    1'b1:    rData4_S1 <= {x_a_1p[15:0], 8'd0};
	    default: rData4_S1 <= 0;
	 endcase
      endmethod
   endinterface

   interface Get out;
      method ActionValue#(PixelData#(Bit#(25))) get();
	 return rData_S4;
      endmethod
   endinterface

endmodule: mkCSMult

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////
(* always_ready, always_enabled *)
interface CSMacc;
   interface Put#(PixelData#(Bit#(24))) in;
   interface Get#(PixelData#(Bit#(8)))  out;
endinterface

(* synthesize *)
module mkCSMacc#(Bit#(17) c1, Bit#(17) c2, Bit#(17) c3, Bit#(25) c4)(CSMacc);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   let                        i_mul_c1       <- mkCSMult;
   let                        i_mul_c2       <- mkCSMult;
   let                        i_mul_c3       <- mkCSMult;
   let                        i_add_c4       <- mkCSAdder;

   Reg#(PixelData#(Bit#(24))) rPixelIn       <- mkReg(unpack(0));
   Reg#(PixelData#(Bit#(8)))  rPixelOut      <- mkReg(unpack(0));

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* fire_when_enabled, no_implicit_conditions *)
   rule drive_multipliers;
      // C1
      let t1 = CSMultIn {
	 a:  c1,
	 b:  rPixelIn.data[23:16],
	 sync: SyncData {
	    vsync:  rPixelIn.vsync,
	    hsync:  rPixelIn.hsync,
	    dataen: rPixelIn.dataen,
	    data:   ?
	    }
	 };
      i_mul_c1.in.put(t1);
      // C2
      let t2 = CSMultIn {
	 a:  c2,
	 b:  rPixelIn.data[15:8],
	 sync: SyncData {
	    vsync:  rPixelIn.vsync,
	    hsync:  rPixelIn.hsync,
	    dataen: rPixelIn.dataen,
	    data:   ?
	    }
	 };
      i_mul_c2.in.put(t2);
      // C3
      let t3 = CSMultIn {
	 a:  c3,
	 b:  rPixelIn.data[7:0],
	 sync: SyncData {
	    vsync:  rPixelIn.vsync,
	    hsync:  rPixelIn.hsync,
	    dataen: rPixelIn.dataen,
	    data:   ?
	    }
	 };
      i_mul_c3.in.put(t3);
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule drive_adder;
      let data1 <- i_mul_c1.out.get;
      let data2 <- i_mul_c2.out.get;
      let data3 <- i_mul_c3.out.get;

      let in = CSAdderIn {
	 a:    data1.data,
	 b:    data2.data,
	 c:    data3.data,
	 d:    c4,
	 sync: SyncData {
	    vsync:  data1.vsync,
	    hsync:  data1.hsync,
	    dataen: data1.dataen,
	    data:   ?
	    }
	 };
      i_add_c4.in.put(in);
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule capture_results;
      let data <- i_add_c4.out.get;
      rPixelOut <= data;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface Put in;
      method Action put(PixelData#(Bit#(24)) x);
	 rPixelIn <= x;
      endmethod
   endinterface

   interface Get out;
      method ActionValue#(PixelData#(Bit#(8))) get();
	 return rPixelOut;
      endmethod
   endinterface

endmodule: mkCSMacc

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////
(* always_ready, always_enabled *)
interface RGB888toCrYCbY422;
   interface Put#(PixelData#(RGB888))    rgb;
   interface Get#(PixelData#(CrYCbY422)) crycby;
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
///
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
(* synthesize *)
module mkRGB888toCrYCbY422(RGB888toCrYCbY422);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Reg#(PixelData#(RGB888))   rPixelIn       <- mkReg(unpack(0));
   let                        i_csc_Cr       <- mkCSMacc(17'h00707, 17'h105e2, 17'h10124, 25'h0080000);
   let                        i_csc_Y        <- mkCSMacc(17'h0041b, 17'h00810, 17'h00191, 25'h0010000);
   let                        i_csc_Cb       <- mkCSMacc(17'h1025f, 17'h104a7, 17'h00707, 25'h0080000);

   Reg#(PixelData#(CrYCb444)) rPixelInter    <- mkReg(unpack(0));
   Reg#(PixelData#(Bit#(24))) rData_S1       <- mkReg(unpack(0));
   Reg#(PixelData#(Bit#(24))) rData_S2       <- mkReg(unpack(0));
   Reg#(PixelData#(Bit#(24))) rData_S3       <- mkReg(unpack(0));

   Reg#(Bool)                 rCrCbSel       <- mkReg(True);
   Reg#(Bit#(8))              rCr            <- mkReg(0);
   Reg#(Bit#(8))              rCb            <- mkReg(0);

   Reg#(PixelData#(CrYCbY422)) rPixelOut     <- mkReg(unpack(0));

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* fire_when_enabled, no_implicit_conditions *)
   rule drive_macs;
      PixelData#(Bit#(24)) x = PixelData {
	 vsync:  rPixelIn.vsync,
	 hsync:  rPixelIn.hsync,
	 dataen: rPixelIn.dataen,
	 data:   pack(rPixelIn.data)
	 };

      i_csc_Cr.in.put(x);
      i_csc_Y.in.put(x);
      i_csc_Cb.in.put(x);
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule assemble_intermediate_pixel;
      let out_cr <- i_csc_Cr.out.get;
      let out_y  <- i_csc_Y.out.get;
      let out_cb <- i_csc_Cb.out.get;

      rPixelInter <= PixelData {
	 vsync:   out_cr.vsync,
	 hsync:   out_cr.hsync,
	 dataen:  out_cr.dataen,
	 data:    CrYCb444 { cr: out_cr.data, y: out_y.data, cb: out_cb.data }
	 };
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule pipeline_subsample_pixels;
      rData_S1  <= PixelData {
	 vsync:  rPixelInter.vsync,
	 hsync:  rPixelInter.hsync,
	 dataen: rPixelInter.dataen,
	 data:   pack(rPixelInter.data)
	 };
      rData_S2  <= rData_S1;
      rData_S3  <= rData_S2;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule compute_subsample_cr_cb;
      Bit#(10) cr = { 2'd0, rData_S1.data[23:16] } + { 2'd0, rData_S3.data[23:16] } + { 1'd0, rData_S2.data[23:16], 1'd0 };
      Bit#(10) cb = { 2'd0, rData_S1.data[7:0] } + { 2'd0, rData_S3.data[7:0] } + { 1'd0, rData_S2.data[7:0], 1'd0 };
      rCr <= cr[9:2];
      rCb <= cb[9:2];
      if (rData_S3.dataen == 1) begin
	 rCrCbSel <= !rCrCbSel;
      end
      else begin
	 rCrCbSel <= True;
      end
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule assemble_output_pixel;
      PixelData#(CrYCbY422) d = PixelData {
	 vsync:  rData_S3.vsync,
	 hsync:  rData_S3.hsync,
	 dataen: rData_S3.dataen,
	 data:   ?
	 };

      if (rData_S3.dataen == 0)
	 d.data = CrYCbY422 { c: 0, y: 0 };
      else if (rCrCbSel)
	 d.data = CrYCbY422 { c: rCr, y: rData_S3.data[15:8] };
      else
	 d.data = CrYCbY422 { c: rCb, y: rData_S3.data[15:8] };

      rPixelOut <= d;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface Put rgb;
      method Action put(PixelData#(RGB888) x);
	 rPixelIn <= x;
      endmethod
   endinterface

   interface Get crycby;
      method ActionValue#(PixelData#(CrYCbY422)) get();
	 return rPixelOut;
      endmethod
   endinterface

endmodule: mkRGB888toCrYCbY422

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////
interface SyncGenerator;
   method    Action      tick();
   method    Bool        preedge();
   method    Bool        out_n();
   method    Bool        out();
   method    Bool        active();
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
///
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkSyncGenerator#(SyncDescriptor info)(SyncGenerator);

   let maxActive = fromInteger(info.active - 1);
   let maxFPorch = fromInteger(info.fporch - 1);
   let maxSync   = fromInteger(info.sync   - 1);
   let maxBPorch = fromInteger(info.bporch - 1);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Counter#(16)                    rCounter            <- mkCounter(0);

   PulseWire                       pwTick              <- mkPulseWire;
   PulseWire                       pwPreSyncEdge       <- mkPulseWire;
   Reg#(Bool)                      rSyncOut            <- mkReg(True);
   Reg#(Bool)                      rActive             <- mkReg(False);

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   Stmt machine =
   seq
      while(True) seq
	 // Front Porch
	 while(rCounter.value < maxFPorch) action
	    rCounter.up;
	 endaction

	 action
	    rCounter.clear;
	    pwPreSyncEdge.send;
	    rSyncOut   <= False;
	    rActive    <= False;
	 endaction

	 // Sync Pulse
	 while(rCounter.value < maxSync) action
	    rCounter.up;
	 endaction

	 action
	    rCounter.clear;
	    rSyncOut  <= True;
	    rActive   <= False;
	 endaction

	 // Back Porch
	 while(rCounter.value < maxBPorch) action
	    rCounter.up;
	 endaction

	 action
	    rCounter.clear;
	    rSyncOut  <= True;
	    rActive   <= True;
	 endaction

	 // Active
	 while(rCounter.value < maxActive) action
	    rCounter.up;
	 endaction

	 action
	    rCounter.clear;
	    rSyncOut  <= True;
	    rActive   <= False;
	 endaction
      endseq
   endseq;

   FSM                             fsmSyncGen          <- mkFSMWithPred(machine, pwTick);

   rule start_sync_generator(fsmSyncGen.done);
      fsmSyncGen.start;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   method Action tick     = pwTick.send;
   method Bool   preedge  = pwPreSyncEdge;
   method Bool   out_n    = rSyncOut;
   method Bool   out      = !rSyncOut;
   method Bool   active   = rActive;

endmodule: mkSyncGenerator

endpackage: Video

