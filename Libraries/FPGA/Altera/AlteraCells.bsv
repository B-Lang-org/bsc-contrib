////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : AlteraCells.bsv
//  Description   : Altera specific primitive/macro wrappers
////////////////////////////////////////////////////////////////////////////////
package AlteraCells;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import Clocks            ::*;
import Vector            ::*;
import DefaultValue      ::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////
export AlteraClockGenParams(..);
export AlteraClockGen(..);
export DiffClock(..);
export ODDRParams(..);
export ODDR(..);
export IDDRParams(..);
export IDDR(..);

export mkAlteraClockGen;
export mkAlteraClockDiffIn;
export mkAlteraClockDiffOut;
export mkAlteraODDR;
export mkAlteraClockDDR;
export mkAlteraIDDR;

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
interface DiffClock;
   interface Clock p;
   interface Clock n;
endinterface

////////////////////////////////////////////////////////////////////////////////
/// AltPll
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String          device_family;
   Integer         clkin_period_ps;
   Integer         clk0_div;
   Integer         clk0_duty_cycle;
   String          clk0_phase_shift;
   Integer         clk0_mul;
   Integer         clk1_div;
   Integer         clk1_duty_cycle;
   String          clk1_phase_shift;
   Integer         clk1_mul;
   Integer         clk2_div;
   Integer         clk2_duty_cycle;
   String          clk2_phase_shift;
   Integer         clk2_mul;
   Integer         clk3_div;
   Integer         clk3_duty_cycle;
   String          clk3_phase_shift;
   Integer         clk3_mul;
   Integer         clk4_div;
   Integer         clk4_duty_cycle;
   String          clk4_phase_shift;
   Integer         clk4_mul;
   Integer         clk5_div;
   Integer         clk5_duty_cycle;
   String          clk5_phase_shift;
   Integer         clk5_mul;
   Integer         clk6_div;
   Integer         clk6_duty_cycle;
   String          clk6_phase_shift;
   Integer         clk6_mul;
   Integer         clk7_div;
   Integer         clk7_duty_cycle;
   String          clk7_phase_shift;
   Integer         clk7_mul;
   Integer         clk8_div;
   Integer         clk8_duty_cycle;
   String          clk8_phase_shift;
   Integer         clk8_mul;
   Integer         clk9_div;
   Integer         clk9_duty_cycle;
   String          clk9_phase_shift;
   Integer         clk9_mul;
} AlteraClockGenParams deriving (Bits, Eq);

instance DefaultValue#(AlteraClockGenParams);
   defaultValue = AlteraClockGenParams {
      device_family:     "Stratix III",
      clkin_period_ps:   10000,
      clk0_div:          1,
      clk0_duty_cycle:   50,
      clk0_phase_shift:  "0",
      clk0_mul:          1,
      clk1_div:          1,
      clk1_duty_cycle:   50,
      clk1_phase_shift:  "0",
      clk1_mul:          1,
      clk2_div:          1,
      clk2_duty_cycle:   50,
      clk2_phase_shift:  "0",
      clk2_mul:          1,
      clk3_div:          1,
      clk3_duty_cycle:   50,
      clk3_phase_shift:  "0",
      clk3_mul:          1,
      clk4_div:          1,
      clk4_duty_cycle:   50,
      clk4_phase_shift:  "0",
      clk4_mul:          1,
      clk5_div:          1,
      clk5_duty_cycle:   50,
      clk5_phase_shift:  "0",
      clk5_mul:          1,
      clk6_div:          1,
      clk6_duty_cycle:   50,
      clk6_phase_shift:  "0",
      clk6_mul:          1,
      clk7_div:          1,
      clk7_duty_cycle:   50,
      clk7_phase_shift:  "0",
      clk7_mul:          1,
      clk8_div:          1,
      clk8_duty_cycle:   50,
      clk8_phase_shift:  "0",
      clk8_mul:          1,
      clk9_div:          1,
      clk9_duty_cycle:   50,
      clk9_phase_shift:  "0",
      clk9_mul:          1
      };
endinstance

interface AlteraClockGen;
   interface Clock          clkout0;
   interface Clock          clkout1;
   interface Clock          clkout2;
   interface Clock          clkout3;
   interface Clock          clkout4;
   interface Clock          clkout5;
   interface Clock          clkout6;
   interface Clock          clkout7;
   interface Clock          clkout8;
   interface Clock          clkout9;
   (* always_ready *)
   method    Bool           locked;
