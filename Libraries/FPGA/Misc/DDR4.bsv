////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : DDR4.bsv
//  Description   :
////////////////////////////////////////////////////////////////////////////////
package DDR4;

// Notes : This is currently (03/03/18) very similar to the DDR3 package,
// differing only in the DDR4_Pins definition, and associated macros.

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import Clocks            ::*;
import FIFO              ::*;
import FIFOF             ::*;
import SpecialFIFOs      ::*;
import TriState          ::*;
import DefaultValue      ::*;
import Counter           ::*;
import CommitIfc         ::*;
import Memory            ::*;
import GetPut            ::*;
import ClientServer      ::*;
import BUtils            ::*;
import I2C               ::*;
import Connectable       ::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// Types
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   Bool        simulation;
   Integer     reads_in_flight;
} DDR4_Configure;

instance DefaultValue#(DDR4_Configure);
   defaultValue = DDR4_Configure {
      simulation:       False,
      reads_in_flight:  8
      };
endinstance

typedef struct {
   Bit#(bewidth)    byteen;
   Bit#(addrwidth)  address;
   Bit#(datawidth)  data;
} DDR4Request#(numeric type addrwidth, numeric type datawidth, numeric type bewidth) deriving (Bits, Eq);

typedef struct {
   Bit#(datawidth)  data;
} DDR4Response#(numeric type datawidth) deriving (Bits, Eq);

// Despite the name, the first four parameters specify the user application
// side of the memory controller; while the remaining parameters specify
// the DDR4 pins side.
//
`define DDR4_PRM_DCL numeric type ddr4addrsize,\
                     numeric type ddr4datasize,\
                     numeric type ddr4besize,\
                     numeric type ddr4beats,\
                     numeric type datawidth,\
                     numeric type bewidth,\
                     numeric type rowwidth,\
		     numeric type colwidth,\
		     numeric type bankwidth,\
		     numeric type bankgroupwidth,\
		     numeric type rankwidth,\
		     numeric type clkwidth,\
		     numeric type cswidth,\
		     numeric type ckewidth,\
		     numeric type odtwidth

`define DDR4_PRM     ddr4addrsize,\
                     ddr4datasize,\
                     ddr4besize,\
                     ddr4beats,\
                     datawidth,\
                     bewidth,\
                     rowwidth,\
		     colwidth,\
		     bankwidth,\
		     bankgroupwidth,\
		     rankwidth,\
		     clkwidth,\
		     cswidth,\
		     ckewidth,\
		     odtwidth


////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
(* always_enabled, always_ready *)
interface DDR4_Pins#(`DDR4_PRM_DCL);
   (* prefix = "", result = "ACT_N" *)
   method    Bit#(1)                  act_n;
   (* prefix = "", result = "A" *)
   method    Bit#(rowwidth)           a;
   (* prefix = "", result = "BA" *)
   method    Bit#(bankwidth)          ba;
   (* prefix = "", result = "BG" *)
   method    Bit#(bankgroupwidth)     bg;
   (* prefix = "", result = "CK_C" *)
   method    Bit#(clkwidth)           ck_c;
   (* prefix = "", result = "CK_T" *)
   method    Bit#(clkwidth)           ck_t;
   (* prefix = "", result = "CKE" *)
   method    Bit#(ckewidth)           cke;
   (* prefix = "", result = "CS_N" *)
   method    Bit#(cswidth)            cs_n;
   (* prefix = "", result = "ODT" *)
   method    Bit#(1)                  odt;
   (* prefix = "", result = "RESET_N" *)
   method    Bit#(1)                  reset_n;
   (* prefix = "DM_DBI_N" *)
   interface Inout#(Bit#(bewidth))    dm_dbi_n;
   (* prefix = "DQ" *)
   interface Inout#(Bit#(datawidth))  dq;
   (* prefix = "DQS_C" *)
   interface Inout#(Bit#(bewidth))    dqs_c;
   (* prefix = "DQS_T" *)
   interface Inout#(Bit#(bewidth))    dqs_t;
endinterface

interface DDR4_User#(`DDR4_PRM_DCL);
   interface Clock                    clock;
   interface Reset                    reset_n;
   method    Bool                     init_done;
   method    Action                   request(Bit#(ddr4addrsize) addr,
					      Bit#(TMul#(ddr4besize,ddr4beats))   mask,
					      Bit#(TMul#(ddr4datasize,ddr4beats)) data
					      );
   method    ActionValue#(Bit#(TMul#(ddr4datasize,ddr4beats))) read_data;
endinterface

interface DDR4_Controller#(`DDR4_PRM_DCL);
   (* prefix = "" *)
   interface DDR4_Pins#(`DDR4_PRM)  ddr4;
   (* prefix = "" *)
   interface DDR4_User#(`DDR4_PRM)  user;
