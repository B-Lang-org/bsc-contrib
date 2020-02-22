// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AhbPC;

import AhbDefines::*;
import DefaultValue::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAhbMasterPC#(AhbXtorMaster#(`TLM_PRM) master) (AhbXtorMaster#(`TLM_PRM));

   Wire#(Bool)                 hready_wire <- mkBypassWire;
   Wire#(AhbResp)              hresp_wire  <- mkBypassWire;
   Wire#(AhbData#(`TLM_PRM))   hrdata_wire <- mkBypassWire;
   Wire#(Bool)                 hgrant_wire <- mkBypassWire;

   if (genVerilog)
      begin

	 let params = defaultValue;
	 params.enable_slave = False;
	 AhbPC_Ifc#(`TLM_PRM) check <- mkAhbPC(params);

	 ////////////////////////////////////////////////////////////////////////////////
	 /// Protocol Checker connections;
	 ////////////////////////////////////////////////////////////////////////////////

	 rule connect_check;

	    check.haddr(master.bus.haddr);
	    check.hwdata(master.bus.hwdata);
	    check.hwrite(master.bus.hwrite);
	    check.htrans(master.bus.htrans);
	    check.hburst(master.bus.hburst);
	    check.hsize(master.bus.hsize);
	    check.hprot(master.bus.hprot);

	    check.hrdata(hrdata_wire);
	    check.hready(hready_wire);
	    check.hreadyOUT(hready_wire);
	    check.hresp(hresp_wire);

	    check.hCLKEN(True);
	    check.hgrantx(hgrant_wire);
	    check.hSELx(True);
	    check.hMASTLOCK(False);

	 endrule

	 rule connect2;
	    check.hlockx(master.arbiter.hlock);
	 endrule
   end

   interface AhbMaster bus;
	 // Inputs
	 method Action hrdata (value);
	    hrdata_wire <= value;
	    master.bus.hrdata(value);
	 endmethod
	 method Action hresp (value);
	    hresp_wire <= value;
	    master.bus.hresp(value);
	 endmethod
	 method Action hready (value);
	    hready_wire <= value;
	    master.bus.hready(value);
	 endmethod

	 // Outputs
	 method haddr  = master.bus.haddr;
	 method hwdata = master.bus.hwdata;
	 method hwrite = master.bus.hwrite;
	 method hburst = master.bus.hburst;

	 method htrans = master.bus.htrans;
	 method hsize  = master.bus.hsize;
	 method hprot  = master.bus.hprot;
      endinterface
      interface AhbMasterArbiter arbiter;
	 method hbusreq = master.arbiter.hbusreq;
	 method hlock   = master.arbiter.hlock;
	 method Action hgrant (value);
	    hgrant_wire <= value;
	    master.arbiter.hgrant(value);
	 endmethod
      endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAhbSlavePC#(AhbXtorSlave#(`TLM_PRM) slave) (AhbXtorSlave#(`TLM_PRM));

   Wire#(AhbAddr#(`TLM_PRM)) addr_wire     <- mkBypassWire;
   Wire#(AhbData#(`TLM_PRM)) wdata_wire    <- mkBypassWire;
   Wire#(AhbWrite)           write_wire    <- mkBypassWire;
   Wire#(AhbBurst)           burst_wire    <- mkBypassWire;
   Wire#(AhbTransfer)        transfer_wire <- mkBypassWire;
   Wire#(AhbSize)            size_wire     <- mkBypassWire;
   Wire#(AhbProt)            prot_wire     <- mkBypassWire;
   Wire#(Bool)               readyin_wire  <- mkBypassWire;
   Wire#(Bool)               select_wire   <- mkBypassWire;
   Wire#(AhbSplit)           mast_wire     <- mkBypassWire;

   if (genVerilog)
      begin

	 let params = defaultValue;
	 params.enable_master = False;
	 AhbPC_Ifc#(`TLM_PRM) check <- mkAhbPC(params);

	 ////////////////////////////////////////////////////////////////////////////////
	 /// Protocol Checker connections;
	 ////////////////////////////////////////////////////////////////////////////////

	 rule connect_check;

	    check.haddr(addr_wire);
	    check.hwdata(wdata_wire);
	    check.hwrite(write_wire);
	    check.hburst(burst_wire);
	    check.htrans(transfer_wire);
	    check.hsize(size_wire);
	    check.hprot(prot_wire);

	    check.hrdata(slave.bus.hrdata);
	    check.hready(readyin_wire);
	    check.hreadyOUT(slave.bus.hready);
	    check.hresp(slave.bus.hresp);

	    check.hCLKEN(True);
	    check.hgrantx(True);
	    check.hSELx(select_wire);
	    check.hMASTLOCK(False);

	 endrule

	 rule connect2;
	    check.hlockx(False);
	 endrule

   end


   interface AhbSlave bus;
      // Outputs
      method hrdata = slave.bus.hrdata;
      method hresp  = slave.bus.hresp;
      method hsplit = slave.bus.hsplit;
      method hready = slave.bus.hready;

      // Inputs
      method Action haddr (value);
	 addr_wire <= value;
	 slave.bus.haddr(value);
      endmethod
      method Action hwdata (value);
	 wdata_wire <= value;
	 slave.bus.hwdata(value);
      endmethod
      method Action hwrite (value);
	 write_wire <= value;
	 slave.bus.hwrite(value);
      endmethod
      method Action hburst (value);
	 burst_wire <= value;
	 slave.bus.hburst(value);
      endmethod
      method Action htrans (value);
	 transfer_wire <= value;
	 slave.bus.htrans(value);
      endmethod
      method Action hsize (value);
	 size_wire <= value;
	 slave.bus.hsize(value);
      endmethod
      method Action hprot (value);
	 prot_wire <= value;
	 slave.bus.hprot(value);
      endmethod
      method Action hreadyin (value);
	 readyin_wire <= value;
	 slave.bus.hreadyin(value);
      endmethod
      method Action hmast (value);
	 mast_wire <= value;
	 slave.bus.hmast(value);
      endmethod
   endinterface
   interface AhbSlaveSelector selector;
         method Action select (value);
	    select_wire <= value;
	    slave.selector.select(value);
	 endmethod
   endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AhbPC_Ifc#(`TLM_PRM_DCL);
   // Slave Inputs
   (* prefix = "", result = "unused0" *)
   method Action      haddr((* port = "HADDR" *)    AhbAddr#(`TLM_PRM) addr);
   (* prefix = "", result = "unused1" *)
   method Action      hwdata((* port = "HWDATA" *)  AhbData#(`TLM_PRM) data);
   (* prefix = "", result = "unused2" *)
   method Action      hwrite((* port = "HWRITE" *)  AhbWrite    value);
   (* prefix = "", result = "unused3" *)
   method Action      htrans((* port = "HTRANS" *)  AhbTransfer value);
   (* prefix = "", result = "unused4" *)
   method Action      hburst((* port = "HBURST" *)  AhbBurst    value);
   (* prefix = "", result = "unused5" *)
   method Action      hsize((* port = "HSIZE" *)    AhbSize     value);
   (* prefix = "", result = "unused6" *)
   method Action      hprot((* port = "HPROT" *)    AhbProt     value);

   // Master Inputs
   (* prefix = "", result = "unused7" *)
   method Action      hrdata((* port = "HRDATA" *) AhbData#(`TLM_PRM) data);
   (* prefix = "", result = "unused8" *)
   method Action      hready((* port = "HREADY" *) Bool value);
   (* prefix = "", result = "unused9" *)
   method Action      hreadyOUT((* port = "HREADYOUT" *) Bool value);
   (* prefix = "", result = "unused10" *)
   method Action      hresp((* port = "HRESP" *) AhbResp response);


   // Other Inputs
   (* prefix = "", result = "unused11" *)
   method Action      hCLKEN((* port = "HCLKEN" *) Bool value);
   (* prefix = "", result = "unused12" *)
   method Action      hgrantx((* port = "HGRANTx" *) Bool value);
   (* prefix = "", result = "unused13" *)
   method Action      hSELx((* port = "HSELx" *) Bool value);
   (* prefix = "", result = "unused14" *)
   method Action      hlockx((* port = "HLOCKx" *) Bool value);
   (* prefix = "", result = "unused15" *)
   method Action      hMASTLOCK((* port = "HMASTLOCK" *) Bool value);

endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typedef enum {PROVE, ASSUME, COVER, IGNORE} FVPropType deriving(Bounded, Bits, Eq);

typedef struct {Bool         enable_master;
		Bool         enable_slave;
		Bool         ignore_align;
		AhbPropTypes master;
		AhbPropTypes slave;
		} AhbPCPrms deriving (Eq);

typedef struct {FVPropType err;
		FVPropType rec;
		FVPropType add;
		FVPropType cfg;
		FVPropType inf;
		FVPropType alt;
		FVPropType aux;
		} AhbPropTypes deriving (Eq, Bits);

instance DefaultValue#(AhbPCPrms);
   function AhbPCPrms defaultValue ();
      return AhbPCPrms {enable_master: True,
			enable_slave:  True,
			ignore_align:  False,
			master:        unpack(0),
			slave:         unpack(0)
			};
   endfunction
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import "BVI" AhbPC =
module mkAhbPC#(AhbPCPrms params) (AhbPC_Ifc#(`TLM_PRM));

   // Configure AhbPC for Master, Slave or both.
   parameter P_ENABLE_MASTER  = pack(params.enable_master); // 0=disabled, 1=enabled.
   parameter P_ENABLE_SLAVE   = pack(params.enable_slave);  // 0=disabled, 1=enabled.
   parameter P_IGNORE_ALIGN   = pack(params.ignore_align);  // 0=disabled, 1=enabled.

   parameter ADDRESS_WIDTH    = valueOf(addr_size);
   parameter DATA_WIDTH       = valueOf(data_size);

   // Formal Verification
   parameter ERRM_PropertyType = pack(params.master.err);
   parameter RECM_PropertyType = pack(params.master.rec);
   parameter ADDM_PropertyType = pack(params.master.add);
   parameter CFGM_PropertyType = pack(params.master.cfg);
   parameter INFM_PropertyType = pack(params.master.inf);
   parameter ALTM_PropertyType = pack(params.master.alt);
   parameter AUXM_PropertyType = pack(params.master.aux);
   //
   parameter ERRS_PropertyType = pack(params.slave.err);
   parameter RECS_PropertyType = pack(params.slave.rec);
   parameter ADDS_PropertyType = pack(params.slave.add);
   parameter CFGS_PropertyType = pack(params.slave.cfg);
   parameter INFS_PropertyType = pack(params.slave.inf);
   parameter ALTS_PropertyType = pack(params.slave.alt);
   parameter AUXS_PropertyType = pack(params.slave.aux);

/* -----\/----- EXCLUDED -----\/-----

   // The maximum number of burst--incr transfers.
   parameter BURST_INCR_COUNTER_TYPE   =  6 ; // width of _MAXVAL
   parameter BURST_INCR_COUNTER_MAXVAL = -1 ; // _TYPE{1}

  -----/\----- EXCLUDED -----/\----- */


   default_clock clk(HCLK);
   default_reset rst(HRESETn);

   method haddr     (HADDR     )enable((*inhigh*)IGNORE00);
   method hwdata    (HWDATA    )enable((*inhigh*)IGNORE01);
   method hwrite    (HWRITE    )enable((*inhigh*)IGNORE02);
   method htrans    (HTRANS    )enable((*inhigh*)IGNORE03);
   method hburst    (HBURST    )enable((*inhigh*)IGNORE04);
   method hsize     (HSIZE     )enable((*inhigh*)IGNORE05);
   method hprot     (HPROT     )enable((*inhigh*)IGNORE06);

   method hrdata    (HRDATA    )enable((*inhigh*)IGNORE07);
   method hready    (HREADY    )enable((*inhigh*)IGNORE08);
   method hreadyOUT (HREADYOUT )enable((*inhigh*)IGNORE09);
   method hresp     (HRESP     )enable((*inhigh*)IGNORE10);

   method hCLKEN    (HCLKEN    )enable((*inhigh*)IGNORE11);
   method hgrantx   (HGRANTx   )enable((*inhigh*)IGNORE12);
   method hSELx     (HSELx     )enable((*inhigh*)IGNORE13);
   method hlockx    (HLOCKx    )enable((*inhigh*)IGNORE14);
   method hMASTLOCK (HMASTLOCK )enable((*inhigh*)IGNORE15);

   schedule (haddr, hwdata, hwrite, htrans, hburst, hsize, hprot, hrdata, hready, hreadyOUT, hresp, hCLKEN, hgrantx, hSELx, hlockx, hMASTLOCK) CF (haddr, hwdata, hwrite, htrans, hburst, hsize, hprot, hrdata, hready, hreadyOUT, hresp, hCLKEN, hgrantx, hSELx, hlockx, hMASTLOCK);

endmodule


endpackage