endinterface

import "BVI" altpll_wrapper =
module vMkAltPLL#(AlteraClockGenParams params)(AlteraClockGen);
   default_clock inclk(CLKIN);
   default_reset rst(RESET_N);

   parameter bandwidth_type          = "AUTO";
   parameter clk0_divide_by          = params.clk0_div;
   parameter clk0_duty_cycle         = params.clk0_duty_cycle;
   parameter clk0_multiply_by        = params.clk0_mul;
   parameter clk0_phase_shift        = params.clk0_phase_shift;
   parameter clk1_divide_by          = params.clk1_div;
   parameter clk1_duty_cycle         = params.clk1_duty_cycle;
   parameter clk1_multiply_by        = params.clk1_mul;
   parameter clk1_phase_shift        = params.clk1_phase_shift;
   parameter clk2_divide_by          = params.clk2_div;
   parameter clk2_duty_cycle         = params.clk2_duty_cycle;
   parameter clk2_multiply_by        = params.clk2_mul;
   parameter clk2_phase_shift        = params.clk2_phase_shift;
   parameter clk3_divide_by          = params.clk3_div;
   parameter clk3_duty_cycle         = params.clk3_duty_cycle;
   parameter clk3_multiply_by        = params.clk3_mul;
   parameter clk3_phase_shift        = params.clk3_phase_shift;
   parameter clk4_divide_by          = params.clk4_div;
   parameter clk4_duty_cycle         = params.clk4_duty_cycle;
   parameter clk4_multiply_by        = params.clk4_mul;
   parameter clk4_phase_shift        = params.clk4_phase_shift;
   parameter clk5_divide_by          = params.clk5_div;
   parameter clk5_duty_cycle         = params.clk5_duty_cycle;
   parameter clk5_multiply_by        = params.clk5_mul;
   parameter clk5_phase_shift        = params.clk5_phase_shift;
   parameter clk6_divide_by          = params.clk6_div;
   parameter clk6_duty_cycle         = params.clk6_duty_cycle;
   parameter clk6_multiply_by        = params.clk6_mul;
   parameter clk6_phase_shift        = params.clk6_phase_shift;
   parameter clk7_divide_by          = params.clk7_div;
   parameter clk7_duty_cycle         = params.clk7_duty_cycle;
   parameter clk7_multiply_by        = params.clk7_mul;
   parameter clk7_phase_shift        = params.clk7_phase_shift;
   parameter clk8_divide_by          = params.clk8_div;
   parameter clk8_duty_cycle         = params.clk8_duty_cycle;
   parameter clk8_multiply_by        = params.clk8_mul;
   parameter clk8_phase_shift        = params.clk8_phase_shift;
   parameter clk9_divide_by          = params.clk9_div;
   parameter clk9_duty_cycle         = params.clk9_duty_cycle;
   parameter clk9_multiply_by        = params.clk9_mul;
   parameter clk9_phase_shift        = params.clk9_phase_shift;
   parameter compensate_clock        = "CLK0";
   parameter inclk0_input_frequency  = params.clkin_period_ps;
   parameter intended_device_family  = params.device_family;
   parameter lpm_type                = "altpll";
   parameter operation_mode          = "NORMAL";
   parameter pll_type                = "AUTO";
   parameter port_activeclock        = "PORT_UNUSED";
   parameter port_areset             = "PORT_USED";
   parameter port_clkbad0            = "PORT_UNUSED";
   parameter port_clkbad1            = "PORT_UNUSED";
   parameter port_clkloss            = "PORT_UNUSED";
   parameter port_clkswitch          = "PORT_UNUSED";
   parameter port_configupdate       = "PORT_UNUSED";
   parameter port_fbin               = "PORT_UNUSED";
   parameter port_fbout              = "PORT_UNUSED";
   parameter port_inclk0             = "PORT_USED";
   parameter port_inclk1             = "PORT_UNUSED";
   parameter port_locked             = "PORT_USED";
   parameter port_pfdena             = "PORT_UNUSED";
   parameter port_phasecounterselect = "PORT_UNUSED";
   parameter port_phasedone          = "PORT_UNUSED";
   parameter port_phasestep          = "PORT_UNUSED";
   parameter port_phaseupdown        = "PORT_UNUSED";
   parameter port_pllena             = "PORT_UNUSED";
   parameter port_scanaclr           = "PORT_UNUSED";
   parameter port_scanclk            = "PORT_UNUSED";
   parameter port_scanclkena         = "PORT_UNUSED";
   parameter port_scandata           = "PORT_UNUSED";
   parameter port_scandataout        = "PORT_UNUSED";
   parameter port_scandone           = "PORT_UNUSED";
   parameter port_scanread           = "PORT_UNUSED";
   parameter port_scanwrite          = "PORT_UNUSED";
   parameter port_clk0               = "PORT_USED";
   parameter port_clk1               = "PORT_USED";
   parameter port_clk2               = "PORT_USED";
   parameter port_clk3               = "PORT_USED";
   parameter port_clk4               = "PORT_USED";
   parameter port_clk5               = "PORT_USED";
   parameter port_clk6               = "PORT_USED";
   parameter port_clk7               = "PORT_USED";
   parameter port_clk8               = "PORT_USED";
   parameter port_clk9               = "PORT_USED";
   parameter port_clkena0            = "PORT_UNUSED";
   parameter port_clkena1            = "PORT_UNUSED";
   parameter port_clkena2            = "PORT_UNUSED";
   parameter port_clkena3            = "PORT_UNUSED";
   parameter port_clkena4            = "PORT_UNUSED";
   parameter port_clkena5            = "PORT_UNUSED";
   parameter self_reset_on_loss_lock = "OFF";
   parameter using_fbmimicbidir_port = "OFF";
   parameter width_clock             = 10;

   output_clock clkout0(CLK0);
   output_clock clkout1(CLK1);
   output_clock clkout2(CLK2);
   output_clock clkout3(CLK3);
   output_clock clkout4(CLK4);
   output_clock clkout5(CLK5);
   output_clock clkout6(CLK6);
   output_clock clkout7(CLK7);
   output_clock clkout8(CLK8);
   output_clock clkout9(CLK9);

   method LOCKED locked() clocked_by(no_clock) reset_by(no_reset);

   schedule (locked) CF (locked);