endinterface

(* always_ready, always_enabled *)
interface VDDR4_User_Xilinx#(`DDR4_PRM_DCL);
   interface Clock             clock;
   interface Reset             reset;
   method    Bool              init_done;
   method    Action            app_addr(Bit#(ddr4addrsize) i);
   method    Action            app_cmd(Bit#(3) i);
   method    Action            app_en(Bool i);
   method    Action            app_hi_pri(Bool i);
   method    Action            app_wdf_data(Bit#(ddr4datasize) i);
   method    Action            app_wdf_end(Bool i);
   method    Action            app_wdf_mask(Bit#(ddr4besize) i);
   method    Action            app_wdf_wren(Bool i);
   method    Bit#(ddr4datasize) app_rd_data;
   method    Bool              app_rd_data_end;
   method    Bool              app_rd_data_valid;
   method    Bool              app_rdy;
   method    Bool              app_wdf_rdy;
   method    Bit#(512)         dbg_bus;
endinterface

interface VDDR4_Controller_Xilinx#(`DDR4_PRM_DCL);
   (* prefix = "" *)
   interface DDR4_Pins#(`DDR4_PRM)  ddr4;
   (* prefix = "" *)
   interface VDDR4_User_Xilinx#(`DDR4_PRM)  user;
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
///
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkAsyncResetLong#(Integer cycles, Reset rst_in, Clock clk_out)(Reset);
   Reg#(UInt#(32)) count <- mkReg(fromInteger(cycles), clocked_by clk_out, reset_by rst_in);
   let rstifc <- mkReset(0, True, clk_out);

   rule count_down if (count > 0);
      count <= count - 1;
      rstifc.assertReset();
   endrule

   return rstifc.new_rst;
endmodule

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
///
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
module mkXilinxDDR4Controller_2beats#(VDDR4_Controller_Xilinx#(`DDR4_PRM) ddr4Ifc, DDR4_Configure cfg)(DDR4_Controller#(`DDR4_PRM))
   provisos( NumAlias#(2, ddr4beats)
	   , Add#(_1, 8, ddr4datasize)
	   , Add#(_2, 1, ddr4addrsize)
	   , Add#(_3, 1, ddr4besize)
           , NumAlias#(TMul#(ddr4datasize,2), ddr4datasz)
           , NumAlias#(TMul#(ddr4besize,2), ddr4besz)
	    // ultimately the following shouldn't be necessary
	   , Add#(ddr4besize, _4, TMul#(ddr4besize,2))
           , Add#(ddr4datasize, _5, TMul#(ddr4datasize,2))
	   );

   if (cfg.reads_in_flight < 1)
      error("The number of reads in flight has to be at least 1");

   Integer reads = cfg.reads_in_flight;

   ////////////////////////////////////////////////////////////////////////////////
   /// Clocks & Resets
   ////////////////////////////////////////////////////////////////////////////////
   Clock                                     clock               <- exposeCurrentClock;
   Reset                                     reset_n             <- exposeCurrentReset;
   Reset                                     dly_reset_n         <- mkAsyncResetLong( 40000, reset_n, clock );

   Clock                                     user_clock           = ddr4Ifc.user.clock;
   Reset                                     user_reset0_n       <- mkResetInverter(ddr4Ifc.user.reset);
   Reset                                     user_reset_n        <- mkAsyncReset(2, user_reset0_n, user_clock);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   FIFO#(DDR4Request#(ddr4addrsize,
		      ddr4datasz,
		      ddr4besz))             fRequest            <- mkFIFO(clocked_by user_clock, reset_by user_reset_n);
   FIFO#(DDR4Response#(ddr4datasz))          fResponse           <- mkFIFO(clocked_by user_clock, reset_by user_reset_n);

   Counter#(32)                              rReadsPending       <- mkCounter(0, clocked_by user_clock, reset_by user_reset_n);
   Reg#(Bool)                                rDeqWriteReq        <- mkReg(False, clocked_by user_clock, reset_by user_reset_n);
   Reg#(Bool)                                rEnqReadResp        <- mkReg(False, clocked_by user_clock, reset_by user_reset_n);
   Reg#(Bit#(ddr4datasize))                  rFirstResponse      <- mkReg(0, clocked_by user_clock, reset_by user_reset_n);

   PulseWire                                 pwAppEn             <- mkPulseWire(clocked_by user_clock, reset_by user_reset_n);
   PulseWire                                 pwAppWdfWren        <- mkPulseWire(clocked_by user_clock, reset_by user_reset_n);
   PulseWire                                 pwAppWdfEnd         <- mkPulseWire(clocked_by user_clock, reset_by user_reset_n);

   Wire#(Bit#(3))                            wAppCmd             <- mkDWire(0, clocked_by user_clock, reset_by user_reset_n);
   Wire#(Bit#(ddr4addrsize))                 wAppAddr            <- mkDWire(0, clocked_by user_clock, reset_by user_reset_n);
   Wire#(Bit#(ddr4besize))                   wAppWdfMask         <- mkDWire('1, clocked_by user_clock, reset_by user_reset_n);
   Wire#(Bit#(ddr4datasize))                 wAppWdfData         <- mkDWire(0, clocked_by user_clock, reset_by user_reset_n);

   Bool initialized      = ddr4Ifc.user.init_done;
   Bool ctrl_ready_req   = ddr4Ifc.user.app_rdy;
   Bool write_ready_req  = ddr4Ifc.user.app_wdf_rdy;
   Bool read_data_ready  = ddr4Ifc.user.app_rd_data_valid;

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* fire_when_enabled, no_implicit_conditions *)
   rule tie_off_hi_pri;
      ddr4Ifc.user.app_hi_pri(False);
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule drive_enables;
      ddr4Ifc.user.app_en(pwAppEn);
      ddr4Ifc.user.app_wdf_wren(pwAppWdfWren);
      ddr4Ifc.user.app_wdf_end(pwAppWdfEnd);
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule drive_data_signals;
      ddr4Ifc.user.app_cmd(wAppCmd);
      ddr4Ifc.user.app_addr(wAppAddr);
      ddr4Ifc.user.app_wdf_data(wAppWdfData);
      ddr4Ifc.user.app_wdf_mask(wAppWdfMask);
   endrule

   rule ready(initialized);
      rule process_write_request_first((fRequest.first.byteen != 0) && !rDeqWriteReq && ctrl_ready_req && write_ready_req);
	 rDeqWriteReq <= True;
	 wAppCmd      <= 0;
	 wAppAddr     <= fRequest.first.address;
	 pwAppEn.send;
	 wAppWdfData  <= truncate(fRequest.first.data);
	 wAppWdfMask  <= ~truncate(fRequest.first.byteen);
	 pwAppWdfWren.send;
      endrule

      rule process_write_request_second((fRequest.first.byteen != 0) && rDeqWriteReq && write_ready_req);
	 fRequest.deq;
	 rDeqWriteReq <= False;
	 wAppWdfData  <= truncateLSB(fRequest.first.data);
	 wAppWdfMask  <= ~truncateLSB(fRequest.first.byteen);
	 pwAppWdfWren.send;
	 pwAppWdfEnd.send;
      endrule

      rule process_read_request(fRequest.first.byteen == 0 && ctrl_ready_req);
	 fRequest.deq;
	 wAppCmd  <= 1;
	 wAppAddr <= fRequest.first.address;
	 pwAppEn.send;
	 rReadsPending.inc(2);
      endrule

      rule process_read_response_first(!rEnqReadResp && read_data_ready);
	 rFirstResponse <= ddr4Ifc.user.app_rd_data;
	 rEnqReadResp   <= True;
	 rReadsPending.down;
      endrule

      rule process_read_response_second(rEnqReadResp && read_data_ready);
	 fResponse.enq(unpack({ ddr4Ifc.user.app_rd_data, rFirstResponse }));
	 rEnqReadResp   <= False;
	 rReadsPending.down;
      endrule
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface ddr4 = ddr4Ifc.ddr4;
   interface DDR4_User user;
      interface clock   = user_clock;
      interface reset_n = user_reset_n;
      method init_done  = initialized;

      method Action request(Bit#(ddr4addrsize) addr, Bit#(ddr4besz) mask, Bit#(ddr4datasz) data);
	 let req = DDR4Request { byteen: mask, address: addr, data: data };
	 fRequest.enq(req);
      endmethod

      method ActionValue#(Bit#(ddr4datasz)) read_data;
	 fResponse.deq;
	 return fResponse.first.data;
      endmethod
   endinterface
endmodule: mkXilinxDDR4Controller_2beats

module mkXilinxDDR4Controller_1beat#(VDDR4_Controller_Xilinx#(`DDR4_PRM) ddr4Ifc, DDR4_Configure cfg)(DDR4_Controller#(`DDR4_PRM))
   provisos( NumAlias#(1, ddr4beats)
	   , Add#(_1, 8, ddr4datasize)
	   , Add#(_2, 1, ddr4addrsize)
	   , Add#(_3, 1, ddr4besize)
	   );

   if (cfg.reads_in_flight < 1)
      error("The number of reads in flight has to be at least 1");

   Integer reads = cfg.reads_in_flight;

   ////////////////////////////////////////////////////////////////////////////////
   /// Clocks & Resets
   ////////////////////////////////////////////////////////////////////////////////
   //Clock                                     clock               <- exposeCurrentClock;
   //Reset                                     reset_n             <- exposeCurrentReset;
   //Reset                                     dly_reset_n         <- mkAsyncResetLong( 40000, reset_n, clock );

   Clock                                     user_clock           = ddr4Ifc.user.clock;
   Reset                                     user_reset0_n       <- mkResetInverter(ddr4Ifc.user.reset);
   Reset                                     user_reset_n        <- mkAsyncReset(2, user_reset0_n, user_clock);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   FIFO#(DDR4Request#(ddr4addrsize,
		      ddr4datasize,
		      ddr4besize))           fRequest            <- mkFIFO(clocked_by user_clock, reset_by user_reset_n);
   FIFO#(DDR4Response#(ddr4datasize))        fResponse           <- mkFIFO(clocked_by user_clock, reset_by user_reset_n);

   Counter#(32)                              rReadsPending       <- mkCounter(0, clocked_by user_clock, reset_by user_reset_n);

   PulseWire                                 pwAppEn             <- mkPulseWire(clocked_by user_clock, reset_by user_reset_n);
   PulseWire                                 pwAppWdfWren        <- mkPulseWire(clocked_by user_clock, reset_by user_reset_n);
   PulseWire                                 pwAppWdfEnd         <- mkPulseWire(clocked_by user_clock, reset_by user_reset_n);

   Wire#(Bit#(3))                            wAppCmd             <- mkDWire(0, clocked_by user_clock, reset_by user_reset_n);
   Wire#(Bit#(ddr4addrsize))                 wAppAddr            <- mkDWire(0, clocked_by user_clock, reset_by user_reset_n);
   Wire#(Bit#(ddr4besize))                   wAppWdfMask         <- mkDWire('1, clocked_by user_clock, reset_by user_reset_n);
   Wire#(Bit#(ddr4datasize))                 wAppWdfData         <- mkDWire(0, clocked_by user_clock, reset_by user_reset_n);

   Bool initialized      = ddr4Ifc.user.init_done;
   Bool ctrl_ready_req   = ddr4Ifc.user.app_rdy;
   Bool write_ready_req  = ddr4Ifc.user.app_wdf_rdy;
   Bool read_data_ready  = ddr4Ifc.user.app_rd_data_valid;

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* fire_when_enabled, no_implicit_conditions *)
   rule tie_off_hi_pri;
      ddr4Ifc.user.app_hi_pri(False);
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule drive_enables;
      ddr4Ifc.user.app_en(pwAppEn);
      ddr4Ifc.user.app_wdf_wren(pwAppWdfWren);
      ddr4Ifc.user.app_wdf_end(pwAppWdfEnd);
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule drive_data_signals;
      ddr4Ifc.user.app_cmd(wAppCmd);
      ddr4Ifc.user.app_addr(wAppAddr);
      ddr4Ifc.user.app_wdf_data(wAppWdfData);
      ddr4Ifc.user.app_wdf_mask(wAppWdfMask);
   endrule

   rule ready(initialized);
      rule process_write_request((fRequest.first.byteen != 0) && ctrl_ready_req && write_ready_req);
	 let request <- toGet(fRequest).get;
	 wAppCmd      <= 0;
	 wAppAddr     <= request.address;
	 wAppWdfData  <= request.data;
	 wAppWdfMask  <= ~request.byteen;
	 pwAppEn.send;
	 pwAppWdfWren.send;
	 pwAppWdfEnd.send;
      endrule

      rule process_read_request(fRequest.first.byteen == 0 && ctrl_ready_req);
	 let request <- toGet(fRequest).get;
	 wAppCmd  <= 1;
	 wAppAddr <= request.address;
	 pwAppEn.send;
	 rReadsPending.up;
      endrule

      rule process_read_response(read_data_ready);
	 fResponse.enq(unpack(ddr4Ifc.user.app_rd_data));
	 rReadsPending.down;
      endrule
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface ddr4 = ddr4Ifc.ddr4;
   interface DDR4_User user;
      interface clock   = user_clock;
      interface reset_n = user_reset_n;
      method init_done  = initialized;

      method Action request(Bit#(ddr4addrsize) addr, Bit#(ddr4besize) mask, Bit#(ddr4datasize) data);
	 let req = DDR4Request { byteen: mask, address: addr, data: data };
	 fRequest.enq(req);
      endmethod

      method ActionValue#(Bit#(ddr4datasize)) read_data;
	 fResponse.deq;
	 return fResponse.first.data;
      endmethod
   endinterface
endmodule: mkXilinxDDR4Controller_1beat


endpackage: DDR4
