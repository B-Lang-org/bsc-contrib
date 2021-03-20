// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AHBPC;

import AHBDefines::*;
`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkAHBMasterPC#(AHBFabricMaster#(`TLM_PRM) master) (AHBFabricMaster#(`TLM_PRM));

   Wire#(Bool)                 hready_wire <- mkBypassWire;
   Wire#(AHBResp)              hresp_wire  <- mkBypassWire;
   Wire#(AHBData#(`TLM_PRM)) hrdata_wire <- mkBypassWire;
   Wire#(Bool)                 hgrant_wire <- mkBypassWire;

   if (genVerilog)
      begin

	 let params = mkParams;
	 AHBPC_Ifc#(`TLM_PRM) check <- mkAHBPC(params);

	 ////////////////////////////////////////////////////////////////////////////////
	 /// Protocol Checker connections;
	 ////////////////////////////////////////////////////////////////////////////////

	 rule connect_check;

	    check.hADDR(master.bus.hADDR);
	    check.hWDATA(master.bus.hWDATA);
	    check.hWRITE(master.bus.hWRITE);
	    check.hTRANS(master.bus.hTRANS);
	    check.hBURST(master.bus.hBURST);
	    check.hSIZE(master.bus.hSIZE);
	    check.hPROT(master.bus.hPROT);

	    check.hRDATA(hrdata_wire);
	    check.hREADY(hready_wire);
	    check.hREADYOUT(hready_wire);
	    check.hRESP(hresp_wire);

	    check.hCLKEN(True);
	    check.hGRANTx(hgrant_wire);
	    check.hSELx(True);
	    check.hLOCKx(False);
	    check.hMASTLOCK(False);

	 endrule
   end

   interface AHBMaster bus;
	 // Inputs
	 method Action hRDATA (value);
	    hrdata_wire <= value;
	    master.bus.hRDATA(value);
	 endmethod
	 method Action hRESP (value);
	    hresp_wire <= value;
	    master.bus.hRESP(value);
	 endmethod
	 method Action hREADY (value);
	    hready_wire <= value;
	    master.bus.hREADY(value);
	 endmethod

	 // Outputs
	 method hADDR  = master.bus.hADDR;
	 method hWDATA = master.bus.hWDATA;
	 method hWRITE = master.bus.hWRITE;
	 method hBURST = master.bus.hBURST;

	 method hTRANS = master.bus.hTRANS;
	 method hSIZE  = master.bus.hSIZE;
	 method hPROT  = master.bus.hPROT;
      endinterface
      interface AHBMasterArbiter arbiter;
	 method hBUSREQ = master.arbiter.hBUSREQ;
	 method hLOCK   = master.arbiter.hLOCK;
	 method Action hGRANT (value);
	    hgrant_wire <= value;
	    master.arbiter.hGRANT(value);
	 endmethod
      endinterface

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AHBPC_Ifc#(`TLM_PRM_DCL);
   // Slave Inputs
   (* prefix = "", result = "unused0" *)
   method Action      hADDR((* port = "HADDR" *)    AHBAddr#(`TLM_PRM) addr);
   (* prefix = "", result = "unused1" *)
   method Action      hWDATA((* port = "HWDATA" *)  AHBData#(`TLM_PRM) data);
   (* prefix = "", result = "unused2" *)
   method Action      hWRITE((* port = "HWRITE" *)  AHBWrite    value);
   (* prefix = "", result = "unused3" *)
   method Action      hTRANS((* port = "HTRANS" *)  AHBTransfer value);
   (* prefix = "", result = "unused4" *)
   method Action      hBURST((* port = "HBURST" *)  AHBBurst    value);
   (* prefix = "", result = "unused5" *)
   method Action      hSIZE((* port = "HSIZE" *)    AHBSize     value);
   (* prefix = "", result = "unused6" *)
   method Action      hPROT((* port = "HPROT" *)    AHBProt     value);

   // Master Inputs
   (* prefix = "", result = "unused7" *)
   method Action      hRDATA((* port = "HRDATA" *) AHBData#(`TLM_PRM) data);
   (* prefix = "", result = "unused8" *)
   method Action      hREADY((* port = "HREADY" *) Bool value);
   (* prefix = "", result = "unused9" *)
   method Action      hREADYOUT((* port = "HREADYOUT" *) Bool value);
   (* prefix = "", result = "unused10" *)
   method Action      hRESP((* port = "HRESP" *) AHBResp response);


   // Other Inputs
   (* prefix = "", result = "unused11" *)
   method Action      hCLKEN((* port = "HCLKEN" *) Bool value);
   (* prefix = "", result = "unused12" *)
   method Action      hGRANTx((* port = "HGRANTx" *) Bool value);
   (* prefix = "", result = "unused13" *)
   method Action      hSELx((* port = "HSELx" *) Bool value);
   (* prefix = "", result = "unused14" *)
   method Action      hLOCKx((* port = "HLOCKx" *) Bool value);
   (* prefix = "", result = "unused15" *)
   method Action      hMASTLOCK((* port = "HMASTLOCK" *) Bool value);

endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typeclass Parameters#(type t);
   function t mkParams ();
endtypeclass

typedef enum {PROVE, ASSUME, COVER, IGNORE} FVPropType deriving(Bounded, Bits, Eq);

typedef struct {Bool         enable_master;
		Bool         enable_slave;
		Bool         ignore_align;
		AHBPropTypes master;
		AHBPropTypes slave;
		} AHBPCPrms deriving (Eq);

typedef struct {FVPropType err;
		FVPropType rec;
		FVPropType add;
		FVPropType cfg;
		FVPropType inf;
		FVPropType alt;
		FVPropType aux;
		} AHBPropTypes deriving (Eq, Bits);

instance Parameters#(AHBPCPrms);
   function AHBPCPrms mkParams ();
      return AHBPCPrms {enable_master: True,
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
module mkAHBPC#(AHBPCPrms params) (AHBPC_Ifc#(`TLM_PRM));

   // Configure AhbPC for Master, Slave or both.
   parameter P_ENABLE_MASTER  = pack(params.enable_master); // 0=disabled, 1=enabled.
   parameter P_ENABLE_SLAVE   = pack(params.enable_slave);  // 0=disabled, 1=enabled.
   parameter P_IGNORE_ALIGN   = pack(params.ignore_align);  // 0=disabled, 1=enabled.

   parameter ADDRESS_WIDTH = valueOf(addr_size);
   parameter DATA_WIDTH    = valueOf(data_size);

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

   method hADDR     (HADDR     )enable((*inhigh*)IGNORE00);
   method hWDATA    (HWDATA    )enable((*inhigh*)IGNORE01);
   method hWRITE    (HWRITE    )enable((*inhigh*)IGNORE02);
   method hTRANS    (HTRANS    )enable((*inhigh*)IGNORE03);
   method hBURST    (HBURST    )enable((*inhigh*)IGNORE04);
   method hSIZE     (HSIZE     )enable((*inhigh*)IGNORE05);
   method hPROT     (HPROT     )enable((*inhigh*)IGNORE06);

   method hRDATA    (HRDATA    )enable((*inhigh*)IGNORE07);
   method hREADY    (HREADY    )enable((*inhigh*)IGNORE08);
   method hREADYOUT (HREADYOUT )enable((*inhigh*)IGNORE09);
   method hRESP     (HRESP     )enable((*inhigh*)IGNORE10);

   method hCLKEN    (HCLKEN    )enable((*inhigh*)IGNORE11);
   method hGRANTx   (HGRANTx   )enable((*inhigh*)IGNORE12);
   method hSELx     (HSELx     )enable((*inhigh*)IGNORE13);
   method hLOCKx    (HLOCKx    )enable((*inhigh*)IGNORE14);
   method hMASTLOCK (HMASTLOCK )enable((*inhigh*)IGNORE15);

   schedule (hADDR, hWDATA, hWRITE, hTRANS, hBURST, hSIZE, hPROT, hRDATA, hREADY, hREADYOUT, hRESP, hCLKEN, hGRANTx, hSELx, hLOCKx, hMASTLOCK) CF (hADDR, hWDATA, hWRITE, hTRANS, hBURST, hSIZE, hPROT, hRDATA, hREADY, hREADYOUT, hRESP, hCLKEN, hGRANTx, hSELx, hLOCKx, hMASTLOCK);

endmodule


endpackage
