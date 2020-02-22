////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : XilinxCells.bsv
//  Description   : Xilinx specific primitive wrappers
////////////////////////////////////////////////////////////////////////////////
package XilinxCells;

// Notes :
// - Some parameters are really "Real" numbers, but Integers are interpreted
//   correctly by the Xilinx synthesis tools, so they are used here.  Once "Real"
//   parameter support exists, this package should be updated.
// - When feedback clocks are supported with '?', this module should be updated
//   to take advantage

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import Clocks            ::*;
import DefaultValue      ::*;
import TieOff            ::*;
import Vector            ::*;
import Real              ::*;
import TriState          ::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////
export BUFRParams(..);
export IBUFGParams(..);
export IBUFParams(..);
export IBUFDSParams(..);
export IBUFGDSParams(..);
export IBUFDS_GTXE1Params(..);
export IBUFDS_GTE2Params(..);
export OBUFParams(..);
export OBUFDSParams(..);
export ODDRParams(..);
export ODDR(..);
export IDDRParams(..);
export IDDR(..);
export IDELAYCTRL(..);
export IDELAYParams(..);
export IDELAY(..);
export IODELAYParams(..);
export IODELAY(..);
export ClockIODELAYParams(..);
export DiffClock(..);
export PLLParams(..);
export PLL(..);
export ClockGeneratorParams(..);
export ClockGenerator(..);
export ClockGenerator6Params(..);
export ClockGenerator6(..);
export ClockGenerator7Params(..);
export ClockGenerator7(..);
export ClockGeneratorUParams(..);
export ClockGeneratorU(..);
export DCMParams(..);
export DCM(..);
export DCM_DRP(..);
export DCM_PS(..);
export MMCMParams(..);
export MMCM(..);
export MMCM_DRP(..);
export MMCM_PS(..);
export MMCM_CDDC(..);
export MMCME2(..);
export MMCME3(..);
export SRL16EParams(..);
export SRL16E(..);
export SRLC32EParams(..);
export SRLC32E(..);