endmodule

module mkAlteraClockGen#(AlteraClockGenParams params)(AlteraClockGen);
   (* hide *)
   let _m <- vMkAltPLL(params);
   return _m;
endmodule

////////////////////////////////////////////////////////////////////////////////
/// alt_inbuf_diff
////////////////////////////////////////////////////////////////////////////////
import "BVI" alt_inbuf_diff =
module vMkAltInbufDiff#(Clock clk_p, Clock clk_n)(ClockGenIfc);
   default_clock no_clock;
   default_reset no_reset;

   parameter io_standard = "LVDS";

   input_clock clk_p(i)    = clk_p;
   input_clock clk_n(ibar) = clk_n;

   output_clock gen_clk(o);

   path(i, o);
   path(ib, o);

   same_family(clk_p, gen_clk);
endmodule: vMkAltInbufDiff

module mkAlteraClockDiffIn#(Clock clk_p, Clock clk_n)(Clock);
   let _m <- vMkAltInbufDiff(clk_p, clk_n);
   return _m.gen_clk;
endmodule

////////////////////////////////////////////////////////////////////////////////
/// alt_outbuf_diff
////////////////////////////////////////////////////////////////////////////////
import "BVI" alt_outbuf_diff =
module vMkAltOutbufDiff(DiffClock);
   default_clock clk(i);
   default_reset no_reset;

   parameter io_standard = "LVDS";

   output_clock p(o);
   output_clock n(obar);

   path(i, o);
   path(i, obar);

   same_family(clk, p);
endmodule: vMkAltOutbufDiff

module mkAlteraClockDiffOut(DiffClock);
   let _m <- vMkAltOutbufDiff;
   return _m;
endmodule

////////////////////////////////////////////////////////////////////////////////
/// altddio_out
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String      extend_oe_disable;
   String      intended_device_family;
   String      invert_output;
   String      lpm_hint;
   String      lpm_type;
   String      oe_reg;
   String      power_up_high;
} ODDRParams deriving (Bits, Eq);

instance DefaultValue#(ODDRParams);
   defaultValue = ODDRParams {
      extend_oe_disable:      "OFF",
      intended_device_family: "Stratix III",
      invert_output:          "OFF",
      lpm_hint:               "UNUSED",
      lpm_type:               "altddio_out",
      oe_reg:                 "UNREGISTERED",
      power_up_high:          "OFF"
      };
endinstance

(* always_ready, always_enabled *)
interface ODDR#(type a);
   method    a           q();
   method    Action      data_hi(a i);
   method    Action      data_lo(a i);
