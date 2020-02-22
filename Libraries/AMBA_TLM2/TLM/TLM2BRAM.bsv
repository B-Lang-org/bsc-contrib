// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package TLM2BRAM;

import BRAM :: *;
import ClientServer :: * ;
import DefaultValue :: * ;
import FIFOF::*;
import FShow:: *;
import GetPut :: *;
import TLM2Defines::*;

`include "TLM.defines"


module mkTLMBRAM (BRAMServer#(Bit#(anx), Bit#(dn)) bramifc, TLMRecvIFC#(reqt, respt) ifc)
   provisos(Bits#(respt, sr),
	    DefaultValue#(TLMResponse#(`TLM_PRM)),
	    Div#(data_size, 8, byte_size), // byte_size needs to be a power of 2 (i.e. 1, 2, 4 ..)
	    Add#(anx, TLog#(byte_size), an),
	    Add#(anx, iax, addr_size),
	    Add#(an, ia, addr_size),
            Add#(dn, id, data_size),
            Add#(TDiv#(dn,8), xn, byte_size),
            Div#(data_size,8,TDiv#(data_size,8)),
	    TLMRequestTC#(reqt,   `TLM_PRM),
	    TLMResponseTC#(respt, `TLM_PRM),
	    FShow#(TLMRequest#(`TLM_PRM)),
	    FShow#(RequestData#(`TLM_PRM))
      );

   BRAMServerBE#(Bit#(anx), Bit#(dn), TDiv#(dn,8)) bram_be = toBRAMServerBE(bramifc);
   let _z <- mkTLMBRAMBE(bram_be);
   return _z;

endmodule

// A module which provides a TLMRecv interface, built on any module that
// provides a BRAM1Port interface for example a mkBRAM module.
module mkTLMBRAMBE (BRAMServerBE#(Bit#(anx), Bit#(dn), nn) bramifc, TLMRecvIFC#(reqt, respt) ifc)
   provisos(Bits#(respt, sr),
	    DefaultValue#(TLMResponse#(`TLM_PRM)),
	    Div#(data_size, 8, byte_size), // byte_size needs to be a power of 2 (i.e. 1, 2, 4 ..)
	    Add#(anx, TLog#(byte_size), an),
	    Add#(anx, iax, addr_size),
	    Add#(an, ia, addr_size),
            Add#(dn, id, data_size),
            Add#(nn, xn, byte_size),
            Div#(data_size,8,TDiv#(data_size,8)),
	    TLMRequestTC#(reqt,   `TLM_PRM),
	    TLMResponseTC#(respt, `TLM_PRM),
	    FShow#(TLMRequest#(`TLM_PRM)),
	    FShow#(RequestData#(`TLM_PRM))
      );

   BRAMServerBE#(TLMAddr#(`TLM_PRM), TLMData#(`TLM_PRM), byte_size) bram = convertBRAMType (bramifc);

   FIFOF#(TLMCommand)  fifo_op       <- mkFIFOF;

   interface Get tx;
      method ActionValue#(respt) get () ;
         let val <- bram.response.get;
         let cmd = fifo_op.first;
         fifo_op.deq;
         TLMResponse#(`TLM_PRM) response = defaultValue ;
         response.data = {0,val};
         response.command = cmd;
         response.status  = SUCCESS; // Assume always OK if we get a response from the BRAM
         return fromTLMResponse(response);
      endmethod
   endinterface
   interface Put rx;
      method Action put (reqt req);
         case (toTLMRequest(req))  matches
            tagged Descriptor .d : begin
               case (d.command)
                  READ: begin
			   TLMAddr#(`TLM_PRM) addr = {0, (d.addr >> valueOf(TLog#(byte_size)))};
                           bram.request.put( BRAMRequestBE {writeen    :0,
                                                            responseOnWrite : True,
                                                            address  :addr,
			                                    datain   :0} );
			   fifo_op.enq(READ);
//			   $display("(%0d) READ ADDR: %h (%h)", $time, d.addr, addr);
                        end
                  WRITE: begin
			    TLMAddr#(`TLM_PRM) addr = {0, (d.addr >> valueOf(TLog#(byte_size)))};
                            bram.request.put( BRAMRequestBE {writeen    : d.byte_enable,
                                                             responseOnWrite : True,
			                                     address  :addr,
			                                     datain   :d.data} );
			    fifo_op.enq(WRITE);
//			    $display("(%0d) WRITE ADDR: %h (%h) VALUE: %h", $time, d.addr, addr, d.data);
                         end
               endcase
               // Bursts of Length 1 are supported.
               if (d.burst_length != 1)
                  $display( "ERROR: %m, burst length > 1 not supported ", fshow(d));
            end
            tagged Data .d : begin
               $display( "ERROR: data stream sent: %m, not supported", fshow(d));
            end
         endcase
      endmethod
   endinterface

endmodule


function BRAMServerBE#(TLMAddr#(`TLM_PRM), TLMData#(`TLM_PRM), n)
         convertBRAMType (BRAMServerBE#(Bit#(an), Bit#(dn), nn) ifcin)
	    provisos (Add#(an, ai, addr_size),
		      Add#(dn, di, data_size),
                      Add#(nn, ni, n));
   return
   (interface Server;
       interface Put request;
          method Action put (reqin);
             let req = BRAMRequestBE {writeen   : truncate(reqin.writeen),
                                      responseOnWrite: True, // TLM has write response
	                              address : truncate(reqin.address),
	                              datain  : truncate(reqin.datain)};
	     ifcin.request.put (req);
          endmethod
       endinterface
       interface Get response;
          method ActionValue#(TLMData#(`TLM_PRM)) get;
	     let value <-  ifcin.response.get;
	     return(extend(value));
	  endmethod
       endinterface
    endinterface
    );
endfunction


typeclass ToBRAMSeverBETC #(type a, type addr, type data, numeric type n)
   dependencies (a determines (addr, data, n));
   function BRAMServerBE#(addr, data, n) toBRAMServerBE (a ifc);
endtypeclass

instance ToBRAMSeverBETC #(BRAMServerBE#(addr, data, n), addr, data, n);
   function toBRAMServerBE = id ;
endinstance

instance ToBRAMSeverBETC #(BRAMServer#(addr, data), addr, data, n);
   function BRAMServerBE#(addr, data, n) toBRAMServerBE ( BRAMServer#(addr, data) ifcin );
      return
      (interface Server;
          interface Put request;
             method Action put ( BRAMRequestBE#(addr, data, n) reqin);
                if ( (reqin.writeen != '0) && (reqin.writeen != '1) )
                   $display ("Converting from a BRAM Server to BRAM Server BE with invalid Byte enable %b",
                             reqin.writeen );
                let req = BRAMRequest {write    : reqin.writeen != 0,
                                       responseOnWrite: reqin.responseOnWrite,
	                               address : reqin.address,
	                               datain  : reqin.datain } ;
                ifcin.request.put (req);
       endmethod
          endinterface
          interface Get response;
             method ActionValue#(data) get;
	        let value <-  ifcin.response.get;
	        return(value);
       endmethod
          endinterface
       endinterface);
   endfunction
endinstance



endpackage