export mkBUFG;
export mkClockBUFG;
export mkClockBitBUFG;
export mkBitClockBUFG;
export mkBUFR;
export mkClockBUFR;
export mkClockBitBUFR;
export mkResetBUFG;
export mkIBUFG;
export mkClockIBUFG;
export mkIBUF;
export mkClockIBUF;
export mkResetIBUF;
export mkClockIBUFDS;
export mkClockIBUFGDS;
export mkClockIBUFDS_GTXE1;
export mkClockIBUFDS_GTXE1_div2;
export mkClockIBUFDS_GTXE1_both;
export mkClockIBUFDS_GTE2;
export mkClockIBUFDS_GTE2_div2;
export mkClockIBUFDS_GTE2_both;
export mkClockIBUFDS_GTE3;
export mkClockIBUFDS_GTHE1;
export mkOBUF;
export mkClockOBUFDS;
export mkODDR;
export mkClockODDR;
export mkIDDR;
export mkIDELAYCTRL;
export mkIDELAY;
export mkIODELAY;
export mkClockIODELAY;
export mkPLL;
export mkClockGenerator;
export mkClockGenerator6;
export mkClockGenerator7;
export mkClockGeneratorU;
export mkDCM;
export mkDCMClockDivider;
export mkMMCM;
export mkMMCME2;
export mkMMCME3;
export mkSRL16E;
export mkSRLC32E;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Miscellaneous Wrappers
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Buffer Cells
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// BUFG
////////////////////////////////////////////////////////////////////////////////
import "BVI" BUFG =
module vMkBUFG(Wire#(one_bit))
   provisos(Bits#(one_bit, 1));

   default_clock clk();
   default_reset rstn();

   method      _write(I) enable((*inhigh*)en);
   method O    _read;

   path(I, O);

   schedule _write SB _read;
   schedule _write C  _write;
   schedule _read  CF _read;
endmodule: vMkBUFG

module mkBUFG(Wire#(a))
   provisos(Bits#(a, sa));

   Vector#(sa, Wire#(Bit#(1))) _bufg <- replicateM(vMkBUFG);

   method a _read;
      return unpack(pack(readVReg(_bufg)));
   endmethod

   method Action _write(a x);
      writeVReg(_bufg, unpack(pack(x)));
   endmethod
endmodule: mkBUFG

import "BVI" BUFG =
module vMkClockBUFG(ClockGenIfc);
   default_clock clk(I, (*unused*)GATE);
   default_reset no_reset;

   path(I, O);

   output_clock gen_clk(O);

   same_family(clk, gen_clk);
endmodule: vMkClockBUFG

module mkClockBUFG(Clock);
   let _m <- vMkClockBUFG;
   return _m.gen_clk;
endmodule: mkClockBUFG

import "BVI" BUFG =
module vMkClockBitBUFG(ReadOnly#(one_bit))
   provisos(Bits#(one_bit, 1));

   default_clock clk(I);
   default_reset no_reset;

   path(I, O);

   method O _read;

   schedule _read CF _read;

endmodule: vMkClockBitBUFG

module mkClockBitBUFG(ReadOnly#(one_bit))
   provisos(Bits#(one_bit, 1));

   let _m <- vMkClockBitBUFG;
   return _m;

endmodule: mkClockBitBUFG

import "BVI" BUFG =
module vMkBitClockBUFG#(ReadOnly#(one_bit) in)(ClockGenIfc)
   provisos(Bits#(one_bit, 1));

   default_clock no_clock;
   default_reset no_reset;

   port I = in;

   output_clock gen_clk(O);

   path(I, O);
endmodule

module mkBitClockBUFG#(ReadOnly#(one_bit) in)(Clock)
   provisos(Bits#(one_bit, 1));

   let _m <- vMkBitClockBUFG(in);
   return _m.gen_clk;
endmodule

interface ResetGenIfc;
   interface Reset gen_rst;
endinterface

import "BVI" BUFG =
module vMkResetBUFG(ResetGenIfc);
   default_clock clk();
   default_reset rst_in(I);

   path(I, O);

   output_reset gen_rst(O) clocked_by(clk);
endmodule: vMkResetBUFG

module mkResetBUFG(Reset);
   let _m <- vMkResetBUFG;
   return _m.gen_rst;
endmodule: mkResetBUFG

////////////////////////////////////////////////////////////////////////////////
/// BUFR
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String      bufr_divide;
   String      sim_device;
} BUFRParams deriving (Bits, Eq);

instance DefaultValue#(BUFRParams);
   defaultValue = BUFRParams {
      bufr_divide:           "BYPASS",
      sim_device:            "VIRTEX4"
      };
endinstance

import "BVI" BUFR =
module vMkBUFR#(BUFRParams params)(Wire#(one_bit))
   provisos(Bits#(one_bit, 1));

   default_clock clk();
   default_reset rstn();

   parameter BUFR_DIVIDE = params.bufr_divide;
   parameter SIM_DEVICE  = params.sim_device;

   method       _write(I) enable((*inhigh*)en);
   method O     _read;

   port   CE = True;
   port   CLR = False;

   path(I, O);

   schedule _write SB _read;
   schedule _write C  _write;
   schedule _read  CF _read;
endmodule: vMkBUFR

module mkBUFR#(BUFRParams params)(Wire#(a))
   provisos(Bits#(a, sa));

   Vector#(sa, Wire#(Bit#(1))) _bufr <- replicateM(vMkBUFR(params));

   method a _read;
      return unpack(pack(readVReg(_bufr)));
   endmethod

   method Action _write(a x);
      writeVReg(_bufr, unpack(pack(x)));
   endmethod
endmodule

import "BVI" BUFR =
module vMkClockBUFR#(BUFRParams params)(ClockGenIfc);
   default_clock clk(I, (*unused*)GATE);
   default_reset no_reset;

   parameter BUFR_DIVIDE = params.bufr_divide;
   parameter SIM_DEVICE  = params.sim_device;

   port CE  = True;
   port CLR = False;

   path(I, O);

   output_clock gen_clk(O);
   same_family(clk, gen_clk);
endmodule

module mkClockBUFR#(BUFRParams params)(Clock);
   let _m <- vMkClockBUFR(params);
   return _m.gen_clk;
endmodule

import "BVI" BUFR =
module vMkClockBitBUFR#(BUFRParams params)(ReadOnly#(one_bit))
   provisos(Bits#(one_bit, 1));

   default_clock clk(I);
   default_reset no_reset;

   parameter BUFR_DIVIDE = params.bufr_divide;
   parameter SIM_DEVICE  = params.sim_device;

   port CE  = True;
   port CLR = False;

   path(I, O);

   method O _read;

   schedule _read CF _read;
endmodule

module mkClockBitBUFR#(BUFRParams params)(ReadOnly#(one_bit))
   provisos(Bits#(one_bit, 1));

   let _m <- vMkClockBitBUFR(params);
   return _m;
endmodule

////////////////////////////////////////////////////////////////////////////////
/// IBUFG
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String      capacitance;
   String      ibuf_delay_value;
   String      ibuf_low_pwr;
   String      iostandard;
} IBUFGParams deriving (Bits, Eq);

instance DefaultValue#(IBUFGParams);
   defaultValue = IBUFGParams {
      capacitance:           "DONT_CARE",
      ibuf_delay_value:      "0",
      ibuf_low_pwr:          "TRUE",
      iostandard:            "DEFAULT"
      };
endinstance

import "BVI" IBUFG =
module vMkIBUFG#(IBUFGParams params)(Wire#(one_bit))
   provisos(Bits#(one_bit, 1));

   default_clock clk();
   default_reset rstn();

   parameter CAPACITANCE      = params.capacitance;
   parameter IBUF_DELAY_VALUE = params.ibuf_delay_value;
   parameter IBUF_LOW_PWR     = params.ibuf_low_pwr;
   parameter IOSTANDARD       = params.iostandard;

   method      _write(I) enable((*inhigh*)en);
   method O    _read;

   path(I, O);

   schedule _write SB _read;
   schedule _write C  _write;
   schedule _read  CF _read;
endmodule: vMkIBUFG

module mkIBUFG#(IBUFGParams params)(Wire#(a))
   provisos(Bits#(a, sa));

   Vector#(sa, Wire#(Bit#(1))) _bufg <- replicateM(vMkIBUFG(params));

   method a _read;
      return unpack(pack(readVReg(_bufg)));
   endmethod

   method Action _write(a x);
      writeVReg(_bufg, unpack(pack(x)));
   endmethod
endmodule: mkIBUFG

import "BVI" IBUFG =
module vMkClockIBUFG#(IBUFGParams params)(ClockGenIfc);
   default_clock clk(I);
   default_reset no_reset;

   parameter CAPACITANCE      = params.capacitance;
   parameter IBUF_DELAY_VALUE = params.ibuf_delay_value;
   parameter IBUF_LOW_PWR     = params.ibuf_low_pwr;
   parameter IOSTANDARD       = params.iostandard;

   output_clock gen_clk(O);

   same_family(clk, gen_clk);
endmodule: vMkClockIBUFG

module mkClockIBUFG#(IBUFGParams params)(Clock);
   let _m <- vMkClockIBUFG(params);
   return _m.gen_clk;
endmodule: mkClockIBUFG

////////////////////////////////////////////////////////////////////////////////
/// IBUF
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String      capacitance;
   String      ibuf_delay_value;
   String      ibuf_low_pwr;
   String      ifd_delay_value;
   String      iostandard;
} IBUFParams deriving (Bits, Eq);

instance DefaultValue#(IBUFParams);
   defaultValue = IBUFParams {
      capacitance:           "DONT_CARE",
      ibuf_delay_value:      "0",
      ibuf_low_pwr:          "TRUE",
      ifd_delay_value:       "AUTO",
      iostandard:            "DEFAULT"
      };
endinstance

import "BVI" IBUF =
module vMkIBUF#(IBUFParams params)(Wire#(one_bit))
   provisos(Bits#(one_bit, 1));

   default_clock clk();
   default_reset rstn();

   parameter CAPACITANCE      = params.capacitance;
   parameter IBUF_DELAY_VALUE = params.ibuf_delay_value;
   parameter IBUF_LOW_PWR     = params.ibuf_low_pwr;
   parameter IFD_DELAY_VALUE  = params.ifd_delay_value;
   parameter IOSTANDARD       = params.iostandard;

   method      _write(I) enable((*inhigh*)en);
   method O    _read;

   path(I, O);

   schedule _write SB _read;
   schedule _write C  _write;
   schedule _read  CF _read;
endmodule: vMkIBUF

module mkIBUF#(IBUFParams params)(Wire#(a))
   provisos(Bits#(a, sa));

   Vector#(sa, Wire#(Bit#(1))) _bufg <- replicateM(vMkIBUF(params));

   method a _read;
      return unpack(pack(readVReg(_bufg)));
   endmethod

   method Action _write(a x);
      writeVReg(_bufg, unpack(pack(x)));
   endmethod
endmodule: mkIBUF

import "BVI" IBUF =
module vMkClockIBUF#(IBUFParams params)(ClockGenIfc);
   default_clock clk(I);
   default_reset no_reset;

   parameter CAPACITANCE      = params.capacitance;
   parameter IBUF_DELAY_VALUE = params.ibuf_delay_value;
   parameter IBUF_LOW_PWR     = params.ibuf_low_pwr;
   parameter IFD_DELAY_VALUE  = params.ifd_delay_value;
   parameter IOSTANDARD       = params.iostandard;

   path(I, O);

   output_clock gen_clk(O);
endmodule: vMkClockIBUF

module mkClockIBUF#(IBUFParams params)(Clock);
   let _m <- vMkClockIBUF(params);
   return _m.gen_clk;
endmodule: mkClockIBUF

import "BVI" IBUF =
module vMkResetIBUF#(IBUFParams params)(ResetGenIfc);
   default_clock no_clock;
   default_reset rstn(I);

   parameter CAPACITANCE      = params.capacitance;
   parameter IBUF_DELAY_VALUE = params.ibuf_delay_value;
   parameter IBUF_LOW_PWR     = params.ibuf_low_pwr;
   parameter IFD_DELAY_VALUE  = params.ifd_delay_value;
   parameter IOSTANDARD       = params.iostandard;

   path(I, O);

   output_reset gen_rst(O) clocked_by(no_clock);
endmodule: vMkResetIBUF

module mkResetIBUF#(IBUFParams params)(Reset);
   let _m <- vMkResetIBUF(params);
   return _m.gen_rst;
endmodule: mkResetIBUF


////////////////////////////////////////////////////////////////////////////////
/// IBUFDS
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String      capacitance;
   String      diff_term;
   String      dqs_bias;
   String      ibuf_delay_value;
   String      ibuf_low_pwr;
   String      ifd_delay_value;
   String      iostandard;
} IBUFDSParams deriving (Bits, Eq);

instance DefaultValue#(IBUFDSParams);
   defaultValue = IBUFDSParams {
      capacitance:             "DONT_CARE",
      diff_term:               "FALSE",
      dqs_bias:                "FALSE",
      ibuf_delay_value:        "0",
      ibuf_low_pwr:            "TRUE",
      ifd_delay_value:         "AUTO",
      iostandard:              "DEFAULT"
      };
endinstance

import "BVI" IBUFDS =
module vMkClockIBUFDS#(IBUFDSParams params, Clock clk_p, Clock clk_n)(ClockGenIfc);
   default_clock no_clock;
   default_reset no_reset;

   input_clock clk_p(I)  = clk_p;
   input_clock clk_n(IB) = clk_n;

   output_clock gen_clk(O);

   parameter CAPACITANCE      = params.capacitance;
   parameter DIFF_TERM        = params.diff_term;
   parameter DQS_BIAS         = params.dqs_bias;
   parameter IBUF_DELAY_VALUE = params.ibuf_delay_value;
   parameter IBUF_LOW_PWR     = params.ibuf_low_pwr;
   parameter IFD_DELAY_VALUE  = params.ifd_delay_value;
   parameter IOSTANDARD       = params.iostandard;

   path(I,  O);
   path(IB, O);

   same_family(clk_p, gen_clk);
endmodule: vMkClockIBUFDS

module mkClockIBUFDS#(IBUFDSParams params, Clock clk_p, Clock clk_n)(Clock);
   let _m <- vMkClockIBUFDS(params, clk_p, clk_n);
   return _m.gen_clk;
endmodule: mkClockIBUFDS

////////////////////////////////////////////////////////////////////////////////
/// IBUFGDS
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String      capacitance;
   String      diff_term;
   String      ibuf_delay_value;
   String      ibuf_low_pwr;
   String      iostandard;
} IBUFGDSParams deriving (Bits, Eq);

instance DefaultValue#(IBUFGDSParams);
   defaultValue = IBUFGDSParams {
      capacitance:             "DONT_CARE",
      diff_term:               "FALSE",
      ibuf_delay_value:        "0",
      ibuf_low_pwr:            "TRUE",
      iostandard:              "DEFAULT"
      };
endinstance

import "BVI" IBUFGDS =
module vMkClockIBUFGDS#(IBUFGDSParams params, Clock clk_p, Clock clk_n)(ClockGenIfc);
   default_clock no_clock;
   default_reset no_reset;

   input_clock clk_p(I)  = clk_p;
   input_clock clk_n(IB) = clk_n;

   output_clock gen_clk(O);

   parameter CAPACITANCE      = params.capacitance;
   parameter DIFF_TERM        = params.diff_term;
   parameter IBUF_DELAY_VALUE = params.ibuf_delay_value;
   parameter IBUF_LOW_PWR     = params.ibuf_low_pwr;
   parameter IOSTANDARD       = params.iostandard;

   path(I,  O);
   path(IB, O);

   same_family(clk_p, gen_clk);
endmodule: vMkClockIBUFGDS

module mkClockIBUFGDS#(IBUFGDSParams params, Clock clk_p, Clock clk_n)(Clock);
   let _m <- vMkClockIBUFGDS(params, clk_p, clk_n);
   return _m.gen_clk;
endmodule: mkClockIBUFGDS

////////////////////////////////////////////////////////////////////////////////
/// IBUFDS_GTXE1
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String      clkcm_cfg;
   String      clkrcv_trst;
   Bit#(10)    refclkout_dly;
} IBUFDS_GTXE1Params deriving (Bits, Eq);

instance DefaultValue#(IBUFDS_GTXE1Params);
   defaultValue = IBUFDS_GTXE1Params {
      clkcm_cfg:          "TRUE",
      clkrcv_trst:        "TRUE",
      refclkout_dly:      0
      };
endinstance

interface GTXE1ClockGenIfc;
   interface Clock gen_clk;
   interface Clock gen_clk_div2;
endinterface

import "BVI" IBUFDS_GTXE1 =
module vMkClockIBUFDS_GTXE1#(IBUFDS_GTXE1Params params, Bool enable, Clock clk_p, Clock clk_n)(GTXE1ClockGenIfc);
   default_clock no_clock;
   default_reset no_reset;

   input_clock clk_p(I)  = clk_p;
   input_clock clk_n(IB) = clk_n;

   port CEB = pack(!enable);

   output_clock gen_clk(O);
   output_clock gen_clk_div2(ODIV2);

   parameter CLKCM_CFG     = params.clkcm_cfg;
   parameter CLKRCV_TRST   = params.clkrcv_trst;
   parameter REFCLKOUT_DLY = (Bit#(10))'(params.refclkout_dly);

   path(I,  O);
   path(IB, O);
   path(I,  ODIV2);
   path(IB, ODIV2);

   same_family(clk_p, gen_clk);
endmodule: vMkClockIBUFDS_GTXE1

module mkClockIBUFDS_GTXE1#(IBUFDS_GTXE1Params params, Bool enable, Clock clk_p, Clock clk_n)(Clock);
   let _m <- vMkClockIBUFDS_GTXE1(params, enable, clk_p, clk_n);
   return _m.gen_clk;
endmodule: mkClockIBUFDS_GTXE1

module mkClockIBUFDS_GTXE1_div2#(IBUFDS_GTXE1Params params, Bool enable, Clock clk_p, Clock clk_n)(Clock);
   let _m <- vMkClockIBUFDS_GTXE1(params, enable, clk_p, clk_n);
   return _m.gen_clk_div2;
endmodule: mkClockIBUFDS_GTXE1_div2

module mkClockIBUFDS_GTXE1_both#(IBUFDS_GTXE1Params params, Bool enable, Clock clk_p, Clock clk_n)(Vector#(2, Clock));
   let _m <- vMkClockIBUFDS_GTXE1(params, enable, clk_p, clk_n);
   Vector#(2, Clock) _v = newVector;
   _v[0] = _m.gen_clk;
   _v[1] = _m.gen_clk_div2;
   return _v;
endmodule

////////////////////////////////////////////////////////////////////////////////
/// IBUFDS_GTE2
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String      clkcm_cfg;
   String      clkrcv_trst;
   Bit#(2)     clkswing_cfg;
} IBUFDS_GTE2Params deriving (Bits, Eq);

instance DefaultValue#(IBUFDS_GTE2Params);
   defaultValue = IBUFDS_GTE2Params {
      clkcm_cfg:          "TRUE",
      clkrcv_trst:        "TRUE",
      clkswing_cfg:       2'b11
      };
endinstance

interface GTE2ClockGenIfc;
   interface Clock gen_clk;
   interface Clock gen_clk_div2;
endinterface

import "BVI" IBUFDS_GTE2 =
module vMkClockIBUFDS_GTE2#(IBUFDS_GTE2Params params, Bool enable, Clock clk_p, Clock clk_n)(GTE2ClockGenIfc);
   default_clock no_clock;
   default_reset no_reset;

   input_clock clk_p(I)  = clk_p;
   input_clock clk_n(IB) = clk_n;

   port CEB = pack(!enable);

   output_clock gen_clk(O);
   output_clock gen_clk_div2(ODIV2);

   parameter CLKCM_CFG      = params.clkcm_cfg;
   parameter CLKRCV_TRST    = params.clkrcv_trst;
   parameter CLKSWING_CFG   = (Bit#(2))'(params.clkswing_cfg);

   path(I,  O);
   path(IB, O);
   path(I,  ODIV2);
   path(IB, ODIV2);

   same_family(clk_p, gen_clk);
endmodule: vMkClockIBUFDS_GTE2

module mkClockIBUFDS_GTE2#(IBUFDS_GTE2Params params, Bool enable, Clock clk_p, Clock clk_n)(Clock);
   let _m <- vMkClockIBUFDS_GTE2(params, enable, clk_p, clk_n);
   return _m.gen_clk;
endmodule: mkClockIBUFDS_GTE2

module mkClockIBUFDS_GTE2_div2#(IBUFDS_GTE2Params params, Bool enable, Clock clk_p, Clock clk_n)(Clock);
   let _m <- vMkClockIBUFDS_GTE2(params, enable, clk_p, clk_n);
   return _m.gen_clk_div2;
endmodule: mkClockIBUFDS_GTE2_div2

module mkClockIBUFDS_GTE2_both#(IBUFDS_GTE2Params params, Bool enable, Clock clk_p, Clock clk_n)(Vector#(2, Clock));
   let _m <- vMkClockIBUFDS_GTE2(params, enable, clk_p, clk_n);
   Vector#(2, Clock) _v = newVector;
   _v[0] = _m.gen_clk;
   _v[1] = _m.gen_clk_div2;
   return _v;
endmodule

////////////////////////////////////////////////////////////////////////////////
/// IBUFDS_GTE3
////////////////////////////////////////////////////////////////////////////////
interface GTE3ClockGenIfc;
   interface Clock gen_clk;
   interface Clock gen_clk_div2;
endinterface

import "BVI" IBUFDS_GTE3 =
module vMkClockIBUFDS_GTE3#(Bool enable, Clock clk_p, Clock clk_n)(GTE3ClockGenIfc);
   default_clock no_clock;
   default_reset no_reset;

   input_clock clk_p(I)  = clk_p;
   input_clock clk_n(IB) = clk_n;

   port CEB = pack(!enable);

   output_clock gen_clk(O);
   output_clock gen_clk_div2(ODIV2);

   // Reserved, always set to 1'b0
   //parameter REFCLK_EN_TX_PATH = 1'b0;

   // Configured ODIV2 output:
   //   2'b00: ODIV2 = O
   //   2'b01: ODIV2 = Divide-by-2 version of O
   //   2'b10: ODIV2 = 1'b0
   //   2'b11: Reserved
   //parameter REFCLK_HROW_CK_SEL = 2'b00

   // Reserved, use the recommended value from the wizard
   //parameter REFCLK_ICNTL_RX = 2'b00;

   path(I,  O);
   path(IB, O);
   path(I,  ODIV2);
   path(IB, ODIV2);

   same_family(clk_p, gen_clk);
   // Only true if ODIV2 = O
   same_family(clk_p, gen_clk_div2);
endmodule: vMkClockIBUFDS_GTE3

module mkClockIBUFDS_GTE3#(Bool enable, Clock clk_p, Clock clk_n)(Vector#(2, Clock));
   let _m <- vMkClockIBUFDS_GTE3(enable, clk_p, clk_n);
   Vector#(2, Clock) _v = newVector;
   _v[0] = _m.gen_clk;
   _v[1] = _m.gen_clk_div2;
   return _v;
endmodule

////////////////////////////////////////////////////////////////////////////////
/// IBUFDS_GTHE1
////////////////////////////////////////////////////////////////////////////////
import "BVI" IBUFDS_GTHE1 =
module vMkClockIBUFDS_GTHE1#(Clock clk_p, Clock clk_n)(ClockGenIfc);
   default_clock no_clock;
   default_reset no_reset;

   input_clock clk_p(I)  = clk_p;
   input_clock clk_n(IB) = clk_n;

   output_clock gen_clk(O);

   path(I,  O);
   path(IB, O);

   same_family(clk_p, gen_clk);
endmodule: vMkClockIBUFDS_GTHE1

module mkClockIBUFDS_GTHE1#(Clock clk_p, Clock clk_n)(Clock);
   let _m <- vMkClockIBUFDS_GTHE1(clk_p, clk_n);
   return _m.gen_clk;
endmodule: mkClockIBUFDS_GTHE1

////////////////////////////////////////////////////////////////////////////////
/// OBUF
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String      capacitance;
   Integer     drive;
   String      iostandard;
   String      slew;
} OBUFParams;

instance DefaultValue#(OBUFParams);
   defaultValue = OBUFParams {
      capacitance:          "DONT_CARE",
      drive:                12,
      iostandard:           "DEFAULT",
      slew:                 "SLOW"
      };
endinstance

import "BVI" OBUF =
module vMkOBUF#(OBUFParams params)(Wire#(one_bit))
   provisos(Bits#(one_bit, 1));

   default_clock clk();
   default_reset rstn();

   parameter CAPACITANCE     = params.capacitance;
   parameter DRIVE           = params.drive;
   parameter IOSTANDARD      = params.iostandard;
   parameter SLEW            = params.slew;

   method        _write(I) enable((*inhigh*)en);
   method O      _read;

   path(I, O);

   schedule _write SB _read;
   schedule _write C  _write;
   schedule _read  CF _read;
endmodule: vMkOBUF

module mkOBUF#(OBUFParams params)(Wire#(a))
   provisos(Bits#(a, sa));

   Vector#(sa, Wire#(Bit#(1))) _obuf <- replicateM(vMkOBUF(params));

   method a _read;
      return unpack(pack(readVReg(_obuf)));
   endmethod

   method Action _write(a x);
      writeVReg(_obuf, unpack(pack(x)));
   endmethod
endmodule: mkOBUF

////////////////////////////////////////////////////////////////////////////////
/// OBUFDS
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String      capacitance;
   String      iostandard;
   String      slew;
} OBUFDSParams deriving (Bits, Eq);

instance DefaultValue#(OBUFDSParams);
   defaultValue = OBUFDSParams {
      capacitance:          "DONT_CARE",
      iostandard:           "DEFAULT",
      slew:                 "SLOW"
      };
endinstance

interface DiffClock;
   interface Clock p;
   interface Clock n;
endinterface

import "BVI" OBUFDS =
module vMkClockOBUFDS#(OBUFDSParams params)(DiffClock);
   default_clock clk(I);
   default_reset no_reset;

   output_clock p(O);
   output_clock n(OB);

   parameter CAPACITANCE     = params.capacitance;
   parameter IOSTANDARD      = params.iostandard;
   parameter SLEW            = params.slew;

   path(I, O);
   path(I, OB);

   same_family(clk, p);
endmodule: vMkClockOBUFDS

module mkClockOBUFDS#(OBUFDSParams params)(DiffClock);
   let _m <- vMkClockOBUFDS(params);
   return _m;
endmodule: mkClockOBUFDS

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Double Data Rate Cells (DDR)
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// ODDR
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String  ddr_clk_edge;
   a       init;
   String  srtype;
   } ODDRParams#(type a) deriving (Bits, Eq);

instance DefaultValue#(ODDRParams#(a))
   provisos(DefaultValue#(a));
   defaultValue = ODDRParams {
      ddr_clk_edge: "OPPOSITE_EDGE",
      init:         defaultValue,
      srtype:       "SYNC"
      };
endinstance

(* always_ready, always_enabled *)
interface ODDR#(type a);
   method    a            q();
   method    Action       s(Bool i);
   method    Action       ce(Bool i);
   method    Action       d1(a i);
   method    Action       d2(a i);
endinterface: ODDR

import "BVI" ODDR =
module vMkODDR#(ODDRParams#(a) params)(ODDR#(a))
   provisos(Bits#(a, 1), DefaultValue#(a));

   if (params.srtype != "SYNC" &&
       params.srtype != "ASYNC")
      error("There are only two modes of reset of the ODDR cell SYNC and ASYNC.  Please specify one of those.");

   if (params.ddr_clk_edge != "OPPOSITE_EDGE" &&
       params.ddr_clk_edge != "SAME_EDGE")
      error("There are only two modes of operation of the ODDR cell OPPOSITE_EDGE and SAME_EDGE.  Please specify one of those.");

   default_clock clk(C);
   default_reset rst(R);

   parameter DDR_CLK_EDGE = params.ddr_clk_edge;
   parameter INIT         = pack(params.init);
   parameter SRTYPE       = params.srtype;

   method Q   q reset_by(no_reset);
   method     s(S)     enable((*inhigh*)en0) reset_by(no_reset);
   method     ce(CE)   enable((*inhigh*)en1) reset_by(no_reset);
   method     d1(D1)   enable((*inhigh*)en2) reset_by(no_reset);
   method     d2(D2)   enable((*inhigh*)en3) reset_by(no_reset);

   schedule (q)      SB (d1, d2);
   schedule (d1)     CF (d2);
   schedule (d1)     C  (d1);
   schedule (d2)     C  (d2);
   schedule (q)      CF (q);
   schedule (ce, s)  CF (ce, s);
   schedule (ce, s)  SB (d1, d2, q);
endmodule: vMkODDR

module mkODDR#(ODDRParams#(a) params)(ODDR#(a))
   provisos(Bits#(a, sa), DefaultValue#(a));

   Reset reset <- invertCurrentReset;

   Vector#(sa, ODDRParams#(Bit#(1))) _params = ?;
   for(Integer i = 0; i < valueof(sa); i = i + 1) begin
      _params[i].ddr_clk_edge = params.ddr_clk_edge;
      _params[i].init         = pack(params.init)[i];
      _params[i].srtype       = params.srtype;
   end

   Vector#(sa, ODDR#(Bit#(1))) _oddr  = ?;
   for(Integer i = 0; i < valueof(sa); i = i + 1) begin
      _oddr[i] <- vMkODDR(_params[i], reset_by reset);
   end

   function Bit#(1) getQ(ODDR#(Bit#(1)) ddr);
      return ddr.q;
   endfunction

   method a q();
      return unpack(pack(map(getQ, _oddr)));
   endmethod

   method Action s(Bool x);
      for(Integer i = 0; i < valueof(sa); i = i + 1) begin
         _oddr[i].s(x);
      end
   endmethod

   method Action ce(Bool x);
      for(Integer i = 0; i < valueof(sa); i = i + 1) begin
         _oddr[i].ce(x);
      end
   endmethod

   method Action d1(a x);
      for(Integer i = 0; i < valueof(sa); i = i + 1) begin
         _oddr[i].d1(pack(x)[i]);
      end
   endmethod

   method Action d2(a x);
      for(Integer i = 0; i < valueof(sa); i = i + 1) begin
         _oddr[i].d2(pack(x)[i]);
      end
   endmethod

endmodule: mkODDR

import "BVI" ODDR =
module vMkClockODDR#(ODDRParams#(Bit#(1)) params, Bit#(1) d1, Bit#(1) d2)(ClockGenIfc);

   Reset reset <- invertCurrentReset;

   default_clock clk(C);
   default_reset rst(R) = reset;

   output_clock  gen_clk(Q);

   parameter DDR_CLK_EDGE = params.ddr_clk_edge;
   parameter INIT         = params.init;
   parameter SRTYPE       = params.srtype;

   port D1 = d1;
   port D2 = d2;
   port CE = True;
   port S  = False;

endmodule: vMkClockODDR

module mkClockODDR#(ODDRParams#(Bit#(1)) params, Bit#(1) d1, Bit#(1) d2)(Clock);
   let _m <- vMkClockODDR(params, d1, d2);
   return _m.gen_clk;
endmodule: mkClockODDR

////////////////////////////////////////////////////////////////////////////////
/// IDDR
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String  ddr_clk_edge;
   a       init_q1;
   a       init_q2;
   String  srtype;
   } IDDRParams#(type a) deriving (Bits, Eq);

instance DefaultValue#(IDDRParams#(a))
   provisos(DefaultValue#(a));
   defaultValue = IDDRParams {
      ddr_clk_edge: "OPPOSITE_EDGE",
      init_q1:      defaultValue,
      init_q2:      defaultValue,
      srtype:       "ASYNC"
      };
endinstance

(* always_ready, always_enabled *)
interface VIDDR#(type a);
   method    a           q1();
   method    a           q2();
   method    Action      s(Bool i);
   method    Action      ce(Bool i);
   method    Action      d(a i);
endinterface: VIDDR

(* always_ready, always_enabled *)
interface IDDR#(type a);
   method    a           q1();
   method    a           q2();
   method    Action      s(Bool i);
   method    Action      ce(Bool i);
   method    Action      d(a i);
endinterface: IDDR

import "BVI" IDDR =
module vMkIDDR#(IDDRParams#(a) params)(VIDDR#(a))
   provisos(Bits#(a, 1), DefaultValue#(a));

   if (params.srtype != "SYNC" &&
       params.srtype != "ASYNC")
      error("There are only two modes of reset of the ODDR cell SYNC and ASYNC.  Please specify one of those.");

   if (params.ddr_clk_edge != "OPPOSITE_EDGE" &&
       params.ddr_clk_edge != "SAME_EDGE" &&
       params.ddr_clk_edge != "SAME_EDGE_PIPELINED")
      error("There are only three modes of operation of the ODDR cell OPPOSITE_EDGE, SAME_EDGE, and SAME_EDGE_PIPELINED.  Please specify one of those.");

   default_clock clk(C);
   default_reset rst(R);

   parameter DDR_CLK_EDGE = params.ddr_clk_edge;
   parameter INIT_Q1      = pack(params.init_q1);
   parameter INIT_Q2      = pack(params.init_q2);
   parameter SRTYPE       = params.srtype;

   method Q1  q1 reset_by(no_reset);
   method Q2  q2 reset_by(no_reset);
   method     s(S)    enable((*inhigh*)en0) reset_by(no_reset);
   method     ce(CE)  enable((*inhigh*)en1) reset_by(no_reset);
   method     d(D)    enable((*inhigh*)en2) reset_by(no_reset);

   schedule (q1, q2)   SB (d);
   schedule (d)        C  (d);
   schedule (q1, q2)   CF (q1, q2);
   schedule (ce, s)    CF (ce, s);
   schedule (ce, s)    SB (d, q1, q2);

endmodule: vMkIDDR

module mkIDDR#(IDDRParams#(a) params)(IDDR#(a))
   provisos(Bits#(a, sa), DefaultValue#(a));

   Reset reset <- invertCurrentReset;

   Vector#(sa, IDDRParams#(Bit#(1))) _params = ?;
   for(Integer i = 0; i < valueof(sa); i = i + 1) begin
      _params[i].ddr_clk_edge = params.ddr_clk_edge;
      _params[i].init_q1      = pack(params.init_q1)[i];
      _params[i].init_q2      = pack(params.init_q2)[i];
      _params[i].srtype       = params.srtype;
   end

   Vector#(sa, VIDDR#(Bit#(1))) _iddr  = ?;
   for(Integer i = 0; i < valueof(sa); i = i + 1) begin
      _iddr[i] <- vMkIDDR(_params[i], reset_by reset);
   end

   function Bit#(1) getQ1(VIDDR#(Bit#(1)) ddr);
      return ddr.q1;
   endfunction

   function Bit#(1) getQ2(VIDDR#(Bit#(1)) ddr);
      return ddr.q2;
   endfunction

   method a q1();
      return unpack(pack(map(getQ1, _iddr)));
   endmethod

   method a q2();
      return unpack(pack(map(getQ2, _iddr)));
   endmethod

   method Action s(Bool x);
      for(Integer i = 0; i < valueof(sa); i = i + 1) begin
         _iddr[i].s(x);
      end
   endmethod

   method Action ce(Bool x);
      for(Integer i = 0; i < valueof(sa); i = i + 1) begin
         _iddr[i].ce(x);
      end
   endmethod

   method Action d(a x);
      for(Integer i = 0; i < valueof(sa); i = i + 1) begin
         _iddr[i].d(pack(x)[i]);
      end
   endmethod

endmodule: mkIDDR

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Delay Cells
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// IDELAYCTRL
////////////////////////////////////////////////////////////////////////////////
(* always_ready, always_enabled *)
interface IDELAYCTRL;
   method    Bool     rdy;
endinterface: IDELAYCTRL

import "BVI" IDELAYCTRL =
module vMkIDELAYCTRL#(Integer rst_delay)(IDELAYCTRL);
   Reset reset   <- invertCurrentReset;
   Clock c       <- exposeCurrentClock;
   Reset delayed <- mkAsyncReset(rst_delay, reset, c);

   default_clock clk(REFCLK);
   default_reset rst(RST) = delayed;

   method RDY rdy  reset_by(no_reset);

   schedule rdy CF rdy;
endmodule: vMkIDELAYCTRL

module mkIDELAYCTRL#(Integer rst_delay)(IDELAYCTRL);
   let _m <- vMkIDELAYCTRL(rst_delay);
   return _m;
endmodule: mkIDELAYCTRL


////////////////////////////////////////////////////////////////////////////////
/// IDELAY (Virtex-4 ?)
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String  iobdelay_type;
   Integer iobdelay_value;
   } IDELAYParams;

instance DefaultValue#(IDELAYParams);
   defaultValue = IDELAYParams {
      iobdelay_type:  "DEFAULT",
      iobdelay_value: 0
      };
endinstance

interface VIDELAY#(type a);
   (* always_enabled *)
   method   Action       i(a i);
   (* always_ready *)
   method   Action       inc(Bool inc_not_dec);
   (* always_ready *)
   method   a            o;
endinterface: VIDELAY

interface IDELAY#(type a);
   (* always_enabled *)
   method   Action       i(a i);
   (* always_ready *)
   method   Action       inc(Bool inc_not_dec);
   (* always_ready *)
   method   a            o;
endinterface: IDELAY


import "BVI" IDELAY =
module vMkIDELAY#(IDELAYParams params)(VIDELAY#(a))
   provisos(Bits#(a, 1));

   if (params.iobdelay_value < 0 || params.iobdelay_value > 63)
      error("There are only 63 total taps on the IDELAY cell.  Please specify a quantity between 0 and 63.");

   if (params.iobdelay_type != "DEFAULT" &&
       params.iobdelay_type != "FIXED" &&
       params.iobdelay_type != "VARIABLE")
      error("There are only three types of tap delay DEFAULT, FIXED, and VARIABLE.  Please specify one of these.");


   default_clock clk(C);
   default_reset rst(RST);

   parameter IOBDELAY_TYPE  = params.iobdelay_type;
   parameter IOBDELAY_VALUE = params.iobdelay_value;

   method O   o        reset_by(no_reset);
   method     i(I)     enable((*inhigh*)en0) reset_by(no_reset);
   method     inc(INC) enable(CE) reset_by(no_reset);

   path(I, O);

   schedule i   SB o;
   schedule i   C  i;
   schedule o   CF o;
   schedule inc C  inc;
   schedule inc CF (i, o);

endmodule: vMkIDELAY

module mkIDELAY#(IDELAYParams params)(IDELAY#(a))
   provisos(Bits#(a, sa));

   Reset reset <- invertCurrentReset;

   Vector#(sa, IDELAYParams) _params = ?;
   for(Integer k = 0; k < valueof(sa); k = k + 1) begin
      _params[k].iobdelay_type  = params.iobdelay_type;
      _params[k].iobdelay_value = params.iobdelay_value;
   end

   Vector#(sa, VIDELAY#(Bit#(1))) _idelay = ?;
   for(Integer k = 0; k < valueof(sa); k = k + 1) begin
      _idelay[k] <- vMkIDELAY(_params[k], reset_by reset);
   end

   function Bit#(1) getO(VIDELAY#(Bit#(1)) idly);
      return idly.o;
   endfunction

   method a o();
      return unpack(pack(map(getO, _idelay)));
   endmethod

   method Action i(a x);
      for(Integer k = 0; k < valueof(sa); k = k + 1) begin
         _idelay[k].i(pack(x)[k]);
      end
   endmethod

   method Action inc(Bool inc_not_dec);
      for(Integer k = 0; k < valueof(sa); k = k + 1) begin
         _idelay[k].inc(inc_not_dec);
      end
   endmethod

endmodule: mkIDELAY


////////////////////////////////////////////////////////////////////////////////
/// IODELAY
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String   delay_source;
   String   high_performance_mode;
   String   idelay_type;
   Integer  idelay_value;
   Integer  odelay_value;
   Integer  refclk_frequency; // Real
   String   signal_pattern;
   } IODELAYParams deriving (Bits, Eq);

instance DefaultValue#(IODELAYParams);
   defaultValue = IODELAYParams {
      delay_source:          "DATAIN",
      high_performance_mode: "TRUE",
      idelay_type:           "DEFAULT",
      idelay_value:          0,
      odelay_value:          0,
      refclk_frequency:      200,
      signal_pattern:        "DATA"
      };
endinstance

typedef struct {
   String   delay_source;
   String   high_performance_mode;
   String   idelay_type;
   Integer  idelay_value;
   Integer  odelay_value;
   Integer  refclk_frequency; // Real
   String   signal_pattern;
   } ClockIODELAYParams deriving (Bits, Eq);

instance DefaultValue#(ClockIODELAYParams);
   defaultValue = ClockIODELAYParams {
      delay_source:          "I",
      high_performance_mode: "TRUE",
      idelay_type:           "FIXED",
      idelay_value:          0,
      odelay_value:          0,
      refclk_frequency:      200,
      signal_pattern:        "CLOCK"
      };
endinstance

interface VIODELAY#(type a);
   (* always_enabled *)
   method Action     idatain(a i);
   (* always_enabled *)
   method Action     odatain(a i);
   (* always_ready *)
   method a          dataout;
   (* always_enabled *)
   method Action     datain(a i);
   (* always_enabled *)
   method Action     t(Bool i);
   (* always_ready *)
   method Action     inc(Bool inc_not_dec);
endinterface: VIODELAY

interface IODELAY#(type a);
   (* always_enabled *)
   method Action     idatain(a i);
   (* always_enabled *)
   method Action     odatain(a i);
   (* always_ready *)
   method a          dataout;
   (* always_enabled *)
   method Action     datain(a i);
   (* always_enabled *)
   method Action     t(Bool i);
   (* always_ready *)
   method Action     inc(Bool inc_not_dec);
endinterface: IODELAY

import "BVI" IODELAY =
module vMkIODELAY#(IODELAYParams params)(VIODELAY#(a))
   provisos(Bits#(a, 1));

   if (params.idelay_type != "DEFAULT" &&
       params.idelay_type != "FIXED" &&
       params.idelay_type != "VARIABLE")
      error("There are only three types of IDELAY_TYPE: DEFAULT, FIXED, and VARIABLE.  Please specify one of those.");

   if (params.idelay_value < 0 || params.idelay_value > 63)
      error("There are only 63 total taps on the IODELAY cell.  Please specify a quantity for IDELAY_VALUE between 0 and 63.");

   if (params.odelay_value < 0 || params.odelay_value > 63)
      error("There are only 63 total taps on the IODELAY cell.  Please specify a quantity for ODELAY_VALUE between 0 and 63.");

   if (params.high_performance_mode != "FALSE" &&
       params.high_performance_mode != "TRUE")
      error("You must specify TRUE or FALSE for HIGH_PERFORMANCE_MODE.");

   if (params.signal_pattern != "DATA" &&
       params.signal_pattern != "CLOCK")
      error("There are only two settings for SIGNAL_PATTERN: DATA and CLOCK.  Please specify one of those.");

   if (params.refclk_frequency < 190 || params.refclk_frequency > 210)
      error("The IDELAYCTRL reference clock frequency must be between 190 MHz and 210 MHz.");

   if (params.delay_source != "I" &&
       params.delay_source != "O" &&
       params.delay_source != "IO" &&
       params.delay_source != "DATAIN")
      error("There are only four valid settings for DELAY_SRC: I, O, IO, DATAIN.  Please specify one of those.");

   default_clock clk(C);
   default_reset rst(RST);

   parameter IDELAY_TYPE           = params.idelay_type;
   parameter IDELAY_VALUE          = params.idelay_value;
   parameter ODELAY_VALUE          = params.odelay_value;
   parameter HIGH_PERFORMANCE_MODE = params.high_performance_mode;
   parameter SIGNAL_PATTERN        = params.signal_pattern;
   parameter REFCLK_FREQUENCY      = params.refclk_frequency;
   parameter DELAY_SRC             = params.delay_source;

   method         idatain(IDATAIN)   enable((*inhigh*)en0)  reset_by(no_reset);
   method         odatain(ODATAIN)   enable((*inhigh*)en1)  reset_by(no_reset);
   method DATAOUT dataout            reset_by(no_reset);
   method         datain(DATAIN)     enable((*inhigh*)en2)  reset_by(no_reset);
   method         t(T)               enable((*inhigh*)en3)  reset_by(no_reset);
   method         inc(INC)           enable(CE)             reset_by(no_reset);

   path (IDATAIN, DATAOUT);
   path (ODATAIN, DATAOUT);
   path (DATAIN,  DATAOUT);

      schedule (idatain, odatain, datain) CF (idatain, odatain, datain);
      schedule dataout CF dataout;
      schedule (idatain, odatain, datain) SB (dataout);
      schedule t  SB (idatain, odatain, datain, dataout);
      schedule inc SB (idatain, odatain, datain, dataout);
      schedule t C t;
      schedule inc C inc;
      schedule t CF inc;

endmodule: vMkIODELAY

module mkIODELAY#(IODELAYParams params)(IODELAY#(a))
   provisos(Bits#(a, sa));

   Reset reset <- invertCurrentReset;

   Vector#(sa, IODELAYParams) _params = ?;
   for(Integer k = 0; k < valueof(sa); k = k + 1) begin
      _params[k].idelay_type           = params.idelay_type;
      _params[k].idelay_value          = params.idelay_value;
      _params[k].odelay_value          = params.odelay_value;
      _params[k].high_performance_mode = params.high_performance_mode;
      _params[k].signal_pattern        = params.signal_pattern;
      _params[k].refclk_frequency      = params.refclk_frequency;
      _params[k].delay_source          = params.delay_source;
   end

   Vector#(sa, VIODELAY#(Bit#(1))) _iodelay = ?;
   for(Integer k = 0; k < valueof(sa); k = k + 1) begin
      _iodelay[k] <- vMkIODELAY(_params[k], reset_by reset);
   end

   function Bit#(1) getDataOut(VIODELAY#(Bit#(1)) iodly);
      return iodly.dataout;
   endfunction

   method Action idatain(a i);
      for(Integer k = 0; k < valueof(sa); k = k + 1) begin
         _iodelay[k].idatain(pack(i)[k]);
      end
   endmethod

   method Action odatain(a i);
      for(Integer k = 0; k < valueof(sa); k = k + 1) begin
         _iodelay[k].odatain(pack(i)[k]);
      end
   endmethod

   method a dataout;
      return unpack(pack(map(getDataOut, _iodelay)));
   endmethod

   method Action datain(a i);
      for(Integer k = 0; k < valueof(sa); k = k + 1) begin
         _iodelay[k].datain(pack(i)[k]);
      end
   endmethod

   method Action t(Bool i);
      for(Integer k = 0; k < valueof(sa); k = k + 1) begin
         _iodelay[k].t(i);
      end
   endmethod

   method Action inc(Bool inc_not_dec);
      for(Integer k = 0; k < valueof(sa); k = k + 1) begin
         _iodelay[k].inc(inc_not_dec);
      end
   endmethod

endmodule: mkIODELAY


import "BVI" IODELAY =
module vMkClockIODELAY#(ClockIODELAYParams params)(ClockGenIfc);
   if (params.idelay_type != "DEFAULT" &&
       params.idelay_type != "FIXED" &&
       params.idelay_type != "VARIABLE")
      error("There are only three types of IDELAY_TYPE: DEFAULT, FIXED, and VARIABLE.  Please specify one of those.");

   if (params.idelay_value < 0 || params.idelay_value > 63)
      error("There are only 63 total taps on the IODELAY cell.  Please specify a quantity for IDELAY_VALUE between 0 and 63.");

   if (params.odelay_value < 0 || params.odelay_value > 63)
      error("There are only 63 total taps on the IODELAY cell.  Please specify a quantity for ODELAY_VALUE between 0 and 63.");

   if (params.high_performance_mode != "FALSE" &&
       params.high_performance_mode != "TRUE")
      error("You must specify TRUE or FALSE for HIGH_PERFORMANCE_MODE.");

   if (params.signal_pattern != "DATA" &&
       params.signal_pattern != "CLOCK")
      error("There are only two settings for SIGNAL_PATTERN: DATA and CLOCK.  Please specify one of those.");

   if (params.refclk_frequency < 190 || params.refclk_frequency > 210)
      error("The IDELAYCTRL reference clock frequency must be between 190 MHz and 210 MHz.");

   if (params.delay_source != "I" &&
       params.delay_source != "O" &&
       params.delay_source != "IO" &&
       params.delay_source != "DATAIN")
      error("There are only four valid settings for DELAY_SRC: I, O, IO, DATAIN.  Please specify one of those.");

   default_clock clk(IDATAIN);
   default_reset rst();

   parameter IDELAY_TYPE           = params.idelay_type;
   parameter IDELAY_VALUE          = params.idelay_value;
   parameter ODELAY_VALUE          = params.odelay_value;
   parameter HIGH_PERFORMANCE_MODE = params.high_performance_mode;
   parameter SIGNAL_PATTERN        = params.signal_pattern;
   parameter REFCLK_FREQUENCY      = params.refclk_frequency;
   parameter DELAY_SRC             = params.delay_source;

   port ODATAIN = 0;
   port DATAIN  = 0;
   port C       = 0;
   port T       = 0;
   port CE      = 0;
   port INC     = 0;
   port RST     = 0;

   output_clock gen_clk(DATAOUT);

endmodule: vMkClockIODELAY

module mkClockIODELAY#(ClockIODELAYParams params)(Clock);
   (* hide *)
   let _m <- vMkClockIODELAY(params);
   return _m.gen_clk;
endmodule: mkClockIODELAY

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Clock Generators
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// PLL_ADV
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String      bandwidth;
   String      clkfbout_deskew_adjust;
   String      clkout0_deskew_adjust;
   String      clkout1_deskew_adjust;
   String      clkout2_deskew_adjust;
   String      clkout3_deskew_adjust;
   String      clkout4_deskew_adjust;
   String      clkout5_deskew_adjust;
   Integer     clkfbout_mult;
   Real        clkfbout_phase;
   Real        clkin1_period;
   Real        clkin2_period;
   Integer     clkout0_divide;
   Real        clkout0_duty_cycle;
   Real        clkout0_phase;
   Integer     clkout1_divide;
   Real        clkout1_duty_cycle;
   Real        clkout1_phase;
   Integer     clkout2_divide;
   Real        clkout2_duty_cycle;
   Real        clkout2_phase;
   Integer     clkout3_divide;
   Real        clkout3_duty_cycle;
   Real        clkout3_phase;
   Integer     clkout4_divide;
   Real        clkout4_duty_cycle;
   Real        clkout4_phase;
   Integer     clkout5_divide;
   Real        clkout5_duty_cycle;
   Real        clkout5_phase;
   String      compensation;
   Integer     divclk_divide;
   String      en_rel;
   String      pll_pmcd_mode;
   Real        ref_jitter;
   String      reset_on_loss_of_lock;
   String      rst_deassert_clk;
   } PLLParams deriving (Bits, Eq);

instance DefaultValue#(PLLParams);
   defaultValue = PLLParams {
      bandwidth:              "OPTIMIZED", // HIGH, LOW, OPTIMIZED
      clkfbout_deskew_adjust: "NONE", // NONE, PPC
      clkout0_deskew_adjust:  "NONE", // NONE, PPC
      clkout1_deskew_adjust:  "NONE", // NONE, PPC
      clkout2_deskew_adjust:  "NONE", // NONE, PPC
      clkout3_deskew_adjust:  "NONE", // NONE, PPC
      clkout4_deskew_adjust:  "NONE", // NONE, PPC
      clkout5_deskew_adjust:  "NONE", // NONE, PPC
      clkfbout_mult:          1, // 1 - 74
      clkfbout_phase:         0.0,
      clkin1_period:          0.000,
      clkin2_period:          0.000,
      clkout0_divide:         1,
      clkout0_duty_cycle:     0.5,
      clkout0_phase:          0.0,
      clkout1_divide:         1,
      clkout1_duty_cycle:     0.5,
      clkout1_phase:          0.0,
      clkout2_divide:         1,
      clkout2_duty_cycle:     0.5,
      clkout2_phase:          0.0,
      clkout3_divide:         1,
      clkout3_duty_cycle:     0.5,
      clkout3_phase:          0.0,
      clkout4_divide:         1,
      clkout4_duty_cycle:     0.5,
      clkout4_phase:          0.0,
      clkout5_divide:         1,
      clkout5_duty_cycle:     0.5,
      clkout5_phase:          0.0,
      compensation:           "SYSTEM_SYNCHRONOUS", // SOURCE_SYNCHRONOUS, INTERNAL, EXTERNAL, DCM2PLL, PLL2DCM
      divclk_divide:          1,
      en_rel:                 "FALSE", // TRUE, FALSE
      pll_pmcd_mode:          "FALSE", // TRUE, FALSE
      ref_jitter:             0.100,
      reset_on_loss_of_lock:  "FALSE", // FALSE
      rst_deassert_clk:       "CLKIN1" // CLKFBIN
      };
endinstance

interface VPLL;
   interface Clock       clkout0;
   interface Clock       clkout1;
   interface Clock       clkout2;
   interface Clock       clkout3;
   interface Clock       clkout4;
   interface Clock       clkout5;
   interface Clock       clkoutdcm0;
   interface Clock       clkoutdcm1;
   interface Clock       clkoutdcm2;
   interface Clock       clkoutdcm3;
   interface Clock       clkoutdcm4;
   interface Clock       clkoutdcm5;
   interface Clock       clkfbout;
   interface Clock       clkfbdcm;
   (* always_ready *)
   method    Bool        locked;
   (* always_ready, always_enabled *)
   method    Action      clkin1sel(Bool select);
   (* always_ready, always_enabled *)
   method    Action      fbin(Bool i);
endinterface: VPLL

interface PLL;
   interface Clock       clkout0;
   interface Clock       clkout1;
   interface Clock       clkout2;
   interface Clock       clkout3;
   interface Clock       clkout4;
   interface Clock       clkout5;
   interface Clock       clkoutdcm0;
   interface Clock       clkoutdcm1;
   interface Clock       clkoutdcm2;
   interface Clock       clkoutdcm3;
   interface Clock       clkoutdcm4;
   interface Clock       clkoutdcm5;
   interface Clock       clkfbout;
   interface Clock       clkfbdcm;
   (* always_ready *)
   method    Bool        locked;
   (* always_ready, always_enabled *)
   method    Action      clkin1sel(Bool select);
   (* always_ready, always_enabled *)
   method    Action      fbin(Bool i);
endinterface: PLL

import "BVI" PLL_ADV =
module vMkPLL#(PLLParams params)(VPLL);
   default_clock clk1(CLKIN1);
   default_reset rst(RST);

   parameter BANDWIDTH              = params.bandwidth;
   parameter CLKFBOUT_DESKEW_ADJUST = params.clkfbout_deskew_adjust;
   parameter CLKOUT0_DESKEW_ADJUST  = params.clkout0_deskew_adjust;
   parameter CLKOUT1_DESKEW_ADJUST  = params.clkout1_deskew_adjust;
   parameter CLKOUT2_DESKEW_ADJUST  = params.clkout2_deskew_adjust;
   parameter CLKOUT3_DESKEW_ADJUST  = params.clkout3_deskew_adjust;
   parameter CLKOUT4_DESKEW_ADJUST  = params.clkout4_deskew_adjust;
   parameter CLKOUT5_DESKEW_ADJUST  = params.clkout5_deskew_adjust;
   parameter CLKFBOUT_MULT          = params.clkfbout_mult;
   parameter CLKFBOUT_PHASE         = params.clkfbout_phase;
   parameter CLKIN1_PERIOD          = params.clkin1_period;
   parameter CLKIN2_PERIOD          = params.clkin2_period;
   parameter CLKOUT0_DIVIDE         = params.clkout0_divide;
   parameter CLKOUT0_DUTY_CYCLE     = params.clkout0_duty_cycle;
   parameter CLKOUT0_PHASE          = params.clkout0_phase;
   parameter CLKOUT1_DIVIDE         = params.clkout1_divide;
   parameter CLKOUT1_DUTY_CYCLE     = params.clkout1_duty_cycle;
   parameter CLKOUT1_PHASE          = params.clkout1_phase;
   parameter CLKOUT2_DIVIDE         = params.clkout2_divide;
   parameter CLKOUT2_DUTY_CYCLE     = params.clkout2_duty_cycle;
   parameter CLKOUT2_PHASE          = params.clkout2_phase;
   parameter CLKOUT3_DIVIDE         = params.clkout3_divide;
   parameter CLKOUT3_DUTY_CYCLE     = params.clkout3_duty_cycle;
   parameter CLKOUT3_PHASE          = params.clkout3_phase;
   parameter CLKOUT4_DIVIDE         = params.clkout4_divide;
   parameter CLKOUT4_DUTY_CYCLE     = params.clkout4_duty_cycle;
   parameter CLKOUT4_PHASE          = params.clkout4_phase;
   parameter CLKOUT5_DIVIDE         = params.clkout5_divide;
   parameter CLKOUT5_DUTY_CYCLE     = params.clkout5_duty_cycle;
   parameter CLKOUT5_PHASE          = params.clkout5_phase;
   parameter COMPENSATION           = params.compensation;
   parameter DIVCLK_DIVIDE          = params.divclk_divide;
   parameter EN_REL                 = params.en_rel;
   parameter PLL_PMCD_MODE          = params.pll_pmcd_mode;
   parameter REF_JITTER             = params.ref_jitter;
   parameter RESET_ON_LOSS_OF_LOCK  = params.reset_on_loss_of_lock;
   parameter RST_DEASSERT_CLK       = params.rst_deassert_clk;

   port CLKIN2 = Bit#(1)'(0);
   port DCLK   = Bit#(1)'(0);
   port DWE    = Bit#(1)'(0);
   port DADDR  = Bit#(5)'(0);
   port DI     = Bit#(16)'(0);
   port DEN    = Bit#(1)'(0);
   port REL    = Bit#(1)'(0);

   output_clock clkfbout(CLKFBOUT);
   output_clock clkfbdcm(CLKFBDCM);
   output_clock clkout0(CLKOUT0);
   output_clock clkout1(CLKOUT1);
   output_clock clkout2(CLKOUT2);
   output_clock clkout3(CLKOUT3);
   output_clock clkout4(CLKOUT4);
   output_clock clkout5(CLKOUT5);

   output_clock clkoutdcm0(CLKOUTDCM0);
   output_clock clkoutdcm1(CLKOUTDCM1);
   output_clock clkoutdcm2(CLKOUTDCM2);
   output_clock clkoutdcm3(CLKOUTDCM3);
   output_clock clkoutdcm4(CLKOUTDCM4);
   output_clock clkoutdcm5(CLKOUTDCM5);

   method LOCKED locked()            clocked_by(no_clock) reset_by(no_reset);
   method        clkin1sel(CLKINSEL) enable((*inhigh*)en1) clocked_by(clk1) reset_by(rst);

   method        fbin(CLKFBIN)       enable((*inhigh*)en2) clocked_by(clkfbout) reset_by(no_reset);

   schedule (locked, clkin1sel, fbin) CF (locked, clkin1sel, fbin);

endmodule: vMkPLL

import "BVI" PLL_ADV =
module vMkPLLSF#(PLLParams params)(VPLL);
   default_clock clk1(CLKIN1);
   default_reset rst(RST);

   parameter BANDWIDTH              = params.bandwidth;
   parameter CLKFBOUT_DESKEW_ADJUST = params.clkfbout_deskew_adjust;
   parameter CLKOUT0_DESKEW_ADJUST  = params.clkout0_deskew_adjust;
   parameter CLKOUT1_DESKEW_ADJUST  = params.clkout1_deskew_adjust;
   parameter CLKOUT2_DESKEW_ADJUST  = params.clkout2_deskew_adjust;
   parameter CLKOUT3_DESKEW_ADJUST  = params.clkout3_deskew_adjust;
   parameter CLKOUT4_DESKEW_ADJUST  = params.clkout4_deskew_adjust;
   parameter CLKOUT5_DESKEW_ADJUST  = params.clkout5_deskew_adjust;
   parameter CLKFBOUT_MULT          = params.clkfbout_mult;
   parameter CLKFBOUT_PHASE         = params.clkfbout_phase;
   parameter CLKIN1_PERIOD          = params.clkin1_period;
   parameter CLKIN2_PERIOD          = params.clkin2_period;
   parameter CLKOUT0_DIVIDE         = params.clkout0_divide;
   parameter CLKOUT0_DUTY_CYCLE     = params.clkout0_duty_cycle;
   parameter CLKOUT0_PHASE          = params.clkout0_phase;
   parameter CLKOUT1_DIVIDE         = params.clkout1_divide;
   parameter CLKOUT1_DUTY_CYCLE     = params.clkout1_duty_cycle;
   parameter CLKOUT1_PHASE          = params.clkout1_phase;
   parameter CLKOUT2_DIVIDE         = params.clkout2_divide;
   parameter CLKOUT2_DUTY_CYCLE     = params.clkout2_duty_cycle;
   parameter CLKOUT2_PHASE          = params.clkout2_phase;
   parameter CLKOUT3_DIVIDE         = params.clkout3_divide;
   parameter CLKOUT3_DUTY_CYCLE     = params.clkout3_duty_cycle;
   parameter CLKOUT3_PHASE          = params.clkout3_phase;
   parameter CLKOUT4_DIVIDE         = params.clkout4_divide;
   parameter CLKOUT4_DUTY_CYCLE     = params.clkout4_duty_cycle;
   parameter CLKOUT4_PHASE          = params.clkout4_phase;
   parameter CLKOUT5_DIVIDE         = params.clkout5_divide;
   parameter CLKOUT5_DUTY_CYCLE     = params.clkout5_duty_cycle;
   parameter CLKOUT5_PHASE          = params.clkout5_phase;
   parameter COMPENSATION           = params.compensation;
   parameter DIVCLK_DIVIDE          = params.divclk_divide;
   parameter EN_REL                 = params.en_rel;
   parameter PLL_PMCD_MODE          = params.pll_pmcd_mode;
   parameter REF_JITTER             = params.ref_jitter;
   parameter RESET_ON_LOSS_OF_LOCK  = params.reset_on_loss_of_lock;
   parameter RST_DEASSERT_CLK       = params.rst_deassert_clk;

   port CLKIN2 = Bit#(1)'(0);
   port DCLK   = Bit#(1)'(0);
   port DWE    = Bit#(1)'(0);
   port DADDR  = Bit#(5)'(0);
   port DI     = Bit#(16)'(0);
   port DEN    = Bit#(1)'(0);
   port REL    = Bit#(1)'(0);

   output_clock clkfbout(CLKFBOUT);
   output_clock clkfbdcm(CLKFBDCM);
   output_clock clkout0(CLKOUT0);
   output_clock clkout1(CLKOUT1);
   output_clock clkout2(CLKOUT2);
   output_clock clkout3(CLKOUT3);
   output_clock clkout4(CLKOUT4);
   output_clock clkout5(CLKOUT5);

   output_clock clkoutdcm0(CLKOUTDCM0);
   output_clock clkoutdcm1(CLKOUTDCM1);
   output_clock clkoutdcm2(CLKOUTDCM2);
   output_clock clkoutdcm3(CLKOUTDCM3);
   output_clock clkoutdcm4(CLKOUTDCM4);
   output_clock clkoutdcm5(CLKOUTDCM5);

   method LOCKED locked()            clocked_by(no_clock) reset_by(no_reset);
   method        clkin1sel(CLKINSEL) enable((*inhigh*)en1) clocked_by(clk1) reset_by(rst);

   method        fbin(CLKFBIN)       enable((*inhigh*)en2) clocked_by(clkfbout) reset_by(no_reset);

   schedule (locked, clkin1sel, fbin) CF (locked, clkin1sel, fbin);

   same_family(clk1, clkout0);
   same_family(clk1, clkout1);
   same_family(clk1, clkout2);
   same_family(clk1, clkout3);
   same_family(clk1, clkout4);
   same_family(clk1, clkout5);
   same_family(clk1, clkoutdcm0);
   same_family(clk1, clkoutdcm1);
   same_family(clk1, clkoutdcm2);
   same_family(clk1, clkoutdcm3);
   same_family(clk1, clkoutdcm4);
   same_family(clk1, clkoutdcm5);
endmodule: vMkPLLSF

module mkPLL#(PLLParams params)(PLL);
   VPLL _pll <- vMkPLL(params);

   interface clkout0    = _pll.clkout0;
   interface clkout1    = _pll.clkout1;
   interface clkout2    = _pll.clkout2;
   interface clkout3    = _pll.clkout3;
   interface clkout4    = _pll.clkout4;
   interface clkout5    = _pll.clkout5;
   interface clkoutdcm0 = _pll.clkoutdcm0;
   interface clkoutdcm1 = _pll.clkoutdcm1;
   interface clkoutdcm2 = _pll.clkoutdcm2;
   interface clkoutdcm3 = _pll.clkoutdcm3;
   interface clkoutdcm4 = _pll.clkoutdcm4;
   interface clkoutdcm5 = _pll.clkoutdcm5;
   interface clkfbout   = _pll.clkfbout;
   interface clkfbdcm   = _pll.clkfbdcm;

   method locked        = _pll.locked;
   method clkin1sel     = _pll.clkin1sel;
   method fbin          = _pll.fbin;

endmodule: mkPLL

////////////////////////////////////////////////////////////////////////////////
/// Clock Generator
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   Bool        clkin_buffer;
   Real        clkin1_period;
   Integer     reset_stages;
   Integer     feedback_mul;
   Integer     feedback_div;
   Integer     clk0_div;
   Real        clk0_duty_cycle;
   Real        clk0_phase;
   Bool        clk0_buffer;
   Integer     clk1_div;
   Real        clk1_duty_cycle;
   Real        clk1_phase;
   Bool        clk1_buffer;
   Integer     clk2_div;
   Real        clk2_duty_cycle;
   Real        clk2_phase;
   Bool        clk2_buffer;
   Integer     clk3_div;
   Real        clk3_duty_cycle;
   Real        clk3_phase;
   Bool        clk3_buffer;
   Integer     clk4_div;
   Real        clk4_duty_cycle;
   Real        clk4_phase;
   Bool        clk4_buffer;
   Integer     clk5_div;
   Real        clk5_duty_cycle;
   Real        clk5_phase;
   Bool        clk5_buffer;
   Bool        use_same_family;
   } ClockGeneratorParams deriving (Bits, Eq);

instance DefaultValue#(ClockGeneratorParams);
   defaultValue = ClockGeneratorParams {
      clkin_buffer:    True,
      clkin1_period:   10.000,
      reset_stages:    3,
      feedback_mul:    1,
      feedback_div:    1,
      clk0_div:        1,
      clk0_duty_cycle: 0.5,
      clk0_phase:      0.0,
      clk0_buffer:     True,
      clk1_div:        1,
      clk1_duty_cycle: 0.5,
      clk1_phase:      0.0,
      clk1_buffer:     True,
      clk2_div:        1,
      clk2_duty_cycle: 0.5,
      clk2_phase:      0.0,
      clk2_buffer:     True,
      clk3_div:        1,
      clk3_duty_cycle: 0.5,
      clk3_phase:      0.0,
      clk3_buffer:     True,
      clk4_div:        1,
      clk4_duty_cycle: 0.5,
      clk4_phase:      0.0,
      clk4_buffer:     True,
      clk5_div:        1,
      clk5_duty_cycle: 0.5,
      clk5_phase:      0.0,
      clk5_buffer:     True,
      use_same_family: False
      };
endinstance

interface ClockGenerator;
   interface Clock       clkout0;
   interface Clock       clkout1;
   interface Clock       clkout2;
   interface Clock       clkout3;
   interface Clock       clkout4;
   interface Clock       clkout5;
   (* always_ready *)
   method    Bool        locked;
endinterface: ClockGenerator

module mkClockGenerator#(ClockGeneratorParams params)(ClockGenerator);

   ////////////////////////////////////////////////////////////////////////////////
   /// Clocks & Resets
   ////////////////////////////////////////////////////////////////////////////////
   Clock                                     clk                 <- exposeCurrentClock;
   Clock                                     clk_buffered         = ?;

   if (params.clkin_buffer) begin
      Clock inbuffer <- mkClockIBUFG(defaultValue);
      clk_buffered  = inbuffer;
   end
   else begin
      clk_buffered  = clk;
   end

   Reset                                     rst_n               <- mkAsyncResetFromCR(params.reset_stages, clk_buffered);
   Reset                                     rst                 <- mkResetInverter(rst_n);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   PLLParams                                 pll_params           = defaultValue;
   pll_params.clkin1_period      = params.clkin1_period;
   pll_params.clkfbout_mult      = params.feedback_mul;
   pll_params.divclk_divide      = params.feedback_div;
   pll_params.clkout0_divide     = params.clk0_div;
   pll_params.clkout0_duty_cycle = params.clk0_duty_cycle;
   pll_params.clkout0_phase      = params.clk0_phase;
   pll_params.clkout1_divide     = params.clk1_div;
   pll_params.clkout1_duty_cycle = params.clk1_duty_cycle;
   pll_params.clkout1_phase      = params.clk1_phase;
   pll_params.clkout2_divide     = params.clk2_div;
   pll_params.clkout2_duty_cycle = params.clk2_duty_cycle;
   pll_params.clkout2_phase      = params.clk2_phase;
   pll_params.clkout3_divide     = params.clk3_div;
   pll_params.clkout3_duty_cycle = params.clk3_duty_cycle;
   pll_params.clkout3_phase      = params.clk3_phase;
   pll_params.clkout4_divide     = params.clk4_div;
   pll_params.clkout4_duty_cycle = params.clk4_duty_cycle;
   pll_params.clkout4_phase      = params.clk4_phase;
   pll_params.clkout5_divide     = params.clk5_div;
   pll_params.clkout5_duty_cycle = params.clk5_duty_cycle;
   pll_params.clkout5_phase      = params.clk5_phase;

   VPLL                                      pll                  = ?;
   if (params.use_same_family)
      pll <- vMkPLLSF(pll_params, clocked_by clk_buffered, reset_by rst);
   else
      pll <- vMkPLL(pll_params, clocked_by clk_buffered, reset_by rst);

   ReadOnly#(Bool)                           clkfbbuf            <- mkClockBitBUFG(clocked_by pll.clkfbout);
   Clock                                     clkout0buf           = ?;
   Clock                                     clkout1buf           = ?;
   Clock                                     clkout2buf           = ?;
   Clock                                     clkout3buf           = ?;
   Clock                                     clkout4buf           = ?;
   Clock                                     clkout5buf           = ?;

   if (params.clk0_buffer) begin
      Clock clk0buffer <- mkClockBUFG(clocked_by pll.clkout0);
      clkout0buf = clk0buffer;
   end
   else begin
      clkout0buf = pll.clkout0;
   end


   if (params.clk1_buffer) begin
      Clock clk1buffer <- mkClockBUFG(clocked_by pll.clkout1);
      clkout1buf = clk1buffer;
   end
   else begin
      clkout1buf = pll.clkout1;
   end


   if (params.clk2_buffer) begin
      Clock clk2buffer <- mkClockBUFG(clocked_by pll.clkout2);
      clkout2buf = clk2buffer;
   end
   else begin
      clkout2buf = pll.clkout2;
   end


   if (params.clk3_buffer) begin
      Clock clk3buffer <- mkClockBUFG(clocked_by pll.clkout3);
      clkout3buf = clk3buffer;
   end
   else begin
      clkout3buf = pll.clkout3;
   end


   if (params.clk4_buffer) begin
      Clock clk4buffer <- mkClockBUFG(clocked_by pll.clkout4);
      clkout4buf = clk4buffer;
   end
   else begin
      clkout4buf = pll.clkout4;
   end


   if (params.clk5_buffer) begin
      Clock clk5buffer <- mkClockBUFG(clocked_by pll.clkout5);
      clkout5buf = clk5buffer;
   end
   else begin
      clkout5buf = pll.clkout5;
   end


   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* fire_when_enabled, no_implicit_conditions *)
   rule connect_clkin1sel;
      pll.clkin1sel(True);
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule connect_feedback;
      pll.fbin(clkfbbuf);
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface clkout0 = clkout0buf;
   interface clkout1 = clkout1buf;
   interface clkout2 = clkout2buf;
   interface clkout3 = clkout3buf;
   interface clkout4 = clkout4buf;
   interface clkout5 = clkout5buf;
   method    locked  = pll.locked;

endmodule: mkClockGenerator

////////////////////////////////////////////////////////////////////////////////
/// MMCME2_ADV
////////////////////////////////////////////////////////////////////////////////
interface MMCME2;
   interface Clock     clkout0;
   interface Clock     clkout0_n;
   interface Clock     clkout1;
   interface Clock     clkout1_n;
   interface Clock     clkout2;
   interface Clock     clkout2_n;
   interface Clock     clkout3;
   interface Clock     clkout3_n;
   interface Clock     clkout4;
   interface Clock     clkout5;
   interface Clock     clkout6;
   (* always_ready, always_enabled *)
   method    Bool      locked;
endinterface

import "BVI" MMCME2_ADV =
module vMkMMCME2_ADV#(MMCMParams params, Clock clkin2, Clock dclk, Clock psclk)(MMCM);
   Reset reset <- invertCurrentReset;

   default_clock clk1(CLKIN1);
   default_reset rst(RST) = reset;

   parameter BANDWIDTH            = params.bandwidth;
   parameter CLKFBOUT_USE_FINE_PS = params.clkfbout_use_fine_ps;
   parameter CLKOUT0_USE_FINE_PS  = params.clkout0_use_fine_ps;
   parameter CLKOUT1_USE_FINE_PS  = params.clkout1_use_fine_ps;
   parameter CLKOUT2_USE_FINE_PS  = params.clkout2_use_fine_ps;
   parameter CLKOUT3_USE_FINE_PS  = params.clkout3_use_fine_ps;
   parameter CLKOUT4_CASCADE      = params.clkout4_cascade;
   parameter CLKOUT4_USE_FINE_PS  = params.clkout4_use_fine_ps;
   parameter CLKOUT5_USE_FINE_PS  = params.clkout5_use_fine_ps;
   parameter CLKOUT6_USE_FINE_PS  = params.clkout6_use_fine_ps;
   parameter COMPENSATION         = params.compensation;
   parameter STARTUP_WAIT         = params.startup_wait;
   parameter CLKFBOUT_MULT_F      = params.clkfbout_mult_f;
   parameter CLKFBOUT_PHASE       = params.clkfbout_phase;
   parameter CLKIN1_PERIOD        = params.clkin1_period;
   parameter CLKIN2_PERIOD        = params.clkin2_period;
   parameter DIVCLK_DIVIDE        = params.divclk_divide;
   parameter CLKOUT0_DIVIDE_F     = params.clkout0_divide_f;
   parameter CLKOUT0_DUTY_CYCLE   = params.clkout0_duty_cycle;
   parameter CLKOUT0_PHASE        = params.clkout0_phase;
   parameter CLKOUT1_DIVIDE       = params.clkout1_divide;
   parameter CLKOUT1_DUTY_CYCLE   = params.clkout1_duty_cycle;
   parameter CLKOUT1_PHASE        = params.clkout1_phase;
   parameter CLKOUT2_DIVIDE       = params.clkout2_divide;
   parameter CLKOUT2_DUTY_CYCLE   = params.clkout2_duty_cycle;
   parameter CLKOUT2_PHASE        = params.clkout2_phase;
   parameter CLKOUT3_DIVIDE       = params.clkout3_divide;
   parameter CLKOUT3_DUTY_CYCLE   = params.clkout3_duty_cycle;
   parameter CLKOUT3_PHASE        = params.clkout3_phase;
   parameter CLKOUT4_DIVIDE       = params.clkout4_divide;
   parameter CLKOUT4_DUTY_CYCLE   = params.clkout4_duty_cycle;
   parameter CLKOUT4_PHASE        = params.clkout4_phase;
   parameter CLKOUT5_DIVIDE       = params.clkout5_divide;
   parameter CLKOUT5_DUTY_CYCLE   = params.clkout5_duty_cycle;
   parameter CLKOUT5_PHASE        = params.clkout5_phase;
   parameter CLKOUT6_DIVIDE       = params.clkout6_divide;
   parameter CLKOUT6_DUTY_CYCLE   = params.clkout6_duty_cycle;
   parameter CLKOUT6_PHASE        = params.clkout6_phase;
   parameter REF_JITTER1          = params.ref_jitter1;
   parameter REF_JITTER2          = params.ref_jitter2;

   port PWRDWN       = Bit#(1)'(0);

   input_clock clk2(CLKIN2, (*unused*)CLKIN2_GATE)    = clkin2;
   input_clock dclk(DCLK, (*unused*)DCLK_GATE)        = dclk;
   input_clock psclk(PSCLK, (*unused*)PSCLK_GATE)     = psclk;

   output_clock clkfbout(CLKFBOUT);
   output_clock clkfbout_n(CLKFBOUTB);
   output_clock clkout0(CLKOUT0);
   output_clock clkout0_n(CLKOUT0B);
   output_clock clkout1(CLKOUT1);
   output_clock clkout1_n(CLKOUT1B);
   output_clock clkout2(CLKOUT2);
   output_clock clkout2_n(CLKOUT2B);
   output_clock clkout3(CLKOUT3);
   output_clock clkout3_n(CLKOUT3B);
   output_clock clkout4(CLKOUT4);
   output_clock clkout5(CLKOUT5);
   output_clock clkout6(CLKOUT6);

   method LOCKED   locked()     clocked_by(no_clock) reset_by(no_reset);
   method CLKFBSTOPPED clkfb_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method CLKINSTOPPED clkin_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method          clkin1sel(CLKINSEL) enable((*inhigh*)en0) clocked_by(clk1) reset_by(no_reset);
   method          clkfbin(CLKFBIN) enable((*inhigh*)en1) clocked_by(clkfbout) reset_by(no_reset);

   interface MMCM_DRP reconfig;
      method       request(DWE, DADDR, DI) enable(DEN) clocked_by(dclk) reset_by(no_reset);
      method DO    response() ready(DRDY) clocked_by(dclk) reset_by(no_reset);
   endinterface

   interface MMCM_PS phase_shift;
      method incdec (PSINCDEC)  enable(PSEN) clocked_by(psclk) reset_by(no_reset);
      method PSDONE done ()                  clocked_by(psclk) reset_by(no_reset);
   endinterface

   schedule clkfbin C clkfbin;
   schedule clkin1sel C clkin1sel;
   schedule (locked, clkfb_stopped, clkin_stopped) CF (locked, clkfb_stopped, clkin_stopped);
   schedule reconfig_response SB reconfig_request;
   schedule reconfig_request C reconfig_request;
   schedule reconfig_response CF reconfig_response;
   schedule phase_shift_incdec C phase_shift_incdec;
   schedule phase_shift_done SB phase_shift_incdec;
   schedule phase_shift_done CF phase_shift_done;
endmodule

// Version where the output clocks are annotated as "same_family" with CLKIN1
//
import "BVI" MMCME2_ADV =
module vMkMMCME2SF_ADV#(MMCMParams params, Clock clkin2, Clock dclk, Clock psclk)(MMCM);
   Reset reset <- invertCurrentReset;

   default_clock clk1(CLKIN1);
   default_reset rst(RST) = reset;

   parameter BANDWIDTH            = params.bandwidth;
   parameter CLKFBOUT_USE_FINE_PS = params.clkfbout_use_fine_ps;
   parameter CLKOUT0_USE_FINE_PS  = params.clkout0_use_fine_ps;
   parameter CLKOUT1_USE_FINE_PS  = params.clkout1_use_fine_ps;
   parameter CLKOUT2_USE_FINE_PS  = params.clkout2_use_fine_ps;
   parameter CLKOUT3_USE_FINE_PS  = params.clkout3_use_fine_ps;
   parameter CLKOUT4_CASCADE      = params.clkout4_cascade;
   parameter CLKOUT4_USE_FINE_PS  = params.clkout4_use_fine_ps;
   parameter CLKOUT5_USE_FINE_PS  = params.clkout5_use_fine_ps;
   parameter CLKOUT6_USE_FINE_PS  = params.clkout6_use_fine_ps;
   parameter COMPENSATION         = params.compensation;
   parameter STARTUP_WAIT         = params.startup_wait;
   parameter CLKFBOUT_MULT_F      = params.clkfbout_mult_f;
   parameter CLKFBOUT_PHASE       = params.clkfbout_phase;
   parameter CLKIN1_PERIOD        = params.clkin1_period;
   parameter CLKIN2_PERIOD        = params.clkin2_period;
   parameter DIVCLK_DIVIDE        = params.divclk_divide;
   parameter CLKOUT0_DIVIDE_F     = params.clkout0_divide_f;
   parameter CLKOUT0_DUTY_CYCLE   = params.clkout0_duty_cycle;
   parameter CLKOUT0_PHASE        = params.clkout0_phase;
   parameter CLKOUT1_DIVIDE       = params.clkout1_divide;
   parameter CLKOUT1_DUTY_CYCLE   = params.clkout1_duty_cycle;
   parameter CLKOUT1_PHASE        = params.clkout1_phase;
   parameter CLKOUT2_DIVIDE       = params.clkout2_divide;
   parameter CLKOUT2_DUTY_CYCLE   = params.clkout2_duty_cycle;
   parameter CLKOUT2_PHASE        = params.clkout2_phase;
   parameter CLKOUT3_DIVIDE       = params.clkout3_divide;
   parameter CLKOUT3_DUTY_CYCLE   = params.clkout3_duty_cycle;
   parameter CLKOUT3_PHASE        = params.clkout3_phase;
   parameter CLKOUT4_DIVIDE       = params.clkout4_divide;
   parameter CLKOUT4_DUTY_CYCLE   = params.clkout4_duty_cycle;
   parameter CLKOUT4_PHASE        = params.clkout4_phase;
   parameter CLKOUT5_DIVIDE       = params.clkout5_divide;
   parameter CLKOUT5_DUTY_CYCLE   = params.clkout5_duty_cycle;
   parameter CLKOUT5_PHASE        = params.clkout5_phase;
   parameter CLKOUT6_DIVIDE       = params.clkout6_divide;
   parameter CLKOUT6_DUTY_CYCLE   = params.clkout6_duty_cycle;
   parameter CLKOUT6_PHASE        = params.clkout6_phase;
   parameter REF_JITTER1          = params.ref_jitter1;
   parameter REF_JITTER2          = params.ref_jitter2;

   port PWRDWN       = Bit#(1)'(0);

   input_clock clk2(CLKIN2, (*unused*)CLKIN2_GATE)    = clkin2;
   input_clock dclk(DCLK, (*unused*)DCLK_GATE)        = dclk;
   input_clock psclk(PSCLK, (*unused*)PSCLK_GATE)     = psclk;

   output_clock clkfbout(CLKFBOUT);
   output_clock clkfbout_n(CLKFBOUTB);
   output_clock clkout0(CLKOUT0);
   output_clock clkout0_n(CLKOUT0B);
   output_clock clkout1(CLKOUT1);
   output_clock clkout1_n(CLKOUT1B);
   output_clock clkout2(CLKOUT2);
   output_clock clkout2_n(CLKOUT2B);
   output_clock clkout3(CLKOUT3);
   output_clock clkout3_n(CLKOUT3B);
   output_clock clkout4(CLKOUT4);
   output_clock clkout5(CLKOUT5);
   output_clock clkout6(CLKOUT6);

   same_family(clk1, clkfbout);
   same_family(clk1, clkfbout_n);
   same_family(clk1, clkout0);
   same_family(clk1, clkout0_n);
   same_family(clk1, clkout1);
   same_family(clk1, clkout1_n);
   same_family(clk1, clkout2);
   same_family(clk1, clkout2_n);
   same_family(clk1, clkout3);
   same_family(clk1, clkout3_n);
   same_family(clk1, clkout4);
   same_family(clk1, clkout5);
   same_family(clk1, clkout6);

   method LOCKED   locked()     clocked_by(no_clock) reset_by(no_reset);
   method CLKFBSTOPPED clkfb_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method CLKINSTOPPED clkin_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method          clkin1sel(CLKINSEL) enable((*inhigh*)en0) clocked_by(clk1) reset_by(no_reset);
   method          clkfbin(CLKFBIN) enable((*inhigh*)en1) clocked_by(clkfbout) reset_by(no_reset);

   interface MMCM_DRP reconfig;
      method       request(DWE, DADDR, DI) enable(DEN) clocked_by(dclk) reset_by(no_reset);
      method DO    response() ready(DRDY) clocked_by(dclk) reset_by(no_reset);
   endinterface

   interface MMCM_PS phase_shift;
      method incdec (PSINCDEC)  enable(PSEN) clocked_by(psclk) reset_by(no_reset);
      method PSDONE done ()                  clocked_by(psclk) reset_by(no_reset);
   endinterface

   schedule clkfbin C clkfbin;
   schedule clkin1sel C clkin1sel;
   schedule clkin1sel CF clkfbin;
   schedule (locked, clkfb_stopped, clkin_stopped) CF (locked, clkfb_stopped, clkin_stopped);
   schedule reconfig_response SB reconfig_request;
   schedule reconfig_request C reconfig_request;
   schedule reconfig_response CF reconfig_response;
   schedule phase_shift_incdec C phase_shift_incdec;
   schedule phase_shift_done SB phase_shift_incdec;
   schedule phase_shift_done CF phase_shift_done;
endmodule

module mkMMCME2#(MMCMParams params)(MMCME2);
   MMCM _mmcm  = ?;
   if (params.use_same_family)
      _mmcm <- vMkMMCME2SF_ADV(params, noClock, noClock, noClock);
   else
      _mmcm <- vMkMMCME2_ADV(params, noClock, noClock, noClock);

   ReadOnly#(Bool) clkfbbuf <- mkClockBitBUFG(clocked_by _mmcm.clkfbout);

   (* fire_when_enabled, no_implicit_conditions *)
   rule connect_feedback;
      _mmcm.clkfbin(pack(clkfbbuf));
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule connect_clkin1sel;
      _mmcm.clkin1sel(True);
   endrule

   interface Clock     clkout0   = _mmcm.clkout0;
   interface Clock     clkout0_n = _mmcm.clkout0_n;
   interface Clock     clkout1   = _mmcm.clkout1;
   interface Clock     clkout1_n = _mmcm.clkout1_n;
   interface Clock     clkout2   = _mmcm.clkout2;
   interface Clock     clkout2_n = _mmcm.clkout2_n;
   interface Clock     clkout3   = _mmcm.clkout3;
   interface Clock     clkout3_n = _mmcm.clkout3_n;
   interface Clock     clkout4   = _mmcm.clkout4;
   interface Clock     clkout5   = _mmcm.clkout5;
   interface Clock     clkout6   = _mmcm.clkout6;
   method    Bool      locked    = _mmcm.locked;
endmodule

////////////////////////////////////////////////////////////////////////////////
/// MMCME3_ADV
////////////////////////////////////////////////////////////////////////////////
interface MMCME3;
   interface Clock     clkout0;
   interface Clock     clkout0_n;
   interface Clock     clkout1;
   interface Clock     clkout1_n;
   interface Clock     clkout2;
   interface Clock     clkout2_n;
   interface Clock     clkout3;
   interface Clock     clkout3_n;
   interface Clock     clkout4;
   interface Clock     clkout5;
   interface Clock     clkout6;
   (* always_ready, always_enabled *)
   method    Bool      locked;
endinterface

interface VMMCME3;
   interface Clock     clkout0;
   interface Clock     clkout0_n;
   interface Clock     clkout1;
   interface Clock     clkout1_n;
   interface Clock     clkout2;
   interface Clock     clkout2_n;
   interface Clock     clkout3;
   interface Clock     clkout3_n;
   interface Clock     clkout4;
   interface Clock     clkout5;
   interface Clock     clkout6;
   interface Clock     clkfbout;
   interface Clock     clkfbout_n;
   interface MMCM_DRP  reconfig;
   interface MMCM_CDDC cddc;
   interface MMCM_PS   phase_shift;
   (* always_ready, always_enabled *)
   method    Bool      locked;
   (* always_ready, always_enabled *)
   method    Bool      clkfb_stopped;
   (* always_ready, always_enabled *)
   method    Bool      clkin_stopped;
   (* always_ready, always_enabled *)
   method    Action    clkin1sel(Bool select);
   (* always_ready, always_enabled *)
   method    Action    clkfbin(Bit#(1) clk);
endinterface

import "BVI" MMCME3_ADV =
module vMkMMCME3_ADV#(MMCMParams params, Clock clkin2, Clock dclk, Clock psclk)(VMMCME3);
   Reset reset <- invertCurrentReset;

   default_clock clk1(CLKIN1);
   default_reset rst(RST) = reset;

   parameter BANDWIDTH            = params.bandwidth;
   parameter CLKFBOUT_USE_FINE_PS = params.clkfbout_use_fine_ps;
   parameter CLKOUT0_USE_FINE_PS  = params.clkout0_use_fine_ps;
   parameter CLKOUT1_USE_FINE_PS  = params.clkout1_use_fine_ps;
   parameter CLKOUT2_USE_FINE_PS  = params.clkout2_use_fine_ps;
   parameter CLKOUT3_USE_FINE_PS  = params.clkout3_use_fine_ps;
   parameter CLKOUT4_CASCADE      = params.clkout4_cascade;
   parameter CLKOUT4_USE_FINE_PS  = params.clkout4_use_fine_ps;
   parameter CLKOUT5_USE_FINE_PS  = params.clkout5_use_fine_ps;
   parameter CLKOUT6_USE_FINE_PS  = params.clkout6_use_fine_ps;
   parameter COMPENSATION         = params.compensation;
   parameter STARTUP_WAIT         = params.startup_wait;
   parameter CLKFBOUT_MULT_F      = params.clkfbout_mult_f;
   parameter CLKFBOUT_PHASE       = params.clkfbout_phase;
   parameter CLKIN1_PERIOD        = params.clkin1_period;
   parameter CLKIN2_PERIOD        = params.clkin2_period;
   parameter DIVCLK_DIVIDE        = params.divclk_divide;
   parameter CLKOUT0_DIVIDE_F     = params.clkout0_divide_f;
   parameter CLKOUT0_DUTY_CYCLE   = params.clkout0_duty_cycle;
   parameter CLKOUT0_PHASE        = params.clkout0_phase;
   parameter CLKOUT1_DIVIDE       = params.clkout1_divide;
   parameter CLKOUT1_DUTY_CYCLE   = params.clkout1_duty_cycle;
   parameter CLKOUT1_PHASE        = params.clkout1_phase;
   parameter CLKOUT2_DIVIDE       = params.clkout2_divide;
   parameter CLKOUT2_DUTY_CYCLE   = params.clkout2_duty_cycle;
   parameter CLKOUT2_PHASE        = params.clkout2_phase;
   parameter CLKOUT3_DIVIDE       = params.clkout3_divide;
   parameter CLKOUT3_DUTY_CYCLE   = params.clkout3_duty_cycle;
   parameter CLKOUT3_PHASE        = params.clkout3_phase;
   parameter CLKOUT4_DIVIDE       = params.clkout4_divide;
   parameter CLKOUT4_DUTY_CYCLE   = params.clkout4_duty_cycle;
   parameter CLKOUT4_PHASE        = params.clkout4_phase;
   parameter CLKOUT5_DIVIDE       = params.clkout5_divide;
   parameter CLKOUT5_DUTY_CYCLE   = params.clkout5_duty_cycle;
   parameter CLKOUT5_PHASE        = params.clkout5_phase;
   parameter CLKOUT6_DIVIDE       = params.clkout6_divide;
   parameter CLKOUT6_DUTY_CYCLE   = params.clkout6_duty_cycle;
   parameter CLKOUT6_PHASE        = params.clkout6_phase;
   parameter REF_JITTER1          = params.ref_jitter1;
   parameter REF_JITTER2          = params.ref_jitter2;

   port PWRDWN       = Bit#(1)'(0);

   input_clock clk2(CLKIN2, (*unused*)CLKIN2_GATE)    = clkin2;
   input_clock dclk(DCLK, (*unused*)DCLK_GATE)        = dclk;
   input_clock psclk(PSCLK, (*unused*)PSCLK_GATE)     = psclk;

   output_clock clkfbout(CLKFBOUT);
   output_clock clkfbout_n(CLKFBOUTB);
   output_clock clkout0(CLKOUT0);
   output_clock clkout0_n(CLKOUT0B);
   output_clock clkout1(CLKOUT1);
   output_clock clkout1_n(CLKOUT1B);
   output_clock clkout2(CLKOUT2);
   output_clock clkout2_n(CLKOUT2B);
   output_clock clkout3(CLKOUT3);
   output_clock clkout3_n(CLKOUT3B);
   output_clock clkout4(CLKOUT4);
   output_clock clkout5(CLKOUT5);
   output_clock clkout6(CLKOUT6);

   method LOCKED   locked()     clocked_by(no_clock) reset_by(no_reset);
   method CLKFBSTOPPED clkfb_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method CLKINSTOPPED clkin_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method          clkin1sel(CLKINSEL) enable((*inhigh*)en0) clocked_by(clk1) reset_by(no_reset);
   method          clkfbin(CLKFBIN) enable((*inhigh*)en1) clocked_by(clkfbout) reset_by(no_reset);

   interface MMCM_DRP reconfig;
      method       request(DWE, DADDR, DI) enable(DEN) clocked_by(dclk) reset_by(no_reset);
      method DO    response() ready(DRDY) clocked_by(dclk) reset_by(no_reset);
   endinterface

   interface MMCM_CDDC cddc;
      method          request () enable(CDDCREQ) clocked_by(dclk) reset_by(no_reset);
      method CDDCDONE done()                     clocked_by(dclk) reset_by(no_reset);
   endinterface

   interface MMCM_PS phase_shift;
      method incdec (PSINCDEC)  enable(PSEN) clocked_by(psclk) reset_by(no_reset);
      method PSDONE done ()                  clocked_by(psclk) reset_by(no_reset);
   endinterface

   schedule clkfbin C clkfbin;
   schedule clkin1sel C clkin1sel;
   schedule (locked, clkfb_stopped, clkin_stopped) CF (locked, clkfb_stopped, clkin_stopped);
   schedule reconfig_response SB reconfig_request;
   schedule reconfig_request C reconfig_request;
   schedule reconfig_response CF reconfig_response;
   schedule (cddc_request, cddc_done) CF (cddc_request, cddc_done, reconfig_request, reconfig_response);
   schedule phase_shift_incdec C phase_shift_incdec;
   schedule phase_shift_done SB phase_shift_incdec;
   schedule phase_shift_done CF phase_shift_done;
endmodule

// Version where the output clocks are annotated as "same_family" with CLKIN1
//
import "BVI" MMCME3_ADV =
module vMkMMCME3SF_ADV#(MMCMParams params, Clock clkin2, Clock dclk, Clock psclk)(VMMCME3);
   Reset reset <- invertCurrentReset;

   default_clock clk1(CLKIN1);
   default_reset rst(RST) = reset;

   parameter BANDWIDTH            = params.bandwidth;
   parameter CLKFBOUT_USE_FINE_PS = params.clkfbout_use_fine_ps;
   parameter CLKOUT0_USE_FINE_PS  = params.clkout0_use_fine_ps;
   parameter CLKOUT1_USE_FINE_PS  = params.clkout1_use_fine_ps;
   parameter CLKOUT2_USE_FINE_PS  = params.clkout2_use_fine_ps;
   parameter CLKOUT3_USE_FINE_PS  = params.clkout3_use_fine_ps;
   parameter CLKOUT4_CASCADE      = params.clkout4_cascade;
   parameter CLKOUT4_USE_FINE_PS  = params.clkout4_use_fine_ps;
   parameter CLKOUT5_USE_FINE_PS  = params.clkout5_use_fine_ps;
   parameter CLKOUT6_USE_FINE_PS  = params.clkout6_use_fine_ps;
   parameter COMPENSATION         = params.compensation;
   parameter STARTUP_WAIT         = params.startup_wait;
   parameter CLKFBOUT_MULT_F      = params.clkfbout_mult_f;
   parameter CLKFBOUT_PHASE       = params.clkfbout_phase;
   parameter CLKIN1_PERIOD        = params.clkin1_period;
   parameter CLKIN2_PERIOD        = params.clkin2_period;
   parameter DIVCLK_DIVIDE        = params.divclk_divide;
   parameter CLKOUT0_DIVIDE_F     = params.clkout0_divide_f;
   parameter CLKOUT0_DUTY_CYCLE   = params.clkout0_duty_cycle;
   parameter CLKOUT0_PHASE        = params.clkout0_phase;
   parameter CLKOUT1_DIVIDE       = params.clkout1_divide;
   parameter CLKOUT1_DUTY_CYCLE   = params.clkout1_duty_cycle;
   parameter CLKOUT1_PHASE        = params.clkout1_phase;
   parameter CLKOUT2_DIVIDE       = params.clkout2_divide;
   parameter CLKOUT2_DUTY_CYCLE   = params.clkout2_duty_cycle;
   parameter CLKOUT2_PHASE        = params.clkout2_phase;
   parameter CLKOUT3_DIVIDE       = params.clkout3_divide;
   parameter CLKOUT3_DUTY_CYCLE   = params.clkout3_duty_cycle;
   parameter CLKOUT3_PHASE        = params.clkout3_phase;
   parameter CLKOUT4_DIVIDE       = params.clkout4_divide;
   parameter CLKOUT4_DUTY_CYCLE   = params.clkout4_duty_cycle;
   parameter CLKOUT4_PHASE        = params.clkout4_phase;
   parameter CLKOUT5_DIVIDE       = params.clkout5_divide;
   parameter CLKOUT5_DUTY_CYCLE   = params.clkout5_duty_cycle;
   parameter CLKOUT5_PHASE        = params.clkout5_phase;
   parameter CLKOUT6_DIVIDE       = params.clkout6_divide;
   parameter CLKOUT6_DUTY_CYCLE   = params.clkout6_duty_cycle;
   parameter CLKOUT6_PHASE        = params.clkout6_phase;
   parameter REF_JITTER1          = params.ref_jitter1;
   parameter REF_JITTER2          = params.ref_jitter2;

   port PWRDWN       = Bit#(1)'(0);

   input_clock clk2(CLKIN2, (*unused*)CLKIN2_GATE)    = clkin2;
   input_clock dclk(DCLK, (*unused*)DCLK_GATE)        = dclk;
   input_clock psclk(PSCLK, (*unused*)PSCLK_GATE)     = psclk;

   output_clock clkfbout(CLKFBOUT);
   output_clock clkfbout_n(CLKFBOUTB);
   output_clock clkout0(CLKOUT0);
   output_clock clkout0_n(CLKOUT0B);
   output_clock clkout1(CLKOUT1);
   output_clock clkout1_n(CLKOUT1B);
   output_clock clkout2(CLKOUT2);
   output_clock clkout2_n(CLKOUT2B);
   output_clock clkout3(CLKOUT3);
   output_clock clkout3_n(CLKOUT3B);
   output_clock clkout4(CLKOUT4);
   output_clock clkout5(CLKOUT5);
   output_clock clkout6(CLKOUT6);

   same_family(clk1, clkfbout);
   same_family(clk1, clkfbout_n);
   same_family(clk1, clkout0);
   same_family(clk1, clkout0_n);
   same_family(clk1, clkout1);
   same_family(clk1, clkout1_n);
   same_family(clk1, clkout2);
   same_family(clk1, clkout2_n);
   same_family(clk1, clkout3);
   same_family(clk1, clkout3_n);
   same_family(clk1, clkout4);
   same_family(clk1, clkout5);
   same_family(clk1, clkout6);

   method LOCKED   locked()     clocked_by(no_clock) reset_by(no_reset);
   method CLKFBSTOPPED clkfb_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method CLKINSTOPPED clkin_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method          clkin1sel(CLKINSEL) enable((*inhigh*)en0) clocked_by(clk1) reset_by(no_reset);
   method          clkfbin(CLKFBIN) enable((*inhigh*)en1) clocked_by(clkfbout) reset_by(no_reset);

   interface MMCM_DRP reconfig;
      method       request(DWE, DADDR, DI) enable(DEN) clocked_by(dclk) reset_by(no_reset);
      method DO    response() ready(DRDY) clocked_by(dclk) reset_by(no_reset);
   endinterface

   interface MMCM_CDDC cddc;
      method          request () enable(CDDCREQ) clocked_by(dclk) reset_by(no_reset);
      method CDDCDONE done()                     clocked_by(dclk) reset_by(no_reset);
   endinterface

   interface MMCM_PS phase_shift;
      method incdec (PSINCDEC)  enable(PSEN) clocked_by(psclk) reset_by(no_reset);
      method PSDONE done ()                  clocked_by(psclk) reset_by(no_reset);
   endinterface

   schedule clkfbin C clkfbin;
   schedule clkin1sel C clkin1sel;
   schedule clkin1sel CF clkfbin;
   schedule (locked, clkfb_stopped, clkin_stopped) CF (locked, clkfb_stopped, clkin_stopped);
   schedule reconfig_response SB reconfig_request;
   schedule reconfig_request C reconfig_request;
   schedule reconfig_response CF reconfig_response;
   schedule (cddc_request, cddc_done) CF (cddc_request, cddc_done, reconfig_request, reconfig_response);
   schedule phase_shift_incdec C phase_shift_incdec;
   schedule phase_shift_done SB phase_shift_incdec;
   schedule phase_shift_done CF phase_shift_done;
endmodule

module mkMMCME3#(MMCMParams params)(MMCME3);
   VMMCME3 _mmcm  = ?;
   if (params.use_same_family)
      _mmcm <- vMkMMCME3SF_ADV(params, noClock, noClock, noClock);
   else
      _mmcm <- vMkMMCME3_ADV(params, noClock, noClock, noClock);

   ReadOnly#(Bool) clkfbbuf <- mkClockBitBUFG(clocked_by _mmcm.clkfbout);

   (* fire_when_enabled, no_implicit_conditions *)
   rule connect_feedback;
      _mmcm.clkfbin(pack(clkfbbuf));
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule connect_clkin1sel;
      _mmcm.clkin1sel(True);
   endrule

   interface Clock     clkout0   = _mmcm.clkout0;
   interface Clock     clkout0_n = _mmcm.clkout0_n;
   interface Clock     clkout1   = _mmcm.clkout1;
   interface Clock     clkout1_n = _mmcm.clkout1_n;
   interface Clock     clkout2   = _mmcm.clkout2;
   interface Clock     clkout2_n = _mmcm.clkout2_n;
   interface Clock     clkout3   = _mmcm.clkout3;
   interface Clock     clkout3_n = _mmcm.clkout3_n;
   interface Clock     clkout4   = _mmcm.clkout4;
   interface Clock     clkout5   = _mmcm.clkout5;
   interface Clock     clkout6   = _mmcm.clkout6;
   method    Bool      locked    = _mmcm.locked;
endmodule

////////////////////////////////////////////////////////////////////////////////
/// ClockGenerator Virtex 6
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   Bool        clkin_buffer;
   Real        clkin1_period;
   Integer     reset_stages;
   Real        clkfbout_mult_f;
   Real        clkfbout_phase;
   Integer     divclk_divide;
   Bool        clkout0_buffer;
   Bool        clkout0n_buffer;
   Real        clkout0_divide_f;
   Real        clkout0_duty_cycle;
   Real        clkout0_phase;
   Bool        clkout1_buffer;
   Bool        clkout1n_buffer;
   Integer     clkout1_divide;
   Real        clkout1_duty_cycle;
   Real        clkout1_phase;
   Bool        clkout2_buffer;
   Bool        clkout2n_buffer;
   Integer     clkout2_divide;
   Real        clkout2_duty_cycle;
   Real        clkout2_phase;
   Bool        clkout3_buffer;
   Bool        clkout3n_buffer;
   Integer     clkout3_divide;
   Real        clkout3_duty_cycle;
   Real        clkout3_phase;
   Bool        clkout4_buffer;
   Integer     clkout4_divide;
   Real        clkout4_duty_cycle;
   Real        clkout4_phase;
   Bool        clkout5_buffer;
   Integer     clkout5_divide;
   Real        clkout5_duty_cycle;
   Real        clkout5_phase;
   Bool        clkout6_buffer;
   Integer     clkout6_divide;
   Real        clkout6_duty_cycle;
   Real        clkout6_phase;
   Bool        use_same_family;
} ClockGenerator6Params deriving (Bits, Eq);

instance DefaultValue#(ClockGenerator6Params);
   defaultValue = ClockGenerator6Params {
      clkin_buffer:       True,
      clkin1_period:      5.000,
      reset_stages:       3,
      clkfbout_mult_f:    1.000,
      clkfbout_phase:     0.000,
      divclk_divide:      1,
      clkout0_buffer:     True,
      clkout0n_buffer:    True,
      clkout0_divide_f:   1.000,
      clkout0_duty_cycle: 0.500,
      clkout0_phase:      0.000,
      clkout1_buffer:     True,
      clkout1n_buffer:    True,
      clkout1_divide:     1,
      clkout1_duty_cycle: 0.500,
      clkout1_phase:      0.000,
      clkout2_buffer:     True,
      clkout2n_buffer:    True,
      clkout2_divide:     1,
      clkout2_duty_cycle: 0.500,
      clkout2_phase:      0.000,
      clkout3_buffer:     True,
      clkout3n_buffer:    True,
      clkout3_divide:     1,
      clkout3_duty_cycle: 0.500,
      clkout3_phase:      0.000,
      clkout4_buffer:     True,
      clkout4_divide:     1,
      clkout4_duty_cycle: 0.500,
      clkout4_phase:      0.000,
      clkout5_buffer:     True,
      clkout5_divide:     1,
      clkout5_duty_cycle: 0.500,
      clkout5_phase:      0.000,
      clkout6_buffer:     True,
      clkout6_divide:     1,
      clkout6_duty_cycle: 0.500,
      clkout6_phase:      0.000,
      use_same_family:    False
      };
endinstance

interface ClockGenerator6;
   interface Clock        clkout0;
   interface Clock        clkout0_n;
   interface Clock        clkout1;
   interface Clock        clkout1_n;
   interface Clock        clkout2;
   interface Clock        clkout2_n;
   interface Clock        clkout3;
   interface Clock        clkout3_n;
   interface Clock        clkout4;
   interface Clock        clkout5;
   interface Clock        clkout6;
   (* always_ready *)
   method    Bool         locked;
endinterface

module mkClockGenerator6#(ClockGenerator6Params params)(ClockGenerator6);

   ////////////////////////////////////////////////////////////////////////////////
   /// Clocks & Resets
   ////////////////////////////////////////////////////////////////////////////////
   Clock                                     clk                 <- exposeCurrentClock;
   Clock                                     clk_buffered         = ?;

   if (params.clkin_buffer) begin
      Clock inbuffer <- mkClockIBUFG(defaultValue);
      clk_buffered = inbuffer;
   end
   else begin
      clk_buffered = clk;
   end

   Reset                                     rst_n               <- mkAsyncResetFromCR(params.reset_stages, clk_buffered);
   Reset                                     rst                 <- mkResetInverter(rst_n);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   MMCMParams                                clkgen_params        = defaultValue;
   clkgen_params.clkin1_period      = params.clkin1_period;
   clkgen_params.clkfbout_mult_f    = params.clkfbout_mult_f;
   clkgen_params.clkfbout_phase     = params.clkfbout_phase;
   clkgen_params.divclk_divide      = params.divclk_divide;
   clkgen_params.clkout0_divide_f   = params.clkout0_divide_f;
   clkgen_params.clkout0_duty_cycle = params.clkout0_duty_cycle;
   clkgen_params.clkout0_phase      = params.clkout0_phase;
   clkgen_params.clkout1_divide     = params.clkout1_divide;
   clkgen_params.clkout1_duty_cycle = params.clkout1_duty_cycle;
   clkgen_params.clkout1_phase      = params.clkout1_phase;
   clkgen_params.clkout2_divide     = params.clkout2_divide;
   clkgen_params.clkout2_duty_cycle = params.clkout2_duty_cycle;
   clkgen_params.clkout2_phase      = params.clkout2_phase;
   clkgen_params.clkout3_divide     = params.clkout3_divide;
   clkgen_params.clkout3_duty_cycle = params.clkout3_duty_cycle;
   clkgen_params.clkout3_phase      = params.clkout3_phase;
   clkgen_params.clkout4_divide     = params.clkout4_divide;
   clkgen_params.clkout4_duty_cycle = params.clkout4_duty_cycle;
   clkgen_params.clkout4_phase      = params.clkout4_phase;
   clkgen_params.clkout5_divide     = params.clkout5_divide;
   clkgen_params.clkout5_duty_cycle = params.clkout5_duty_cycle;
   clkgen_params.clkout5_phase      = params.clkout5_phase;
   clkgen_params.clkout6_divide     = params.clkout6_divide;
   clkgen_params.clkout6_duty_cycle = params.clkout6_duty_cycle;
   clkgen_params.clkout6_phase      = params.clkout6_phase;
   clkgen_params.use_same_family    = params.use_same_family;

   MMCME2                                    pll                 <- mkMMCM(clkgen_params);

   Clock                                     clkout0_buf          = ?;
   Clock                                     clkout0n_buf         = ?;
   Clock                                     clkout1_buf          = ?;
   Clock                                     clkout1n_buf         = ?;
   Clock                                     clkout2_buf          = ?;
   Clock                                     clkout2n_buf         = ?;
   Clock                                     clkout3_buf          = ?;
   Clock                                     clkout3n_buf         = ?;
   Clock                                     clkout4_buf          = ?;
   Clock                                     clkout5_buf          = ?;
   Clock                                     clkout6_buf          = ?;

   if (params.clkout0_buffer) begin
      Clock clkout0buffer <- mkClockBUFG(clocked_by pll.clkout0);
      clkout0_buf = clkout0buffer;
   end
   else begin
      clkout0_buf = pll.clkout0;
   end

   if (params.clkout0n_buffer) begin
      Clock clkout0nbuffer <- mkClockBUFG(clocked_by pll.clkout0_n);
      clkout0n_buf = clkout0nbuffer;
   end
   else begin
      clkout0n_buf = pll.clkout0_n;
   end

   if (params.clkout1_buffer) begin
      Clock clkout1buffer <- mkClockBUFG(clocked_by pll.clkout1);
      clkout1_buf = clkout1buffer;
   end
   else begin
      clkout1_buf = pll.clkout1;
   end

   if (params.clkout1n_buffer) begin
      Clock clkout1nbuffer <- mkClockBUFG(clocked_by pll.clkout1_n);
      clkout1n_buf = clkout1nbuffer;
   end
   else begin
      clkout1n_buf = pll.clkout1_n;
   end

   if (params.clkout2_buffer) begin
      Clock clkout2buffer <- mkClockBUFG(clocked_by pll.clkout2);
      clkout2_buf = clkout2buffer;
   end
   else begin
      clkout2_buf = pll.clkout2;
   end

   if (params.clkout2n_buffer) begin
      Clock clkout2nbuffer <- mkClockBUFG(clocked_by pll.clkout2_n);
      clkout2n_buf = clkout2nbuffer;
   end
   else begin
      clkout2n_buf = pll.clkout2_n;
   end

   if (params.clkout3_buffer) begin
      Clock clkout3buffer <- mkClockBUFG(clocked_by pll.clkout3);
      clkout3_buf = clkout3buffer;
   end
   else begin
      clkout3_buf = pll.clkout3;
   end

   if (params.clkout3n_buffer) begin
      Clock clkout3nbuffer <- mkClockBUFG(clocked_by pll.clkout3_n);
      clkout3n_buf = clkout3nbuffer;
   end
   else begin
      clkout3n_buf = pll.clkout3_n;
   end

   if (params.clkout4_buffer) begin
      Clock clkout4buffer <- mkClockBUFG(clocked_by pll.clkout4);
      clkout4_buf = clkout4buffer;
   end
   else begin
      clkout4_buf = pll.clkout4;
   end

   if (params.clkout5_buffer) begin
      Clock clkout5buffer <- mkClockBUFG(clocked_by pll.clkout5);
      clkout5_buf = clkout5buffer;
   end
   else begin
      clkout5_buf = pll.clkout5;
   end

   if (params.clkout6_buffer) begin
      Clock clkout6buffer <- mkClockBUFG(clocked_by pll.clkout6);
      clkout6_buf = clkout6buffer;
   end
   else begin
      clkout6_buf = pll.clkout6;
   end

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////

   interface Clock        clkout0   = clkout0_buf;
   interface Clock        clkout0_n = clkout0n_buf;
   interface Clock        clkout1   = clkout1_buf;
   interface Clock        clkout1_n = clkout1n_buf;
   interface Clock        clkout2   = clkout2_buf;
   interface Clock        clkout2_n = clkout2n_buf;
   interface Clock        clkout3   = clkout3_buf;
   interface Clock        clkout3_n = clkout3n_buf;
   interface Clock        clkout4   = clkout4_buf;
   interface Clock        clkout5   = clkout5_buf;
   interface Clock        clkout6   = clkout6_buf;
   method    Bool         locked    = pll.locked;
endmodule: mkClockGenerator6

////////////////////////////////////////////////////////////////////////////////
/// ClockGenerator Kintex 7
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   Bool        clkin_buffer;
   Real        clkin1_period;
   Integer     reset_stages;
   Real        clkfbout_mult_f;
   Real        clkfbout_phase;
   Integer     divclk_divide;
   Bool        clkout0_buffer;
   Bool        clkout0n_buffer;
   Real        clkout0_divide_f;
   Real        clkout0_duty_cycle;
   Real        clkout0_phase;
   Bool        clkout1_buffer;
   Bool        clkout1n_buffer;
   Integer     clkout1_divide;
   Real        clkout1_duty_cycle;
   Real        clkout1_phase;
   Bool        clkout2_buffer;
   Bool        clkout2n_buffer;
   Integer     clkout2_divide;
   Real        clkout2_duty_cycle;
   Real        clkout2_phase;
   Bool        clkout3_buffer;
   Bool        clkout3n_buffer;
   Integer     clkout3_divide;
   Real        clkout3_duty_cycle;
   Real        clkout3_phase;
   Bool        clkout4_buffer;
   Integer     clkout4_divide;
   Real        clkout4_duty_cycle;
   Real        clkout4_phase;
   Bool        clkout5_buffer;
   Integer     clkout5_divide;
   Real        clkout5_duty_cycle;
   Real        clkout5_phase;
   Bool        clkout6_buffer;
   Integer     clkout6_divide;
   Real        clkout6_duty_cycle;
   Real        clkout6_phase;
   Bool        use_same_family;
} ClockGenerator7Params deriving (Bits, Eq);

instance DefaultValue#(ClockGenerator7Params);
   defaultValue = ClockGenerator7Params {
      clkin_buffer:       True,
      clkin1_period:      5.000,
      reset_stages:       3,
      clkfbout_mult_f:    1.000,
      clkfbout_phase:     0.000,
      divclk_divide:      1,
      clkout0_buffer:     True,
      clkout0n_buffer:    True,
      clkout0_divide_f:   10.000,
      clkout0_duty_cycle: 0.500,
      clkout0_phase:      0.000,
      clkout1_buffer:     True,
      clkout1n_buffer:    True,
      clkout1_divide:     10,
      clkout1_duty_cycle: 0.500,
      clkout1_phase:      0.000,
      clkout2_buffer:     True,
      clkout2n_buffer:    True,
      clkout2_divide:     10,
      clkout2_duty_cycle: 0.500,
      clkout2_phase:      0.000,
      clkout3_buffer:     True,
      clkout3n_buffer:    True,
      clkout3_divide:     10,
      clkout3_duty_cycle: 0.500,
      clkout3_phase:      0.000,
      clkout4_buffer:     True,
      clkout4_divide:     10,
      clkout4_duty_cycle: 0.500,
      clkout4_phase:      0.000,
      clkout5_buffer:     True,
      clkout5_divide:     10,
      clkout5_duty_cycle: 0.500,
      clkout5_phase:      0.000,
      clkout6_buffer:     True,
      clkout6_divide:     10,
      clkout6_duty_cycle: 0.500,
      clkout6_phase:      0.000,
      use_same_family:    False
      };
endinstance

interface ClockGenerator7;
   interface Clock        clkout0;
   interface Clock        clkout0_n;
   interface Clock        clkout1;
   interface Clock        clkout1_n;
   interface Clock        clkout2;
   interface Clock        clkout2_n;
   interface Clock        clkout3;
   interface Clock        clkout3_n;
   interface Clock        clkout4;
   interface Clock        clkout5;
   interface Clock        clkout6;
   (* always_ready *)
   method    Bool         locked;
endinterface

module mkClockGenerator7#(ClockGenerator7Params params)(ClockGenerator7);

   ////////////////////////////////////////////////////////////////////////////////
   /// Clocks & Resets
   ////////////////////////////////////////////////////////////////////////////////
   Clock                                     clk                 <- exposeCurrentClock;
   Clock                                     clk_buffered         = ?;

   if (params.clkin_buffer) begin
      Clock inbuffer <- mkClockIBUFG(defaultValue);
      clk_buffered = inbuffer;
   end
   else begin
      clk_buffered = clk;
   end

   Reset                                     rst_n               <- mkAsyncResetFromCR(params.reset_stages, clk_buffered);
   Reset                                     rst                 <- mkResetInverter(rst_n);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   MMCMParams                                clkgen_params        = defaultValue;
   clkgen_params.clkin1_period      = params.clkin1_period;
   clkgen_params.clkfbout_mult_f    = params.clkfbout_mult_f;
   clkgen_params.clkfbout_phase     = params.clkfbout_phase;
   clkgen_params.divclk_divide      = params.divclk_divide;
   clkgen_params.clkout0_divide_f   = params.clkout0_divide_f;
   clkgen_params.clkout0_duty_cycle = params.clkout0_duty_cycle;
   clkgen_params.clkout0_phase      = params.clkout0_phase;
   clkgen_params.clkout1_divide     = params.clkout1_divide;
   clkgen_params.clkout1_duty_cycle = params.clkout1_duty_cycle;
   clkgen_params.clkout1_phase      = params.clkout1_phase;
   clkgen_params.clkout2_divide     = params.clkout2_divide;
   clkgen_params.clkout2_duty_cycle = params.clkout2_duty_cycle;
   clkgen_params.clkout2_phase      = params.clkout2_phase;
   clkgen_params.clkout3_divide     = params.clkout3_divide;
   clkgen_params.clkout3_duty_cycle = params.clkout3_duty_cycle;
   clkgen_params.clkout3_phase      = params.clkout3_phase;
   clkgen_params.clkout4_divide     = params.clkout4_divide;
   clkgen_params.clkout4_duty_cycle = params.clkout4_duty_cycle;
   clkgen_params.clkout4_phase      = params.clkout4_phase;
   clkgen_params.clkout5_divide     = params.clkout5_divide;
   clkgen_params.clkout5_duty_cycle = params.clkout5_duty_cycle;
   clkgen_params.clkout5_phase      = params.clkout5_phase;
   clkgen_params.clkout6_divide     = params.clkout6_divide;
   clkgen_params.clkout6_duty_cycle = params.clkout6_duty_cycle;
   clkgen_params.clkout6_phase      = params.clkout6_phase;
   clkgen_params.use_same_family    = params.use_same_family;

   MMCME2                                    pll                 <- mkMMCME2(clkgen_params);

   Clock                                     clkout0_buf          = ?;
   Clock                                     clkout0n_buf         = ?;
   Clock                                     clkout1_buf          = ?;
   Clock                                     clkout1n_buf         = ?;
   Clock                                     clkout2_buf          = ?;
   Clock                                     clkout2n_buf         = ?;
   Clock                                     clkout3_buf          = ?;
   Clock                                     clkout3n_buf         = ?;
   Clock                                     clkout4_buf          = ?;
   Clock                                     clkout5_buf          = ?;
   Clock                                     clkout6_buf          = ?;

   if (params.clkout0_buffer) begin
      Clock clkout0buffer <- mkClockBUFG(clocked_by pll.clkout0);
      clkout0_buf = clkout0buffer;
   end
   else begin
      clkout0_buf = pll.clkout0;
   end

   if (params.clkout0n_buffer) begin
      Clock clkout0nbuffer <- mkClockBUFG(clocked_by pll.clkout0_n);
      clkout0n_buf = clkout0nbuffer;
   end
   else begin
      clkout0n_buf = pll.clkout0_n;
   end

   if (params.clkout1_buffer) begin
      Clock clkout1buffer <- mkClockBUFG(clocked_by pll.clkout1);
      clkout1_buf = clkout1buffer;
   end
   else begin
      clkout1_buf = pll.clkout1;
   end

   if (params.clkout1n_buffer) begin
      Clock clkout1nbuffer <- mkClockBUFG(clocked_by pll.clkout1_n);
      clkout1n_buf = clkout1nbuffer;
   end
   else begin
      clkout1n_buf = pll.clkout1_n;
   end

   if (params.clkout2_buffer) begin
      Clock clkout2buffer <- mkClockBUFG(clocked_by pll.clkout2);
      clkout2_buf = clkout2buffer;
   end
   else begin
      clkout2_buf = pll.clkout2;
   end

   if (params.clkout2n_buffer) begin
      Clock clkout2nbuffer <- mkClockBUFG(clocked_by pll.clkout2_n);
      clkout2n_buf = clkout2nbuffer;
   end
   else begin
      clkout2n_buf = pll.clkout2_n;
   end

   if (params.clkout3_buffer) begin
      Clock clkout3buffer <- mkClockBUFG(clocked_by pll.clkout3);
      clkout3_buf = clkout3buffer;
   end
   else begin
      clkout3_buf = pll.clkout3;
   end

   if (params.clkout3n_buffer) begin
      Clock clkout3nbuffer <- mkClockBUFG(clocked_by pll.clkout3_n);
      clkout3n_buf = clkout3nbuffer;
   end
   else begin
      clkout3n_buf = pll.clkout3_n;
   end

   if (params.clkout4_buffer) begin
      Clock clkout4buffer <- mkClockBUFG(clocked_by pll.clkout4);
      clkout4_buf = clkout4buffer;
   end
   else begin
      clkout4_buf = pll.clkout4;
   end

   if (params.clkout5_buffer) begin
      Clock clkout5buffer <- mkClockBUFG(clocked_by pll.clkout5);
      clkout5_buf = clkout5buffer;
   end
   else begin
      clkout5_buf = pll.clkout5;
   end

   if (params.clkout6_buffer) begin
      Clock clkout6buffer <- mkClockBUFG(clocked_by pll.clkout6);
      clkout6_buf = clkout6buffer;
   end
   else begin
      clkout6_buf = pll.clkout6;
   end

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////

   interface Clock        clkout0   = clkout0_buf;
   interface Clock        clkout0_n = clkout0n_buf;
   interface Clock        clkout1   = clkout1_buf;
   interface Clock        clkout1_n = clkout1n_buf;
   interface Clock        clkout2   = clkout2_buf;
   interface Clock        clkout2_n = clkout2n_buf;
   interface Clock        clkout3   = clkout3_buf;
   interface Clock        clkout3_n = clkout3n_buf;
   interface Clock        clkout4   = clkout4_buf;
   interface Clock        clkout5   = clkout5_buf;
   interface Clock        clkout6   = clkout6_buf;
   method    Bool         locked    = pll.locked;
endmodule: mkClockGenerator7

////////////////////////////////////////////////////////////////////////////////
/// ClockGenerator Ultrascale
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   Bool        clkin_buffer;
   Real        clkin1_period;
   Integer     reset_stages;
   Real        clkfbout_mult_f;
   Real        clkfbout_phase;
   Integer     divclk_divide;
   Bool        clkout0_buffer;
   Bool        clkout0n_buffer;
   Real        clkout0_divide_f;
   Real        clkout0_duty_cycle;
   Real        clkout0_phase;
   Bool        clkout1_buffer;
   Bool        clkout1n_buffer;
   Integer     clkout1_divide;
   Real        clkout1_duty_cycle;
   Real        clkout1_phase;
   Bool        clkout2_buffer;
   Bool        clkout2n_buffer;
   Integer     clkout2_divide;
   Real        clkout2_duty_cycle;
   Real        clkout2_phase;
   Bool        clkout3_buffer;
   Bool        clkout3n_buffer;
   Integer     clkout3_divide;
   Real        clkout3_duty_cycle;
   Real        clkout3_phase;
   Bool        clkout4_buffer;
   Integer     clkout4_divide;
   Real        clkout4_duty_cycle;
   Real        clkout4_phase;
   Bool        clkout5_buffer;
   Integer     clkout5_divide;
   Real        clkout5_duty_cycle;
   Real        clkout5_phase;
   Bool        clkout6_buffer;
   Integer     clkout6_divide;
   Real        clkout6_duty_cycle;
   Real        clkout6_phase;
   Bool        use_same_family;
} ClockGeneratorUParams deriving (Bits, Eq);

instance DefaultValue#(ClockGeneratorUParams);
   defaultValue = ClockGeneratorUParams {
      clkin_buffer:       True,
      clkin1_period:      5.000,
      reset_stages:       3,
      clkfbout_mult_f:    1.000,
      clkfbout_phase:     0.000,
      divclk_divide:      1,
      clkout0_buffer:     True,
      clkout0n_buffer:    True,
      clkout0_divide_f:   10.000,
      clkout0_duty_cycle: 0.500,
      clkout0_phase:      0.000,
      clkout1_buffer:     True,
      clkout1n_buffer:    True,
      clkout1_divide:     10,
      clkout1_duty_cycle: 0.500,
      clkout1_phase:      0.000,
      clkout2_buffer:     True,
      clkout2n_buffer:    True,
      clkout2_divide:     10,
      clkout2_duty_cycle: 0.500,
      clkout2_phase:      0.000,
      clkout3_buffer:     True,
      clkout3n_buffer:    True,
      clkout3_divide:     10,
      clkout3_duty_cycle: 0.500,
      clkout3_phase:      0.000,
      clkout4_buffer:     True,
      clkout4_divide:     10,
      clkout4_duty_cycle: 0.500,
      clkout4_phase:      0.000,
      clkout5_buffer:     True,
      clkout5_divide:     10,
      clkout5_duty_cycle: 0.500,
      clkout5_phase:      0.000,
      clkout6_buffer:     True,
      clkout6_divide:     10,
      clkout6_duty_cycle: 0.500,
      clkout6_phase:      0.000,
      use_same_family:    False
      };
endinstance

interface ClockGeneratorU;
   interface Clock        clkout0;
   interface Clock        clkout0_n;
   interface Clock        clkout1;
   interface Clock        clkout1_n;
   interface Clock        clkout2;
   interface Clock        clkout2_n;
   interface Clock        clkout3;
   interface Clock        clkout3_n;
   interface Clock        clkout4;
   interface Clock        clkout5;
   interface Clock        clkout6;
   (* always_ready *)
   method    Bool         locked;
endinterface

module mkClockGeneratorU#(ClockGeneratorUParams params)(ClockGeneratorU);

   ////////////////////////////////////////////////////////////////////////////////
   /// Clocks & Resets
   ////////////////////////////////////////////////////////////////////////////////
   Clock                                     clk                 <- exposeCurrentClock;
   Clock                                     clk_buffered         = ?;

   if (params.clkin_buffer) begin
      Clock inbuffer <- mkClockIBUFG(defaultValue);
      clk_buffered = inbuffer;
   end
   else begin
      clk_buffered = clk;
   end

   Reset                                     rst_n               <- mkAsyncResetFromCR(params.reset_stages, clk_buffered);
   Reset                                     rst                 <- mkResetInverter(rst_n);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   MMCMParams                                clkgen_params        = defaultValue;
   clkgen_params.clkin1_period      = params.clkin1_period;
   clkgen_params.clkfbout_mult_f    = params.clkfbout_mult_f;
   clkgen_params.clkfbout_phase     = params.clkfbout_phase;
   clkgen_params.divclk_divide      = params.divclk_divide;
   clkgen_params.clkout0_divide_f   = params.clkout0_divide_f;
   clkgen_params.clkout0_duty_cycle = params.clkout0_duty_cycle;
   clkgen_params.clkout0_phase      = params.clkout0_phase;
   clkgen_params.clkout1_divide     = params.clkout1_divide;
   clkgen_params.clkout1_duty_cycle = params.clkout1_duty_cycle;
   clkgen_params.clkout1_phase      = params.clkout1_phase;
   clkgen_params.clkout2_divide     = params.clkout2_divide;
   clkgen_params.clkout2_duty_cycle = params.clkout2_duty_cycle;
   clkgen_params.clkout2_phase      = params.clkout2_phase;
   clkgen_params.clkout3_divide     = params.clkout3_divide;
   clkgen_params.clkout3_duty_cycle = params.clkout3_duty_cycle;
   clkgen_params.clkout3_phase      = params.clkout3_phase;
   clkgen_params.clkout4_divide     = params.clkout4_divide;
   clkgen_params.clkout4_duty_cycle = params.clkout4_duty_cycle;
   clkgen_params.clkout4_phase      = params.clkout4_phase;
   clkgen_params.clkout5_divide     = params.clkout5_divide;
   clkgen_params.clkout5_duty_cycle = params.clkout5_duty_cycle;
   clkgen_params.clkout5_phase      = params.clkout5_phase;
   clkgen_params.clkout6_divide     = params.clkout6_divide;
   clkgen_params.clkout6_duty_cycle = params.clkout6_duty_cycle;
   clkgen_params.clkout6_phase      = params.clkout6_phase;
   clkgen_params.use_same_family    = params.use_same_family;

   MMCME3                                    pll                 <- mkMMCME3(clkgen_params);

   Clock                                     clkout0_buf          = ?;
   Clock                                     clkout0n_buf         = ?;
   Clock                                     clkout1_buf          = ?;
   Clock                                     clkout1n_buf         = ?;
   Clock                                     clkout2_buf          = ?;
   Clock                                     clkout2n_buf         = ?;
   Clock                                     clkout3_buf          = ?;
   Clock                                     clkout3n_buf         = ?;
   Clock                                     clkout4_buf          = ?;
   Clock                                     clkout5_buf          = ?;
   Clock                                     clkout6_buf          = ?;

   if (params.clkout0_buffer) begin
      Clock clkout0buffer <- mkClockBUFG(clocked_by pll.clkout0);
      clkout0_buf = clkout0buffer;
   end
   else begin
      clkout0_buf = pll.clkout0;
   end

   if (params.clkout0n_buffer) begin
      Clock clkout0nbuffer <- mkClockBUFG(clocked_by pll.clkout0_n);
      clkout0n_buf = clkout0nbuffer;
   end
   else begin
      clkout0n_buf = pll.clkout0_n;
   end

   if (params.clkout1_buffer) begin
      Clock clkout1buffer <- mkClockBUFG(clocked_by pll.clkout1);
      clkout1_buf = clkout1buffer;
   end
   else begin
      clkout1_buf = pll.clkout1;
   end

   if (params.clkout1n_buffer) begin
      Clock clkout1nbuffer <- mkClockBUFG(clocked_by pll.clkout1_n);
      clkout1n_buf = clkout1nbuffer;
   end
   else begin
      clkout1n_buf = pll.clkout1_n;
   end

   if (params.clkout2_buffer) begin
      Clock clkout2buffer <- mkClockBUFG(clocked_by pll.clkout2);
      clkout2_buf = clkout2buffer;
   end
   else begin
      clkout2_buf = pll.clkout2;
   end

   if (params.clkout2n_buffer) begin
      Clock clkout2nbuffer <- mkClockBUFG(clocked_by pll.clkout2_n);
      clkout2n_buf = clkout2nbuffer;
   end
   else begin
      clkout2n_buf = pll.clkout2_n;
   end

   if (params.clkout3_buffer) begin
      Clock clkout3buffer <- mkClockBUFG(clocked_by pll.clkout3);
      clkout3_buf = clkout3buffer;
   end
   else begin
      clkout3_buf = pll.clkout3;
   end

   if (params.clkout3n_buffer) begin
      Clock clkout3nbuffer <- mkClockBUFG(clocked_by pll.clkout3_n);
      clkout3n_buf = clkout3nbuffer;
   end
   else begin
      clkout3n_buf = pll.clkout3_n;
   end

   if (params.clkout4_buffer) begin
      Clock clkout4buffer <- mkClockBUFG(clocked_by pll.clkout4);
      clkout4_buf = clkout4buffer;
   end
   else begin
      clkout4_buf = pll.clkout4;
   end

   if (params.clkout5_buffer) begin
      Clock clkout5buffer <- mkClockBUFG(clocked_by pll.clkout5);
      clkout5_buf = clkout5buffer;
   end
   else begin
      clkout5_buf = pll.clkout5;
   end

   if (params.clkout6_buffer) begin
      Clock clkout6buffer <- mkClockBUFG(clocked_by pll.clkout6);
      clkout6_buf = clkout6buffer;
   end
   else begin
      clkout6_buf = pll.clkout6;
   end

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////

   interface Clock        clkout0   = clkout0_buf;
   interface Clock        clkout0_n = clkout0n_buf;
   interface Clock        clkout1   = clkout1_buf;
   interface Clock        clkout1_n = clkout1n_buf;
   interface Clock        clkout2   = clkout2_buf;
   interface Clock        clkout2_n = clkout2n_buf;
   interface Clock        clkout3   = clkout3_buf;
   interface Clock        clkout3_n = clkout3n_buf;
   interface Clock        clkout4   = clkout4_buf;
   interface Clock        clkout5   = clkout5_buf;
   interface Clock        clkout6   = clkout6_buf;
   method    Bool         locked    = pll.locked;
endmodule: mkClockGeneratorU

////////////////////////////////////////////////////////////////////////////////
/// DCM_ADV
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   Real        clkdv_divide;
   Integer     clkfx_divide;
   Integer     clkfx_multiply;
   String      clkin_divide_by_2;
   Real        clkin_period;
   String      clkout_phase_shift;
   String      clk_feedback;
   String      dcm_autocalibration;
   String      dcm_performance_mode;
   String      deskew_adjust;
   String      dfs_frequency_mode;
   String      dll_frequency_mode;
   String      duty_cycle_correction;
   Bit#(16)    factory_jf;
   Integer     phase_shift;
   String      sim_device;
   String      startup_wait;
   } DCMParams deriving (Bits, Eq);

instance DefaultValue#(DCMParams);
   defaultValue = DCMParams {
      clkdv_divide:          2.0,
      clkfx_divide:          1,
      clkfx_multiply:        4,
      clkin_divide_by_2:     "FALSE",
      clkin_period:          10.0,
      clkout_phase_shift:    "NONE",
      clk_feedback:          "1X",
      dcm_autocalibration:   "TRUE",
      dcm_performance_mode:  "MAX_SPEED",
      deskew_adjust:         "SYSTEM_SYNCHRONOUS",
      dfs_frequency_mode:    "LOW",
      dll_frequency_mode:    "LOW",
      duty_cycle_correction: "TRUE",
      factory_jf:            16'hF0F0,
      phase_shift:           1,
      sim_device:            "VIRTEX4",
      startup_wait:          "FALSE"
      };
endinstance

interface VDCM;
   interface Clock       clkout0;
   interface Clock       clkout180;
   interface Clock       clkout270;
   interface Clock       clkout2x180;
   interface Clock       clkout2x;
   interface Clock       clkout90;
   interface Clock       clkoutdv;
   interface Clock       clkoutfx180;
   interface Clock       clkoutfx;
   interface VDCM_DRP    recfg;
   interface VDCM_PS     phase_shift;
   (* always_enabled *)
   method    Bool        locked();
   (* always_ready , always_enabled *)
   method    Action      fbin (Bool clkfb);
endinterface

interface VDCM_DRP;
   (* always_ready *)
   method    Action      request (Bool dwe, Bit#(7) daddr, Bit#(16) di);
   method    Bit#(16)    response();
endinterface

interface VDCM_PS;
   (* always_ready *)
   method    Action      incdec (Bool psincdec);
   (* always_enabled *)
   method    Bool        done();
endinterface

interface DCM;
   interface Clock       clkout0;
   interface Clock       clkout180;
   interface Clock       clkout270;
   interface Clock       clkout2x180;
   interface Clock       clkout2x;
   interface Clock       clkout90;
   interface Clock       clkoutdv;
   interface Clock       clkoutfx180;
   interface Clock       clkoutfx;
   interface DCM_DRP     recfg;
   interface DCM_PS      phase_shift;
   (* always_enabled *)
   method    Bool        locked();
   (* always_ready , always_enabled *)
   method    Action      fbin (Bool clkfb);
endinterface

interface DCM_DRP;
   (* always_ready *)
   method    Action      request (Bool dwe, Bit#(7) daddr, Bit#(16) di);
   method    Bit#(16)    response();
endinterface

interface DCM_PS;
   (* always_ready *)
   method    Action      incdec (Bool psincdec);
   (* always_enabled *)
   method    Bool        done();
endinterface

import "BVI" DCM_ADV =
module vMkDCM #(DCMParams params, Clock dclk, Clock psclk) (VDCM);
   default_clock clk(CLKIN);
   default_reset rst(RST);


   parameter CLKDV_DIVIDE          = params.clkdv_divide;
   parameter CLKFX_DIVIDE          = params.clkfx_divide;
   parameter CLKFX_MULTIPLY        = params.clkfx_multiply;
   parameter CLKIN_DIVIDE_BY_2     = params.clkin_divide_by_2;
   parameter CLKIN_PERIOD          = params.clkin_period;
   parameter CLKOUT_PHASE_SHIFT    = params.clkout_phase_shift;
   parameter CLK_FEEDBACK          = params.clk_feedback;
   parameter DCM_AUTOCALIBRATION   = params.dcm_autocalibration;
   parameter DCM_PERFORMANCE_MODE  = params.dcm_performance_mode;
   parameter DESKEW_ADJUST         = params.deskew_adjust;
   parameter DFS_FREQUENCY_MODE    = params.dfs_frequency_mode;
   parameter DLL_FREQUENCY_MODE    = params.dll_frequency_mode;
   parameter DUTY_CYCLE_CORRECTION = params.duty_cycle_correction;
   parameter FACTORY_JF            = params.factory_jf;
   parameter PHASE_SHIFT           = params.phase_shift;
   parameter SIM_DEVICE            = params.sim_device;
   parameter STARTUP_WAIT          = params.startup_wait;

   input_clock dclk (DCLK, (*unused*)DCLK_GATE)     = dclk;
   input_clock psclk (PSCLK, (*unused*)PSCLK_GATE)  = psclk;

   output_clock clkout0(CLK0);
   output_clock clkout180(CLK180);
   output_clock clkout270(CLK270);
   output_clock clkout2x180(CLK2X180);
   output_clock clkout2x(CLK2X);
   output_clock clkout90(CLK90);
   output_clock clkoutdv(CLKDV);
   output_clock clkoutfx180(CLKFX180);
   output_clock clkoutfx(CLKFX);

   method LOCKED locked()     clocked_by(no_clock) reset_by(no_reset);
   method        fbin(CLKFB)  enable((*inhigh*)iCLKFB_enable) clocked_by(clkout0) reset_by(no_reset);

   interface VDCM_DRP recfg;
      method request (DWE, DADDR, DI)   enable(DEN) clocked_by(dclk) reset_by(no_reset);
      method DO response ()             ready(DRDY) clocked_by(dclk) reset_by(no_reset);
   endinterface

   interface VDCM_PS phase_shift;
      method incdec (PSINCDEC)  enable(PSEN) clocked_by(psclk) reset_by(no_reset);
      method PSDONE done ()                  clocked_by(psclk) reset_by(no_reset);
   endinterface

   schedule (locked, fbin) CF (locked, fbin);
   schedule recfg_response SB recfg_request;
   schedule recfg_request C recfg_request;
   schedule recfg_response CF recfg_response;
   schedule phase_shift_incdec C phase_shift_incdec;
   schedule phase_shift_done SB phase_shift_incdec;
   schedule phase_shift_done CF phase_shift_done;
endmodule: vMkDCM


module mkDCM#(DCMParams params, Clock dclk, Clock psclk)(DCM);
   VDCM _dcm <- vMkDCM(params, dclk, psclk);

   interface clkout0     = _dcm.clkout0;
   interface clkout180   = _dcm.clkout180;
   interface clkout270   = _dcm.clkout270;
   interface clkout2x180 = _dcm.clkout2x180;
   interface clkout2x    = _dcm.clkout2x;
   interface clkout90    = _dcm.clkout90;
   interface clkoutdv    = _dcm.clkoutdv;
   interface clkoutfx180 = _dcm.clkoutfx180;
   interface clkoutfx    = _dcm.clkoutfx;

   interface DCM_DRP recfg;
      method request  = _dcm.recfg.request;
      method response = _dcm.recfg.response;
   endinterface

   interface DCM_PS phase_shift;
      method incdec   = _dcm.phase_shift.incdec;
      method done     = _dcm.phase_shift.done;
   endinterface

   method locked         = _dcm.locked;
   method fbin           = _dcm.fbin;
endmodule: mkDCM

////////////////////////////////////////////////////////////////////////////////
/// Clock Divider
////////////////////////////////////////////////////////////////////////////////
module mkDCMClockDivider#(Real divisor, Real fastPeriodNs)(ClockDividerIfc);

   if ((divisor <= 1) || (divisor > 16)) begin
      error("mkDCMClockDivider requires an integer:  1 < divisor <= 16");
   end

   ////////////////////////////////////////////////////////////////////////////////
   /// Clocks & Resets
   ////////////////////////////////////////////////////////////////////////////////
   Clock                                     fastclk             <- exposeCurrentClock;

   Reset                                     rst_n               <- mkAsyncResetFromCR(3, fastclk);
   Reset                                     rst                 <- mkResetInverter(rst_n);

   DCMParams                                 params               = defaultValue;
   params.clkin_period   = fastPeriodNs;
   params.clkdv_divide   = divisor;

   if (fastPeriodNs < 6.66) begin
      params.dfs_frequency_mode = "HIGH";
      params.dll_frequency_mode = "HIGH";
   end

   VDCM                                      clkdiv              <- vMkDCM(params, noClock, noClock, reset_by rst);

   Clock                                     fastbuf             <- mkClockBUFG(clocked_by clkdiv.clkout0);
   Reset                                     fastrst             <- mkAsyncReset(0, rst_n, fastbuf);
   Clock                                     slowbuf             <- mkClockBUFG(clocked_by clkdiv.clkoutdv);
   Reset                                     slowrst             <- mkAsyncReset(0, rst_n, slowbuf);
   ReadOnly#(Bool)                           clkfbbuf            <- mkClockBitBUFG(clocked_by clkdiv.clkout0);

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   CrossingReg#(Bool)                        sToggle             <- mkNullCrossingRegA(fastbuf, False, clocked_by slowbuf, reset_by slowrst);
   Reg#(Bool)                                fToggle_D1          <- mkRegA(False, clocked_by fastbuf, reset_by fastrst);

   Reg#(Bool)                                slowClockEn         <- mkRegA(False, clocked_by fastbuf, reset_by fastrst);

   Reg#(Bit#(5))                             count               <- mkRegU(clocked_by fastbuf);

   Bool   slowTogglePosedge = sToggle.crossed() && !fToggle_D1;
   Bool   slowToggleNegedge = fToggle_D1 && !sToggle.crossed();
   Bool   slowClockEdge     = slowTogglePosedge || slowToggleNegedge;

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* fire_when_enabled, no_implicit_conditions *)
   rule connect_feedback;
      clkdiv.fbin(clkfbbuf);
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule toggle_flop(clkdiv.locked);
      sToggle <= !sToggle;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule toggle_flop_delayed;
      fToggle_D1 <= sToggle.crossed;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule counter_update(slowClockEn);
      if (slowClockEdge)
         count <= 0;
      else
         count <= count + 1;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule slow_clock_enabled(!slowClockEn && slowClockEdge);
      slowClockEn <= True;
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface fastClock  = fastbuf;
   interface slowClock  = slowbuf;
   method    clockReady = (count == fromInteger(trunc(divisor) - 2));

endmodule: mkDCMClockDivider

////////////////////////////////////////////////////////////////////////////////
/// MMCM_ADV
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String      bandwidth;
   String      clkfbout_use_fine_ps;
   String      clkout0_use_fine_ps;
   String      clkout1_use_fine_ps;
   String      clkout2_use_fine_ps;
   String      clkout3_use_fine_ps;
   String      clkout4_cascade;
   String      clkout4_use_fine_ps;
   String      clkout5_use_fine_ps;
   String      clkout6_use_fine_ps;
   String      clock_hold;
   String      compensation;
   String      startup_wait;
   Real        clkfbout_mult_f;
   Real        clkfbout_phase;
   Real        clkin1_period;
   Real        clkin2_period;
   Integer     divclk_divide;
   Real        clkout0_divide_f;
   Real        clkout0_duty_cycle;
   Real        clkout0_phase;
   Integer     clkout1_divide;
   Real        clkout1_duty_cycle;
   Real        clkout1_phase;
   Integer     clkout2_divide;
   Real        clkout2_duty_cycle;
   Real        clkout2_phase;
   Integer     clkout3_divide;
   Real        clkout3_duty_cycle;
   Real        clkout3_phase;
   Integer     clkout4_divide;
   Real        clkout4_duty_cycle;
   Real        clkout4_phase;
   Integer     clkout5_divide;
   Real        clkout5_duty_cycle;
   Real        clkout5_phase;
   Integer     clkout6_divide;
   Real        clkout6_duty_cycle;
   Real        clkout6_phase;
   Real        ref_jitter1;
   Real        ref_jitter2;
   Bool        use_same_family;
} MMCMParams deriving (Bits, Eq);

instance DefaultValue#(MMCMParams);
   defaultValue = MMCMParams {
      bandwidth:             "OPTIMIZED",
      clkfbout_use_fine_ps:  "FALSE",
      clkout0_use_fine_ps:   "FALSE",
      clkout1_use_fine_ps:   "FALSE",
      clkout2_use_fine_ps:   "FALSE",
      clkout3_use_fine_ps:   "FALSE",
      clkout4_cascade:       "FALSE",
      clkout4_use_fine_ps:   "FALSE",
      clkout5_use_fine_ps:   "FALSE",
      clkout6_use_fine_ps:   "FALSE",
      clock_hold:            "FALSE",
      compensation:          "ZHOLD",
      startup_wait:          "FALSE",
      clkfbout_mult_f:       5.000,
      clkfbout_phase:        0.000,
      clkin1_period:         0.000,
      clkin2_period:         0.000,
      divclk_divide:         1,
      clkout0_divide_f:      1.000,
      clkout0_duty_cycle:    0.500,
      clkout0_phase:         0.000,
      clkout1_divide:        10,
      clkout1_duty_cycle:    0.500,
      clkout1_phase:         0.000,
      clkout2_divide:        10,
      clkout2_duty_cycle:    0.500,
      clkout2_phase:         0.000,
      clkout3_divide:        10,
      clkout3_duty_cycle:    0.500,
      clkout3_phase:         0.000,
      clkout4_divide:        10,
      clkout4_duty_cycle:    0.500,
      clkout4_phase:         0.000,
      clkout5_divide:        10,
      clkout5_duty_cycle:    0.500,
      clkout5_phase:         0.000,
      clkout6_divide:        10,
      clkout6_duty_cycle:    0.500,
      clkout6_phase:         0.000,
      ref_jitter1:           0.010,
      ref_jitter2:           0.010,
      use_same_family:       False
      };
endinstance

interface MMCM_DRP;
   method    Action   request(Bool write, Bit#(7) addr, Bit#(16) datain);
   method    Bit#(16) response;
endinterface

interface MMCM_CDDC;
   method    Action   request();
   method    Bool     done();
endinterface

(* always_ready, always_enabled *)
interface MMCM_PS;
   method    Action      incdec (Bool psincdec);
   method    Bool        done();
endinterface

interface MMCM;
   interface Clock     clkout0;
   interface Clock     clkout0_n;
   interface Clock     clkout1;
   interface Clock     clkout1_n;
   interface Clock     clkout2;
   interface Clock     clkout2_n;
   interface Clock     clkout3;
   interface Clock     clkout3_n;
   interface Clock     clkout4;
   interface Clock     clkout5;
   interface Clock     clkout6;
   interface Clock     clkfbout;
   interface Clock     clkfbout_n;
   interface MMCM_DRP  reconfig;
   interface MMCM_PS   phase_shift;
   (* always_ready, always_enabled *)
   method    Bool      locked;
   (* always_ready, always_enabled *)
   method    Bool      clkfb_stopped;
   (* always_ready, always_enabled *)
   method    Bool      clkin_stopped;
   (* always_ready, always_enabled *)
   method    Action    clkin1sel(Bool select);
   (* always_ready, always_enabled *)
   method    Action    clkfbin(Bit#(1) clk);
endinterface

import "BVI" MMCM_ADV =
module vMkMMCM#(MMCMParams params, Clock clkin2, Clock dclk, Clock psclk)(MMCM);
   Reset reset <- invertCurrentReset;

   default_clock clk1(CLKIN1);
   default_reset rst(RST) = reset;

   parameter BANDWIDTH            = params.bandwidth;
   parameter CLKFBOUT_USE_FINE_PS = params.clkfbout_use_fine_ps;
   parameter CLKOUT0_USE_FINE_PS  = params.clkout0_use_fine_ps;
   parameter CLKOUT1_USE_FINE_PS  = params.clkout1_use_fine_ps;
   parameter CLKOUT2_USE_FINE_PS  = params.clkout2_use_fine_ps;
   parameter CLKOUT3_USE_FINE_PS  = params.clkout3_use_fine_ps;
   parameter CLKOUT4_CASCADE      = params.clkout4_cascade;
   parameter CLKOUT4_USE_FINE_PS  = params.clkout4_use_fine_ps;
   parameter CLKOUT5_USE_FINE_PS  = params.clkout5_use_fine_ps;
   parameter CLKOUT6_USE_FINE_PS  = params.clkout6_use_fine_ps;
   parameter CLOCK_HOLD           = params.clock_hold;
   parameter COMPENSATION         = params.compensation;
   parameter STARTUP_WAIT         = params.startup_wait;
   parameter CLKFBOUT_MULT_F      = params.clkfbout_mult_f;
   parameter CLKFBOUT_PHASE       = params.clkfbout_phase;
   parameter CLKIN1_PERIOD        = params.clkin1_period;
   parameter CLKIN2_PERIOD        = params.clkin2_period;
   parameter DIVCLK_DIVIDE        = params.divclk_divide;
   parameter CLKOUT0_DIVIDE_F     = params.clkout0_divide_f;
   parameter CLKOUT0_DUTY_CYCLE   = params.clkout0_duty_cycle;
   parameter CLKOUT0_PHASE        = params.clkout0_phase;
   parameter CLKOUT1_DIVIDE       = params.clkout1_divide;
   parameter CLKOUT1_DUTY_CYCLE   = params.clkout1_duty_cycle;
   parameter CLKOUT1_PHASE        = params.clkout1_phase;
   parameter CLKOUT2_DIVIDE       = params.clkout2_divide;
   parameter CLKOUT2_DUTY_CYCLE   = params.clkout2_duty_cycle;
   parameter CLKOUT2_PHASE        = params.clkout2_phase;
   parameter CLKOUT3_DIVIDE       = params.clkout3_divide;
   parameter CLKOUT3_DUTY_CYCLE   = params.clkout3_duty_cycle;
   parameter CLKOUT3_PHASE        = params.clkout3_phase;
   parameter CLKOUT4_DIVIDE       = params.clkout4_divide;
   parameter CLKOUT4_DUTY_CYCLE   = params.clkout4_duty_cycle;
   parameter CLKOUT4_PHASE        = params.clkout4_phase;
   parameter CLKOUT5_DIVIDE       = params.clkout5_divide;
   parameter CLKOUT5_DUTY_CYCLE   = params.clkout5_duty_cycle;
   parameter CLKOUT5_PHASE        = params.clkout5_phase;
   parameter CLKOUT6_DIVIDE       = params.clkout6_divide;
   parameter CLKOUT6_DUTY_CYCLE   = params.clkout6_duty_cycle;
   parameter CLKOUT6_PHASE        = params.clkout6_phase;
   parameter REF_JITTER1          = params.ref_jitter1;
   parameter REF_JITTER2          = params.ref_jitter2;

   input_clock clk2(CLKIN2, (*unused*)CLKIN2_GATE)    = clkin2;
   input_clock dclk(DCLK, (*unused*)DCLK_GATE)        = dclk;
   input_clock psclk(PSCLK, (*unused*)PSCLK_GATE)     = psclk;

   output_clock clkfbout(CLKFBOUT);
   output_clock clkfbout_n(CLKFBOUTB);
   output_clock clkout0(CLKOUT0);
   output_clock clkout0_n(CLKOUT0B);
   output_clock clkout1(CLKOUT1);
   output_clock clkout1_n(CLKOUT1B);
   output_clock clkout2(CLKOUT2);
   output_clock clkout2_n(CLKOUT2B);
   output_clock clkout3(CLKOUT3);
   output_clock clkout3_n(CLKOUT3B);
   output_clock clkout4(CLKOUT4);
   output_clock clkout5(CLKOUT5);
   output_clock clkout6(CLKOUT6);

   port PWRDWN   = (Bit#(1)'(0));

   method LOCKED   locked()     clocked_by(no_clock) reset_by(no_reset);
   method CLKFBSTOPPED clkfb_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method CLKINSTOPPED clkin_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method          clkin1sel(CLKINSEL) enable((*inhigh*)en0) clocked_by(clk1) reset_by(no_reset);
   method          clkfbin(CLKFBIN) enable((*inhigh*)en1) clocked_by(clkfbout) reset_by(no_reset);

   interface MMCM_DRP reconfig;
      method       request(DWE, DADDR, DI) enable(DEN) clocked_by(dclk) reset_by(no_reset);
      method DO    response() ready(DRDY) clocked_by(dclk) reset_by(no_reset);
   endinterface

   interface MMCM_PS phase_shift;
      method incdec (PSINCDEC)  enable(PSEN) clocked_by(psclk) reset_by(no_reset);
      method PSDONE done ()                  clocked_by(psclk) reset_by(no_reset);
   endinterface

   schedule clkfbin C clkfbin;
   schedule clkin1sel C clkin1sel;
   schedule (locked, clkfb_stopped, clkin_stopped) CF (locked, clkfb_stopped, clkin_stopped);
   schedule reconfig_response SB reconfig_request;
   schedule reconfig_request C reconfig_request;
   schedule reconfig_response CF reconfig_response;
   schedule phase_shift_incdec C phase_shift_incdec;
   schedule phase_shift_done SB phase_shift_incdec;
   schedule phase_shift_done CF phase_shift_done;
endmodule

import "BVI" MMCM_ADV =
module vMkMMCMSF#(MMCMParams params, Clock clkin2, Clock dclk, Clock psclk)(MMCM);
   Reset reset <- invertCurrentReset;

   default_clock clk1(CLKIN1);
   default_reset rst(RST) = reset;

   parameter BANDWIDTH            = params.bandwidth;
   parameter CLKFBOUT_USE_FINE_PS = params.clkfbout_use_fine_ps;
   parameter CLKOUT0_USE_FINE_PS  = params.clkout0_use_fine_ps;
   parameter CLKOUT1_USE_FINE_PS  = params.clkout1_use_fine_ps;
   parameter CLKOUT2_USE_FINE_PS  = params.clkout2_use_fine_ps;
   parameter CLKOUT3_USE_FINE_PS  = params.clkout3_use_fine_ps;
   parameter CLKOUT4_CASCADE      = params.clkout4_cascade;
   parameter CLKOUT4_USE_FINE_PS  = params.clkout4_use_fine_ps;
   parameter CLKOUT5_USE_FINE_PS  = params.clkout5_use_fine_ps;
   parameter CLKOUT6_USE_FINE_PS  = params.clkout6_use_fine_ps;
   parameter CLOCK_HOLD           = params.clock_hold;
   parameter COMPENSATION         = params.compensation;
   parameter STARTUP_WAIT         = params.startup_wait;
   parameter CLKFBOUT_MULT_F      = params.clkfbout_mult_f;
   parameter CLKFBOUT_PHASE       = params.clkfbout_phase;
   parameter CLKIN1_PERIOD        = params.clkin1_period;
   parameter CLKIN2_PERIOD        = params.clkin2_period;
   parameter DIVCLK_DIVIDE        = params.divclk_divide;
   parameter CLKOUT0_DIVIDE_F     = params.clkout0_divide_f;
   parameter CLKOUT0_DUTY_CYCLE   = params.clkout0_duty_cycle;
   parameter CLKOUT0_PHASE        = params.clkout0_phase;
   parameter CLKOUT1_DIVIDE       = params.clkout1_divide;
   parameter CLKOUT1_DUTY_CYCLE   = params.clkout1_duty_cycle;
   parameter CLKOUT1_PHASE        = params.clkout1_phase;
   parameter CLKOUT2_DIVIDE       = params.clkout2_divide;
   parameter CLKOUT2_DUTY_CYCLE   = params.clkout2_duty_cycle;
   parameter CLKOUT2_PHASE        = params.clkout2_phase;
   parameter CLKOUT3_DIVIDE       = params.clkout3_divide;
   parameter CLKOUT3_DUTY_CYCLE   = params.clkout3_duty_cycle;
   parameter CLKOUT3_PHASE        = params.clkout3_phase;
   parameter CLKOUT4_DIVIDE       = params.clkout4_divide;
   parameter CLKOUT4_DUTY_CYCLE   = params.clkout4_duty_cycle;
   parameter CLKOUT4_PHASE        = params.clkout4_phase;
   parameter CLKOUT5_DIVIDE       = params.clkout5_divide;
   parameter CLKOUT5_DUTY_CYCLE   = params.clkout5_duty_cycle;
   parameter CLKOUT5_PHASE        = params.clkout5_phase;
   parameter CLKOUT6_DIVIDE       = params.clkout6_divide;
   parameter CLKOUT6_DUTY_CYCLE   = params.clkout6_duty_cycle;
   parameter CLKOUT6_PHASE        = params.clkout6_phase;
   parameter REF_JITTER1          = params.ref_jitter1;
   parameter REF_JITTER2          = params.ref_jitter2;

   input_clock clk2(CLKIN2, (*unused*)CLKIN2_GATE)    = clkin2;
   input_clock dclk(DCLK, (*unused*)DCLK_GATE)        = dclk;
   input_clock psclk(PSCLK, (*unused*)PSCLK_GATE)     = psclk;

   output_clock clkfbout(CLKFBOUT);
   output_clock clkfbout_n(CLKFBOUTB);
   output_clock clkout0(CLKOUT0);
   output_clock clkout0_n(CLKOUT0B);
   output_clock clkout1(CLKOUT1);
   output_clock clkout1_n(CLKOUT1B);
   output_clock clkout2(CLKOUT2);
   output_clock clkout2_n(CLKOUT2B);
   output_clock clkout3(CLKOUT3);
   output_clock clkout3_n(CLKOUT3B);
   output_clock clkout4(CLKOUT4);
   output_clock clkout5(CLKOUT5);
   output_clock clkout6(CLKOUT6);

   port PWRDWN   = (Bit#(1)'(0));

   method LOCKED   locked()     clocked_by(no_clock) reset_by(no_reset);
   method CLKFBSTOPPED clkfb_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method CLKINSTOPPED clkin_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method          clkin1sel(CLKINSEL) enable((*inhigh*)en0) clocked_by(clk1) reset_by(no_reset);
   method          clkfbin(CLKFBIN) enable((*inhigh*)en1) clocked_by(clkfbout) reset_by(no_reset);

   interface MMCM_DRP reconfig;
      method       request(DWE, DADDR, DI) enable(DEN) clocked_by(dclk) reset_by(no_reset);
      method DO    response() ready(DRDY) clocked_by(dclk) reset_by(no_reset);
   endinterface

   interface MMCM_PS phase_shift;
      method incdec (PSINCDEC)  enable(PSEN) clocked_by(psclk) reset_by(no_reset);
      method PSDONE done ()                  clocked_by(psclk) reset_by(no_reset);
   endinterface

   same_family(clk1, clkfbout);
   same_family(clk1, clkfbout_n);
   same_family(clk1, clkout0);
   same_family(clk1, clkout0_n);
   same_family(clk1, clkout1);
   same_family(clk1, clkout1_n);
   same_family(clk1, clkout2);
   same_family(clk1, clkout2_n);
   same_family(clk1, clkout3);
   same_family(clk1, clkout3_n);
   same_family(clk1, clkout4);
   same_family(clk1, clkout5);
   same_family(clk1, clkout6);

   schedule clkfbin C clkfbin;
   schedule clkin1sel C clkin1sel;
   schedule clkin1sel CF clkfbin;
   schedule (locked, clkfb_stopped, clkin_stopped) CF (locked, clkfb_stopped, clkin_stopped);
   schedule reconfig_response SB reconfig_request;
   schedule reconfig_request C reconfig_request;
   schedule reconfig_response CF reconfig_response;
   schedule phase_shift_incdec C phase_shift_incdec;
   schedule phase_shift_done SB phase_shift_incdec;
   schedule phase_shift_done CF phase_shift_done;
endmodule


module mkMMCMOrig#(MMCMParams params, Clock clkin2, Clock dclk, Clock psclk)(MMCM);
   MMCM _mmcm <- vMkMMCM(params, clkin2, dclk, psclk);
   return _mmcm;
endmodule

////////////////////////////////////////////////////////////////////////////////
/// SRL16E
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   Bit#(16)     initValue;
} SRL16EParams deriving (Bits, Eq);

instance DefaultValue#(SRL16EParams);
   defaultValue = SRL16EParams {
      initValue:       0
      };
endinstance

(* always_ready, always_enabled *)
interface VSRL16E;
   method    Bit#(1)   _read;
   method    Action    _write(Bit#(1) i);
   method    Action    a0(Bit#(1) i);
   method    Action    a1(Bit#(1) i);
   method    Action    a2(Bit#(1) i);
   method    Action    a3(Bit#(1) i);
endinterface

(* always_ready, always_enabled *)
interface SRL16E;
   method    Bit#(1)   _read;
   method    Action    _write(Bit#(1) i);
   method    Action    a(Bit#(4) i);
endinterface

import "BVI" SRL16E =
module vMkSRL16E#(SRL16EParams params)(VSRL16E);
   default_clock clk(CLK);
   default_reset no_reset;

   parameter INIT = params.initValue;

   method Q    _read();
   method      _write(D) enable(CE);
   method      a0(A0) enable((*inhigh*)en0);
   method      a1(A1) enable((*inhigh*)en1);
   method      a2(A2) enable((*inhigh*)en2);
   method      a3(A3) enable((*inhigh*)en3);

   schedule _write C _write;
   schedule _read SB _write;
   schedule _read CF _read;
   schedule (a0, a1, a2, a3) SB _write;
   schedule _read SB (a0, a1, a2, a3);
   schedule a0 C a0;
   schedule a1 C a1;
   schedule a2 C a2;
   schedule a3 C a3;
   schedule a0 CF (a1, a2, a3);
   schedule a1 CF (a0, a2, a3);
   schedule a2 CF (a0, a1, a3);
   schedule a3 CF (a0, a1, a2);
endmodule

module mkSRL16E#(SRL16EParams params)(SRL16E);
   VSRL16E _srl <- vMkSRL16E(params);

   method _read     = _srl._read;
   method _write(x) = _srl._write(x);
   method Action a(x);
      _srl.a0(x[0]);
      _srl.a1(x[1]);
      _srl.a2(x[2]);
      _srl.a3(x[3]);
   endmethod
endmodule

////////////////////////////////////////////////////////////////////////////////
/// SRLC32E
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   Bit#(32)     initValue;
} SRLC32EParams deriving (Bits, Eq);

instance DefaultValue#(SRLC32EParams);
   defaultValue = SRLC32EParams {
      initValue:       0
      };
endinstance

(* always_ready, always_enabled *)
interface SRLC32E;
   method    Bit#(1)   _read;
   method    Action    _write(Bit#(1) i);
   method    Action    a(Bit#(5) i);
   method    Bit#(1)   cascade();
endinterface

import "BVI" SRLC32E =
module vMkSRLC32E#(SRLC32EParams params)(SRLC32E);
   default_clock clk(CLK);
   default_reset no_reset;

   parameter INIT = params.initValue;

   method Q    _read();
   method      _write(D) enable(CE);
   method      a(A) enable((*inhigh*)en0);
   method Q31  cascade();

   schedule _write C _write;
   schedule (_read, cascade) SB _write;
   schedule a SB _write;
   schedule (_read, cascade) SB a;
   schedule a C a;
   schedule (_read, cascade) CF (_read, cascade);
endmodule

module mkSRLC32E#(SRLC32EParams params)(SRLC32E);
   let _m <- vMkSRLC32E(params);
   return _m;
endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import "BVI" MMCM_ADV =
module vMkMMCM_ADV#(MMCMParams params, Clock clkin2, Clock dclk, Clock psclk)(MMCM);
   Reset reset <- invertCurrentReset;

   default_clock clk1(CLKIN1);
   default_reset rst(RST) = reset;

   parameter BANDWIDTH            = params.bandwidth;
   parameter CLKFBOUT_USE_FINE_PS = params.clkfbout_use_fine_ps;
   parameter CLKOUT0_USE_FINE_PS  = params.clkout0_use_fine_ps;
   parameter CLKOUT1_USE_FINE_PS  = params.clkout1_use_fine_ps;
   parameter CLKOUT2_USE_FINE_PS  = params.clkout2_use_fine_ps;
   parameter CLKOUT3_USE_FINE_PS  = params.clkout3_use_fine_ps;
   parameter CLKOUT4_CASCADE      = params.clkout4_cascade;
   parameter CLKOUT4_USE_FINE_PS  = params.clkout4_use_fine_ps;
   parameter CLKOUT5_USE_FINE_PS  = params.clkout5_use_fine_ps;
   parameter CLKOUT6_USE_FINE_PS  = params.clkout6_use_fine_ps;
   parameter COMPENSATION         = params.compensation;
   parameter STARTUP_WAIT         = params.startup_wait;
   parameter CLKFBOUT_MULT_F      = params.clkfbout_mult_f;
   parameter CLKFBOUT_PHASE       = params.clkfbout_phase;
   parameter CLKIN1_PERIOD        = params.clkin1_period;
   parameter CLKIN2_PERIOD        = params.clkin2_period;
   parameter DIVCLK_DIVIDE        = params.divclk_divide;
   parameter CLKOUT0_DIVIDE_F     = params.clkout0_divide_f;
   parameter CLKOUT0_DUTY_CYCLE   = params.clkout0_duty_cycle;
   parameter CLKOUT0_PHASE        = params.clkout0_phase;
   parameter CLKOUT1_DIVIDE       = params.clkout1_divide;
   parameter CLKOUT1_DUTY_CYCLE   = params.clkout1_duty_cycle;
   parameter CLKOUT1_PHASE        = params.clkout1_phase;
   parameter CLKOUT2_DIVIDE       = params.clkout2_divide;
   parameter CLKOUT2_DUTY_CYCLE   = params.clkout2_duty_cycle;
   parameter CLKOUT2_PHASE        = params.clkout2_phase;
   parameter CLKOUT3_DIVIDE       = params.clkout3_divide;
   parameter CLKOUT3_DUTY_CYCLE   = params.clkout3_duty_cycle;
   parameter CLKOUT3_PHASE        = params.clkout3_phase;
   parameter CLKOUT4_DIVIDE       = params.clkout4_divide;
   parameter CLKOUT4_DUTY_CYCLE   = params.clkout4_duty_cycle;
   parameter CLKOUT4_PHASE        = params.clkout4_phase;
   parameter CLKOUT5_DIVIDE       = params.clkout5_divide;
   parameter CLKOUT5_DUTY_CYCLE   = params.clkout5_duty_cycle;
   parameter CLKOUT5_PHASE        = params.clkout5_phase;
   parameter CLKOUT6_DIVIDE       = params.clkout6_divide;
   parameter CLKOUT6_DUTY_CYCLE   = params.clkout6_duty_cycle;
   parameter CLKOUT6_PHASE        = params.clkout6_phase;
   parameter REF_JITTER1          = params.ref_jitter1;
   parameter REF_JITTER2          = params.ref_jitter2;

   port PWRDWN       = Bit#(1)'(0);

   input_clock clk2(CLKIN2, (*unused*)CLKIN2_GATE)    = clkin2;
   input_clock dclk(DCLK, (*unused*)DCLK_GATE)        = dclk;
   input_clock psclk(PSCLK, (*unused*)PSCLK_GATE)     = psclk;

   output_clock clkfbout(CLKFBOUT);
   output_clock clkfbout_n(CLKFBOUTB);
   output_clock clkout0(CLKOUT0);
   output_clock clkout0_n(CLKOUT0B);
   output_clock clkout1(CLKOUT1);
   output_clock clkout1_n(CLKOUT1B);
   output_clock clkout2(CLKOUT2);
   output_clock clkout2_n(CLKOUT2B);
   output_clock clkout3(CLKOUT3);
   output_clock clkout3_n(CLKOUT3B);
   output_clock clkout4(CLKOUT4);
   output_clock clkout5(CLKOUT5);
   output_clock clkout6(CLKOUT6);

   method LOCKED   locked()     clocked_by(no_clock) reset_by(no_reset);
   method CLKFBSTOPPED clkfb_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method CLKINSTOPPED clkin_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method          clkin1sel(CLKINSEL) enable((*inhigh*)en0) clocked_by(clk1) reset_by(no_reset);
   method          clkfbin(CLKFBIN) enable((*inhigh*)en1) clocked_by(clkfbout) reset_by(no_reset);

   interface MMCM_DRP reconfig;
      method       request(DWE, DADDR, DI) enable(DEN) clocked_by(dclk) reset_by(no_reset);
      method DO    response() ready(DRDY) clocked_by(dclk) reset_by(no_reset);
   endinterface

   interface MMCM_PS phase_shift;
      method incdec (PSINCDEC)  enable(PSEN) clocked_by(psclk) reset_by(no_reset);
      method PSDONE done ()                  clocked_by(psclk) reset_by(no_reset);
   endinterface

   schedule clkfbin C clkfbin;
   schedule clkin1sel C clkin1sel;
   schedule (locked, clkfb_stopped, clkin_stopped) CF (locked, clkfb_stopped, clkin_stopped);
   schedule reconfig_response SB reconfig_request;
   schedule reconfig_request C reconfig_request;
   schedule reconfig_response CF reconfig_response;
   schedule phase_shift_incdec C phase_shift_incdec;
   schedule phase_shift_done SB phase_shift_incdec;
   schedule phase_shift_done CF phase_shift_done;
endmodule

// Version where the output clocks are annotated as "same_family" with CLKIN1
//
import "BVI" MMCM_ADV =
module vMkMMCMSF_ADV#(MMCMParams params, Clock clkin2, Clock dclk, Clock psclk)(MMCM);
   Reset reset <- invertCurrentReset;

   default_clock clk1(CLKIN1);
   default_reset rst(RST) = reset;

   parameter BANDWIDTH            = params.bandwidth;
   parameter CLKFBOUT_USE_FINE_PS = params.clkfbout_use_fine_ps;
   parameter CLKOUT0_USE_FINE_PS  = params.clkout0_use_fine_ps;
   parameter CLKOUT1_USE_FINE_PS  = params.clkout1_use_fine_ps;
   parameter CLKOUT2_USE_FINE_PS  = params.clkout2_use_fine_ps;
   parameter CLKOUT3_USE_FINE_PS  = params.clkout3_use_fine_ps;
   parameter CLKOUT4_CASCADE      = params.clkout4_cascade;
   parameter CLKOUT4_USE_FINE_PS  = params.clkout4_use_fine_ps;
   parameter CLKOUT5_USE_FINE_PS  = params.clkout5_use_fine_ps;
   parameter CLKOUT6_USE_FINE_PS  = params.clkout6_use_fine_ps;
   parameter COMPENSATION         = params.compensation;
   parameter STARTUP_WAIT         = params.startup_wait;
   parameter CLKFBOUT_MULT_F      = params.clkfbout_mult_f;
   parameter CLKFBOUT_PHASE       = params.clkfbout_phase;
   parameter CLKIN1_PERIOD        = params.clkin1_period;
   parameter CLKIN2_PERIOD        = params.clkin2_period;
   parameter DIVCLK_DIVIDE        = params.divclk_divide;
   parameter CLKOUT0_DIVIDE_F     = params.clkout0_divide_f;
   parameter CLKOUT0_DUTY_CYCLE   = params.clkout0_duty_cycle;
   parameter CLKOUT0_PHASE        = params.clkout0_phase;
   parameter CLKOUT1_DIVIDE       = params.clkout1_divide;
   parameter CLKOUT1_DUTY_CYCLE   = params.clkout1_duty_cycle;
   parameter CLKOUT1_PHASE        = params.clkout1_phase;
   parameter CLKOUT2_DIVIDE       = params.clkout2_divide;
   parameter CLKOUT2_DUTY_CYCLE   = params.clkout2_duty_cycle;
   parameter CLKOUT2_PHASE        = params.clkout2_phase;
   parameter CLKOUT3_DIVIDE       = params.clkout3_divide;
   parameter CLKOUT3_DUTY_CYCLE   = params.clkout3_duty_cycle;
   parameter CLKOUT3_PHASE        = params.clkout3_phase;
   parameter CLKOUT4_DIVIDE       = params.clkout4_divide;
   parameter CLKOUT4_DUTY_CYCLE   = params.clkout4_duty_cycle;
   parameter CLKOUT4_PHASE        = params.clkout4_phase;
   parameter CLKOUT5_DIVIDE       = params.clkout5_divide;
   parameter CLKOUT5_DUTY_CYCLE   = params.clkout5_duty_cycle;
   parameter CLKOUT5_PHASE        = params.clkout5_phase;
   parameter CLKOUT6_DIVIDE       = params.clkout6_divide;
   parameter CLKOUT6_DUTY_CYCLE   = params.clkout6_duty_cycle;
   parameter CLKOUT6_PHASE        = params.clkout6_phase;
   parameter REF_JITTER1          = params.ref_jitter1;
   parameter REF_JITTER2          = params.ref_jitter2;

   port PWRDWN       = Bit#(1)'(0);

   input_clock clk2(CLKIN2, (*unused*)CLKIN2_GATE)    = clkin2;
   input_clock dclk(DCLK, (*unused*)DCLK_GATE)        = dclk;
   input_clock psclk(PSCLK, (*unused*)PSCLK_GATE)     = psclk;

   output_clock clkfbout(CLKFBOUT);
   output_clock clkfbout_n(CLKFBOUTB);
   output_clock clkout0(CLKOUT0);
   output_clock clkout0_n(CLKOUT0B);
   output_clock clkout1(CLKOUT1);
   output_clock clkout1_n(CLKOUT1B);
   output_clock clkout2(CLKOUT2);
   output_clock clkout2_n(CLKOUT2B);
   output_clock clkout3(CLKOUT3);
   output_clock clkout3_n(CLKOUT3B);
   output_clock clkout4(CLKOUT4);
   output_clock clkout5(CLKOUT5);
   output_clock clkout6(CLKOUT6);

   same_family(clk1, clkfbout);
   same_family(clk1, clkfbout_n);
   same_family(clk1, clkout0);
   same_family(clk1, clkout0_n);
   same_family(clk1, clkout1);
   same_family(clk1, clkout1_n);
   same_family(clk1, clkout2);
   same_family(clk1, clkout2_n);
   same_family(clk1, clkout3);
   same_family(clk1, clkout3_n);
   same_family(clk1, clkout4);
   same_family(clk1, clkout5);
   same_family(clk1, clkout6);

   method LOCKED   locked()     clocked_by(no_clock) reset_by(no_reset);
   method CLKFBSTOPPED clkfb_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method CLKINSTOPPED clkin_stopped()  clocked_by(no_clock) reset_by(no_reset);
   method          clkin1sel(CLKINSEL) enable((*inhigh*)en0) clocked_by(clk1) reset_by(no_reset);
   method          clkfbin(CLKFBIN) enable((*inhigh*)en1) clocked_by(clkfbout) reset_by(no_reset);

   interface MMCM_DRP reconfig;
      method       request(DWE, DADDR, DI) enable(DEN) clocked_by(dclk) reset_by(no_reset);
      method DO    response() ready(DRDY) clocked_by(dclk) reset_by(no_reset);
   endinterface

   interface MMCM_PS phase_shift;
      method incdec (PSINCDEC)  enable(PSEN) clocked_by(psclk) reset_by(no_reset);
      method PSDONE done ()                  clocked_by(psclk) reset_by(no_reset);
   endinterface

   schedule clkfbin C clkfbin;
   schedule clkin1sel C clkin1sel;
   schedule clkin1sel CF clkfbin;
   schedule (locked, clkfb_stopped, clkin_stopped) CF (locked, clkfb_stopped, clkin_stopped);
   schedule reconfig_response SB reconfig_request;
   schedule reconfig_request C reconfig_request;
   schedule reconfig_response CF reconfig_response;
   schedule phase_shift_incdec C phase_shift_incdec;
   schedule phase_shift_done SB phase_shift_incdec;
   schedule phase_shift_done CF phase_shift_done;
endmodule

module mkMMCM#(MMCMParams params)(MMCME2);
   MMCM _mmcm = ?;
   if (params.use_same_family)
      _mmcm <- vMkMMCMSF_ADV(params, noClock, noClock, noClock);
   else
      _mmcm <- vMkMMCM_ADV(params, noClock, noClock, noClock);

   ReadOnly#(Bool) clkfbbuf <- mkClockBitBUFG(clocked_by _mmcm.clkfbout);

   (* fire_when_enabled, no_implicit_conditions *)
   rule connect_feedback;
      _mmcm.clkfbin(pack(clkfbbuf));
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule connect_clkin1sel;
      _mmcm.clkin1sel(True);
   endrule

   interface Clock     clkout0   = _mmcm.clkout0;
   interface Clock     clkout0_n = _mmcm.clkout0_n;
   interface Clock     clkout1   = _mmcm.clkout1;
   interface Clock     clkout1_n = _mmcm.clkout1_n;
   interface Clock     clkout2   = _mmcm.clkout2;
   interface Clock     clkout2_n = _mmcm.clkout2_n;
   interface Clock     clkout3   = _mmcm.clkout3;
   interface Clock     clkout3_n = _mmcm.clkout3_n;
   interface Clock     clkout4   = _mmcm.clkout4;
   interface Clock     clkout5   = _mmcm.clkout5;
   interface Clock     clkout6   = _mmcm.clkout6;
   method    Bool      locked    = _mmcm.locked;
endmodule


endpackage: XilinxCells