endinterface: ODDR

import "BVI" altddio_out =
module vMkAltDdioOut#(ODDRParams params)(ODDR#(a))
   provisos(Bits#(a, sa));

   default_clock clk(outclock);
   default_reset no_reset;

   parameter extend_oe_disable      = params.extend_oe_disable;
   parameter intended_device_family = params.intended_device_family;
   parameter invert_output          = params.invert_output;
   parameter lpm_hint               = params.lpm_hint;
   parameter lpm_type               = params.lpm_type;
   parameter oe_reg                 = params.oe_reg;
   parameter power_up_high          = params.power_up_high;
   parameter width                  = valueOf(sa);

   port      aclr       = Bit#(1)'(0);
   port      aset       = Bit#(1)'(0);
   port      oe         = Bit#(1)'(1);
   port      outclocken = Bit#(1)'(1);
   port      sclr       = Bit#(1)'(0);
   port      sset       = Bit#(1)'(0);

   method    dataout          q;
   method                     data_hi(datain_h) enable((*inhigh*)en0);
   method                     data_lo(datain_l) enable((*inhigh*)en1);

   schedule (q)       SB (data_hi, data_lo);
   schedule (data_hi) CF (data_lo);
   schedule (data_hi) C  (data_hi);
   schedule (data_lo) C  (data_lo);
   schedule (q)       CF (q);
endmodule: vMkAltDdioOut

module mkAlteraODDR#(ODDRParams params)(ODDR#(a))
   provisos(Bits#(a, sa));
   let _m <- vMkAltDdioOut(params);
   return _m;
endmodule

import "BVI" altddio_out =
module vMkAltDdioClockOut#(ODDRParams params, Bit#(1) data_hi, Bit#(1) data_lo)(ClockGenIfc);
   default_clock clk(outclock);
   default_reset no_reset;

   parameter extend_oe_disable      = params.extend_oe_disable;
   parameter intended_device_family = params.intended_device_family;
   parameter invert_output          = params.invert_output;
   parameter lpm_hint               = params.lpm_hint;
   parameter lpm_type               = params.lpm_type;
   parameter oe_reg                 = params.oe_reg;
   parameter power_up_high          = params.power_up_high;
   parameter width                  = 1;

   port      aclr       = Bit#(1)'(0);
   port      aset       = Bit#(1)'(0);
   port      oe         = Bit#(1)'(1);
   port      outclocken = Bit#(1)'(1);
   port      sclr       = Bit#(1)'(0);
   port      sset       = Bit#(1)'(0);
   port      datain_h   = data_hi;
   port      datain_l   = data_lo;

   output_clock gen_clk(dataout);
endmodule: vMkAltDdioClockOut

module mkAlteraClockDDR#(ODDRParams params, Bit#(1) data_hi, Bit#(1) data_lo)(Clock);
   let _m <- vMkAltDdioClockOut(params, data_hi, data_lo);
   return _m.gen_clk;
endmodule

////////////////////////////////////////////////////////////////////////////////
/// altddio_in
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String      intended_device_family;
   String      invert_input_clocks;
   String      lpm_hint;
   String      lpm_type;
   String      power_up_high;
} IDDRParams deriving (Bits, Eq);

instance DefaultValue#(IDDRParams);
   defaultValue = IDDRParams {
      intended_device_family: "Stratix III",
      invert_input_clocks:    "OFF",
      lpm_hint:               "UNUSED",
      lpm_type:               "altddio_out",
      power_up_high:          "OFF"
      };
endinstance

(* always_ready, always_enabled *)
interface IDDR#(type a);
   method    a           q_hi();
   method    a           q_lo();
   method    Action      data_in(a i);
endinterface: IDDR

import "BVI" altddio_in =
module vMkAltDdioIn#(IDDRParams params)(IDDR#(a))
   provisos(Bits#(a, sa));

   default_clock clk(inclock);
   default_reset no_reset;

   parameter intended_device_family = params.intended_device_family;
   parameter invert_input_clocks    = params.invert_input_clocks;
   parameter lpm_hint               = params.lpm_hint;
   parameter lpm_type               = params.lpm_type;
   parameter power_up_high          = params.power_up_high;
   parameter width                  = valueOf(sa);

   port      aclr       = Bit#(1)'(0);
   port      aset       = Bit#(1)'(0);
   port      inclocken  = Bit#(1)'(1);
   port      sclr       = Bit#(1)'(0);
   port      sset       = Bit#(1)'(0);

   method    dataout_h        q_hi;
   method    dataout_l        q_lo;
   method                     data_in(datain) enable((*inhigh*)en0);

   schedule (q_hi, q_lo)   SB  (data_in);
   schedule (data_in)      C   (data_in);
   schedule (q_hi, q_lo)   CF  (q_hi, q_lo);
endmodule: vMkAltDdioIn

module mkAlteraIDDR#(IDDRParams params)(IDDR#(a))
   provisos(Bits#(a, sa));
   let _m <- vMkAltDdioIn(params);
   return _m;
endmodule

////////////////////////////////////////////////////////////////////////////////
/// LVDS SERDES Transmitter
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String           registered_input;            // is tx_in[] and tx_outclock ports registered
   String           multi_clock;                 // sync_inclock is used
   Integer          inclock_period_ps;           // input clock period in ps
   String           center_align_msb;            // aligns the MSB to the falling edge of the clock instead of rising edge
   String           intended_device_family;      // device family to be used
   Integer          output_data_rate;            // data rate out of the pll (not required for III/IV)
   String           inclock_data_alignment;      // the alignment of the input data w.r.t. the tx_inclock port.
   String           outclock_alignment;          // the alignment of the output data w.r.t. the tx_outclock port.
   String           common_rx_tx_pll;            // specifies whether the compiler uses the same PLL for the LVDS tx/rx
   String           outclock_resource;
   String           use_external_pll;
   String           implement_in_les;
   Integer          preemphasis_setting;
   Integer          vod_setting;
   Integer          differential_drive;
   Integer          outclock_multiply_by;
   Integer          coreclock_divide_by;
   Integer          outclock_duty_cycle;
   Integer          inclock_phase_shift;
   Integer          outclock_phase_shift;
   String           use_no_phase_shift;
   String           pll_self_reset_on_loss_lock;
   String           refclk_frequency;
   String           data_rate;
   String           lpm_type;
   String           lpm_hint;
   String           clk_src_is_pll;
} LVDSTX deriving (Bits, Eq);

instance DefaultValue#(LVDSTX);
   defaultValue = LVDSTX {
      registered_input:            "OFF",
      multi_clock:                 "OFF",
      inclock_period_ps:           20000,
      center_align_msb:            "UNUSED",
      intended_device_family:      "Stratix III",
      output_data_rate:            0,
      inclock_data_alignment:      "EDGE_ALIGNED",
      outclock_alignment:          "EDGE_ALIGNED",
      common_rx_tx_pll:            "ON",
      outclock_resource:           "AUTO",
      use_external_pll:            "OFF",
      implement_in_les:            "OFF",
      preemphasis_setting:         0,
      vod_setting:                 0,
      differential_drive:          0,
      outclock_multiply_by:        1,
      coreclock_divide_by:         1,
      outclock_duty_cycle:         50,
      inclock_phase_shift:         0,
      outclock_phase_shift:        0,
      use_no_phase_shift:          "ON",
      pll_self_reset_on_loss_lock: "OFF",
      refclk_frequency:            "UNUSED",
      data_rate:                   "UNUSED",
      lpm_type:                    "altlvds_tx",
      lpm_hint:                    "UNUSED",
      clk_src_is_pll:              "off"
      };
endinstance

(* always_ready, always_enabled *)
interface SERDES_TX#(type in, type out);
   interface Clock    coreclk;
   interface Clock    outclk;
   method    Action   pins_in(in x);
   method    out      pins_out();
   method    Bool     locked();
endinterface

import "BVI" altlvds_tx =
module vMkAltLvdsTx#(LVDSTX params)(SERDES_TX#(a, b))
   provisos(  Bits#(a, sa)
	    , Bits#(b, sb)
	    , Mul#(sb, x, sa)
	    , Div#(sa, x, sb)
	    );

   let reset <- invertCurrentReset;

   default_clock clk(tx_inclock);
   default_reset rst(pll_areset) = reset;

   parameter number_of_channels     	 = valueOf(sb);
   parameter deserialization_factor 	 = valueOf(x);
   parameter registered_input       	 = params.registered_input;
   parameter multi_clock            	 = params.multi_clock;
   parameter inclock_period      	 = params.inclock_period_ps;
   parameter outclock_divide_by     	 = valueOf(x);
   parameter inclock_boost          	 = valueOf(x);
   parameter center_align_msb       	 = params.center_align_msb;
   parameter intended_device_family 	 = params.intended_device_family;
   parameter output_data_rate       	 = params.output_data_rate;
   parameter inclock_data_alignment 	 = params.inclock_data_alignment;
   parameter outclock_alignment     	 = params.outclock_alignment;
   parameter common_rx_tx_pll       	 = params.common_rx_tx_pll;
   parameter outclock_resource      	 = params.outclock_resource;
   parameter use_external_pll       	 = params.use_external_pll;
   parameter implement_in_les       	 = params.implement_in_les;
   parameter preemphasis_setting    	 = params.preemphasis_setting;
   parameter vod_setting            	 = params.vod_setting;
   parameter differential_drive     	 = params.differential_drive;
   parameter outclock_multiply_by   	 = params.outclock_multiply_by;
   parameter coreclock_divide_by    	 = params.coreclock_divide_by;
   parameter outclock_duty_cycle    	 = params.outclock_duty_cycle;
   parameter inclock_phase_shift    	 = params.inclock_phase_shift;
   parameter outclock_phase_shift   	 = params.outclock_phase_shift;
   parameter use_no_phase_shift     	 = params.use_no_phase_shift;
   parameter pll_self_reset_on_loss_lock = params.pll_self_reset_on_loss_lock;
   parameter refclk_frequency            = params.refclk_frequency;
   parameter data_rate 			 = params.data_rate;
   parameter lpm_type  			 = params.lpm_type;
   parameter lpm_hint  			 = params.lpm_hint;
   parameter clk_src_is_pll              = params.clk_src_is_pll;

   port      sync_inclock     = Bit#(1)'(0);
   port      tx_data_reset    = Bit#(1)'(0);
   port      tx_enable        = Bit#(1)'(1);
   port      tx_pll_enable    = Bit#(1)'(1);
   port      tx_syncclock     = Bit#(1)'(0);

   output_clock coreclk(tx_coreclock);
   output_clock outclk(tx_outclock);

   method             pins_in(tx_in) enable((*inhigh*)en0) reset_by(no_reset);
   method tx_locked   locked() reset_by(no_reset);
   method tx_out      pins_out() reset_by(no_reset);

   schedule (pins_in, locked, pins_out) CF (pins_in, locked, pins_out);
endmodule: vMkAltLvdsTx

module mkAlteraLVDS_TX#(LVDSTX params)(SERDES_TX#(in,out))
   provisos(  Bits#(in, sa)
	    , Bits#(out, sb)
	    , Mul#(sb, factor, sa)
	    , Div#(sa, factor, sb)
	    );

   if (valueOf(factor) > 10)
      error("The deserialization factor must be between 1 and 10, inclusive.");

   if (valueOf(sb) > 45 &&
       valueOf(sb) != 48 &&
       valueOf(sb) != 52 &&
       valueOf(sb) != 56 &&
       valueOf(sb) != 60 &&
       valueOf(sb) != 64)
      error("Invalid number of output channels.  Legal values are [1,45],48,52,56,60,64.");


   let _m <- vMkAltLvdsTx(params);
   return _m;
endmodule

////////////////////////////////////////////////////////////////////////////////
/// LVDS SERDES Receiver
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   String           registered_output;
   Integer          inclock_period_ps;
   String           cds_mode;
   String           intended_device_family;
   Integer          input_data_rate;
   String           inclock_data_alignment;
   String           registered_data_align_input;
   String           common_rx_tx_pll;
   String           enable_dpa_mode;
   String           enable_dpa_calibration;
   String           enable_dpa_pll_calibration;
   String           enable_dpa_fifo;
   String           use_dpll_rawperror;
   String           use_coreclock_input;
   Integer          dpll_lock_count;
   Integer          dpll_lock_window;
   String           outclock_resource;
   String           lose_lock_on_one_change;
   String           reset_fifo_at_first_lock;
   String           use_external_pll;
   String           implement_in_les;
   String           buffer_implementation;
   String           port_rx_data_align;
   String           port_rx_channel_data_align;
   String           pll_operation_mode;
   String           x_on_bitslip;
   String           use_no_phase_shift;
   String           rx_align_data_reg;
   Integer          inclock_phase_shift;
   String           enable_soft_cdr_mode;
   Integer          sim_dpa_output_clock_phase_shift;
   String           sim_dpa_is_negative_ppm_drift;
   Integer          sim_dpa_net_ppm_variation;
   String           enable_dpa_align_to_rising_edge_only;
   String           enable_dpa_initial_phase_selection;
   Integer          dpa_initial_phase_value;
   String           pll_self_reset_on_loss_lock;
   String           refclk_frequency;
   String           enable_clock_pin_mode;
   String           data_rate;
   String           lpm_hint;
   String           lpm_type;
} LVDSRX deriving (Bits, Eq);

instance DefaultValue#(LVDSRX);
   defaultValue = LVDSRX {
      registered_output:                    "ON",
      inclock_period_ps:                    10000,
      cds_mode:                             "UNUSED",
      intended_device_family:               "Stratix III",
      input_data_rate:                      0,
      inclock_data_alignment:               "EDGE_ALIGNED",
      registered_data_align_input:          "ON",
      common_rx_tx_pll:                     "ON",
      enable_dpa_mode:                      "OFF",
      enable_dpa_calibration:               "ON",
      enable_dpa_pll_calibration:           "OFF",
      enable_dpa_fifo:                      "UNUSED",
      use_dpll_rawperror:                   "OFF",
      use_coreclock_input:                  "OFF",
      dpll_lock_count:                      0,
      dpll_lock_window:                     0,
      outclock_resource:                    "AUTO",
      lose_lock_on_one_change:              "UNUSED",
      reset_fifo_at_first_lock:             "UNUSED",
      use_external_pll:                     "OFF",
      implement_in_les:                     "OFF",
      buffer_implementation:                "RAM",
      port_rx_data_align:                   "PORT_UNUSED",
      port_rx_channel_data_align:           "PORT_UNUSED",
      pll_operation_mode:                   "UNUSED",
      x_on_bitslip:                         "ON",
      use_no_phase_shift:                   "ON",
      rx_align_data_reg:                    "RISING_EDGE",
      inclock_phase_shift:                  0,
      enable_soft_cdr_mode:                 "OFF",
      sim_dpa_output_clock_phase_shift:     0,
      sim_dpa_is_negative_ppm_drift:        "OFF",
      sim_dpa_net_ppm_variation:            0,
      enable_dpa_align_to_rising_edge_only: "OFF",
      enable_dpa_initial_phase_selection:   "OFF",
      dpa_initial_phase_value:              0,
      pll_self_reset_on_loss_lock:          "UNUSED",
      refclk_frequency:                     "UNUSED",
      enable_clock_pin_mode:                "UNUSED",
      data_rate:                            "UNUSED",
      lpm_hint:                             "UNUSED",
      lpm_type:                             "altlvds_rx"
      };
endinstance

(* always_ready, always_enabled *)
interface SERDES_RX#(type in, type out);
   interface Clock    outclk;
   method    Action   pins_in(in x);
   method    out      pins_out();
   method    Bool     locked();
endinterface

import "BVI" altlvds_rx =
module vMkAltLvdsRx#(LVDSRX params)(SERDES_RX#(a, b))
   provisos(  Bits#(a, sa)
	    , Bits#(b, sb)
	    , Mul#(sa, x, sb)
	    , Div#(sb, x, sa)
	    );

   let reset <- invertCurrentReset;

   default_clock clk(rx_inclock);
   default_reset rst(pll_areset) = reset;

   parameter number_of_channels                   = valueOf(sa);
   parameter deserialization_factor               = valueOf(x);
   parameter registered_output 			  = params.registered_output;
   parameter inclock_period  			  = params.inclock_period_ps;
   parameter inclock_boost                        = valueOf(x);
   parameter cds_mode                             = params.cds_mode;
   parameter intended_device_family               = params.intended_device_family;
   parameter input_data_rate             	  = params.input_data_rate;
   parameter inclock_data_alignment      	  = params.inclock_data_alignment;
   parameter registered_data_align_input 	  = params.registered_data_align_input;
   parameter common_rx_tx_pll            	  = params.common_rx_tx_pll;
   parameter enable_dpa_mode             	  = params.enable_dpa_mode;
   parameter enable_dpa_calibration      	  = params.enable_dpa_calibration;
   parameter enable_dpa_pll_calibration  	  = params.enable_dpa_pll_calibration;
   parameter enable_dpa_fifo             	  = params.enable_dpa_fifo;
   parameter use_dpll_rawperror          	  = params.use_dpll_rawperror;
   parameter use_coreclock_input         	  = params.use_coreclock_input;
   parameter dpll_lock_count             	  = params.dpll_lock_count;
   parameter dpll_lock_window            	  = params.dpll_lock_window;
   parameter outclock_resource           	  = params.outclock_resource;
   parameter data_align_rollover                  = valueOf(x);
   parameter lose_lock_on_one_change     	  = params.lose_lock_on_one_change;
   parameter reset_fifo_at_first_lock    	  = params.reset_fifo_at_first_lock;
   parameter use_external_pll 		 	  = params.use_external_pll;
   parameter implement_in_les 		 	  = params.implement_in_les;
   parameter buffer_implementation       	  = params.buffer_implementation;
   parameter port_rx_data_align          	  = params.port_rx_data_align;
   parameter port_rx_channel_data_align  	  = params.port_rx_channel_data_align;
   parameter pll_operation_mode          	  = params.pll_operation_mode;
   parameter x_on_bitslip                	  = params.x_on_bitslip;
   parameter use_no_phase_shift   	 	  = params.use_no_phase_shift;
   parameter rx_align_data_reg    	 	  = params.rx_align_data_reg;
   parameter inclock_phase_shift  	 	  = params.inclock_phase_shift;
   parameter enable_soft_cdr_mode 	 	  = params.enable_soft_cdr_mode;
   parameter sim_dpa_output_clock_phase_shift     = params.sim_dpa_output_clock_phase_shift;
   parameter sim_dpa_is_negative_ppm_drift        = params.sim_dpa_is_negative_ppm_drift;
   parameter sim_dpa_net_ppm_variation            = params.sim_dpa_net_ppm_variation;
   parameter enable_dpa_align_to_rising_edge_only = params.enable_dpa_align_to_rising_edge_only;
   parameter enable_dpa_initial_phase_selection   = params.enable_dpa_initial_phase_selection;
   parameter dpa_initial_phase_value              = params.dpa_initial_phase_value;
   parameter pll_self_reset_on_loss_lock          = params.pll_self_reset_on_loss_lock;
   parameter refclk_frequency                     = params.refclk_frequency;
   parameter enable_clock_pin_mode                = params.enable_clock_pin_mode;
   parameter data_rate                            = params.data_rate;
   parameter lpm_hint                             = params.lpm_hint;
   parameter lpm_type                             = params.lpm_type;

   port      dpa_pll_recal        = Bit#(1)'(0);
   port      pll_phasedone        = Bit#(1)'(1);
   port      rx_coreclk           = Bit#(sa)'('1);
   port      rx_data_align        = Bit#(1)'(0);
   port      rx_data_align_reset  = Bit#(1)'(0);
   port      rx_data_reset        = Bit#(1)'(0);
   port      rx_deskew            = Bit#(1)'(0);
   port      rx_dpa_lock_reset    = Bit#(sa)'(0);
   port      rx_dpll_enable       = Bit#(sa)'('1);
   port      rx_dpll_hold         = Bit#(sa)'(0);
   port      rx_dpll_reset        = Bit#(sa)'(0);
   port      rx_enable            = Bit#(1)'(1);
   port      rx_fifo_reset        = Bit#(sa)'(0);
   port      rx_pll_enable        = Bit#(1)'(1);
   port      rx_readclock         = Bit#(1)'(0);
   port      rx_reset             = Bit#(sa)'(0);
   port      rx_syncclock         = Bit#(1)'(0);

   output_clock outclk(rx_outclock);
   method             pins_in(rx_in) enable((*inhigh*)en0) reset_by(no_reset);
   method rx_locked   locked() reset_by(no_reset);
   method rx_out      pins_out() reset_by(no_reset);

   schedule (pins_in, locked, pins_out) CF (pins_in, locked, pins_out);

endmodule: vMkAltLvdsRx

module mkAlteraLVDS_RX#(LVDSRX params)(SERDES_RX#(in,out))
   provisos(  Bits#(in, sa)
	    , Bits#(out, sb)
	    , Mul#(sa, factor, sb)
	    , Div#(sb, factor, sa)
	    );

   if (valueOf(factor) > 10)
      error("The deserialization factor must be between 1 and 10, inclusive.");

   if (valueOf(sa) > 45 &&
       valueOf(sa) != 48 &&
       valueOf(sa) != 52 &&
       valueOf(sa) != 56 &&
       valueOf(sa) != 60 &&
       valueOf(sa) != 64)
      error("Invalid number of input channels.  Legal values are [1,45],48,52,56,60,64.");

   let _m <- vMkAltLvdsRx(params);
   return _m;
endmodule

endpackage: AlteraCells
