// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package TLM2Defines;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import BRAM :: *;
import BUtils::*;
import Connectable::*;
import DefaultValue::*;
import FIFO::*;
import FShow::*;
import GetPut::*;
import Randomizable::*;
import Vector::*;

`include "TLM.defines"


////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typedef TLMRequest#(`TLM_PRM_STD)  TLMRequestStd;
typedef TLMResponse#(`TLM_PRM_STD) TLMResponseStd;

typedef enum {READ, WRITE, UNKNOWN}          	    TLMCommand   deriving(Bounded, Bits, Eq);
typedef enum {REGULAR, DEBUG, CONTROL, UNKNOWN}     TLMMode      deriving(Bounded, Bits, Eq);
typedef enum {INCR, WRAP, CNST, UNKNOWN}     	    TLMBurstMode deriving(Bounded, Bits, Eq);
typedef enum {SUCCESS, ERROR, NO_RESPONSE, UNKNOWN} TLMStatus    deriving(Bounded, Bits, Eq);

typedef Bit#(id_size)                    TLMId#(`TLM_PRM_DCL);
typedef Bit#(addr_size)                  TLMAddr#(`TLM_PRM_DCL);
typedef Bit#(data_size)                  TLMData#(`TLM_PRM_DCL);
typedef UInt#(uint_size)                 TLMUInt#(`TLM_PRM_DCL);
typedef Bit#(TDiv#(data_size, 8))        TLMByteEn#(`TLM_PRM_DCL);
typedef Bit#(TLog#(TDiv#(data_size, 8))) TLMBurstSize#(`TLM_PRM_DCL);
typedef cstm_type                        TLMCustom#(`TLM_PRM_DCL);

typedef struct {TLMCommand              command;
                TLMMode                 mode;
                TLMAddr#(`TLM_PRM)      addr;
                TLMData#(`TLM_PRM)      data;
                TLMUInt#(`TLM_PRM)      burst_length;
                TLMByteEn#(`TLM_PRM)    byte_enable;
                TLMBurstMode            burst_mode;
                TLMBurstSize#(`TLM_PRM) burst_size;
                TLMUInt#(`TLM_PRM)      prty;
                Bool                    lock;
                TLMId#(`TLM_PRM)        thread_id;
                TLMId#(`TLM_PRM)        transaction_id;
                TLMId#(`TLM_PRM)        export_id;
                TLMCustom#(`TLM_PRM)    custom;
                } RequestDescriptor#(`TLM_PRM_DCL) deriving (Eq, Bits, Bounded);

typedef struct {TLMData#(`TLM_PRM)   data;
                TLMId#(`TLM_PRM)     transaction_id;
                TLMCustom#(`TLM_PRM) custom;
                } RequestData#(`TLM_PRM_DCL) deriving (Eq, Bits, Bounded);


typedef union tagged {RequestDescriptor#(`TLM_PRM) Descriptor;
                      RequestData#(`TLM_PRM)       Data;
                      } TLMRequest#(`TLM_PRM_DCL) deriving(Eq, Bits, Bounded);

typedef struct {TLMCommand           command;
                TLMData#(`TLM_PRM)   data;
                TLMStatus            status;
                TLMUInt#(`TLM_PRM)   prty;
                TLMId#(`TLM_PRM)     thread_id;
                TLMId#(`TLM_PRM)     transaction_id;
                TLMId#(`TLM_PRM)     export_id;
                TLMCustom#(`TLM_PRM) custom;
                } TLMResponse#(`TLM_PRM_DCL) deriving (Eq, Bits, Bounded);

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance DefaultValue #(RequestDescriptor#(`TLM_PRM))
   provisos(DefaultValue#(cstm_type));
   function defaultValue ();
      RequestDescriptor#(`TLM_PRM) request;
      request.command        = READ;
      request.mode           = REGULAR;
      request.addr           = 0;
      request.data           = 0;
      request.burst_length   = 1;
      request.byte_enable    = '1;
      request.burst_mode     = INCR;
      request.burst_size     = 3; // assume 32 bits for now.
      request.prty           = 0;
      request.lock           = False;
      request.thread_id      = 0;
      request.transaction_id = 0;
      request.export_id      = 0;
      request.custom         = defaultValue;
      return request;
   endfunction
endinstance

instance DefaultValue #(TLMResponse#(`TLM_PRM))
   provisos(DefaultValue#(cstm_type));
   function defaultValue ();
      TLMResponse#(`TLM_PRM) response;
      response.command        = READ;
      response.data           = 0;
      response.status         = SUCCESS;
      response.prty           = 0;
      response.thread_id      = 0;
      response.transaction_id = 0;
      response.export_id      = 0;
      response.custom         = defaultValue;
      return response;
   endfunction
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typeclass TLMRequestTC#(type a, `TLM_PRM_DCL)
   dependencies (a determines (`TLM_PRM));
   function TLMRequest#(`TLM_PRM) toTLMRequest(a value);
   function a                     fromTLMRequest(TLMRequest#(`TLM_PRM) value);
endtypeclass

typeclass TLMResponseTC#(type a, `TLM_PRM_DCL)
   dependencies (a determines (`TLM_PRM));
   function TLMResponse#(`TLM_PRM) toTLMResponse(a value);
   function a                      fromTLMResponse(TLMResponse#(`TLM_PRM) value);
endtypeclass

instance TLMRequestTC#(TLMRequest#(`TLM_PRM), `TLM_PRM);
   function toTLMRequest   = id;
   function fromTLMRequest = id;
endinstance

instance TLMResponseTC#(TLMResponse#(`TLM_PRM), `TLM_PRM);
   function toTLMResponse   = id;
   function fromTLMResponse = id;
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

module mkTLMRandomizer#(Maybe#(TLMCommand) m_command) (Randomize#(a))
   provisos(TLMRequestTC#(a, `TLM_PRM),
            Bits#(RequestDescriptor#(`TLM_PRM), s0),
            Bounded#(RequestDescriptor#(`TLM_PRM)),
            Bits#(RequestData#(`TLM_PRM), s1),
            Bounded#(RequestData#(`TLM_PRM))
            );

   Reg#(TLMUInt#(`TLM_PRM))                 count            <- mkReg(0);
   Randomize#(RequestDescriptor#(`TLM_PRM)) descriptor_gen   <- mkGenericRandomizer;
   Randomize#(TLMCommand)                   command_gen      <- mkConstrainedRandomizer(READ, WRITE);     // Avoid UNKNOWN
   Randomize#(TLMBurstMode)                 burst_mode_gen   <- mkConstrainedRandomizer(INCR, WRAP); // Avoid UNKNOWN
   Randomize#(TLMUInt#(`TLM_PRM))           burst_length_gen <- mkConstrainedRandomizer(1,16);            // legal sizes between 1 and 16
   Randomize#(Bit#(2))                      log_wrap_gen     <- mkConstrainedRandomizer(1,3);
   Randomize#(RequestData#(`TLM_PRM))       data_gen         <- mkGenericRandomizer;
   Reg#(TLMId#(`TLM_PRM))                   id               <- mkReg(0);

   Randomize#(Bit#(TLog#(SizeOf#(TLMBurstSize#(`TLM_PRM))))) log_size_gen <- mkGenericRandomizer;

   interface Control cntrl;
      method Action init();
   //       srand(0);
         descriptor_gen.cntrl.init();
         command_gen.cntrl.init();
         burst_mode_gen.cntrl.init();
         burst_length_gen.cntrl.init();
         log_wrap_gen.cntrl.init();
         data_gen.cntrl.init();
         log_size_gen.cntrl.init();
      endmethod
   endinterface

   method ActionValue#(a) next ();

      if (count == 0)
         begin
            let descriptor <- descriptor_gen.next;
            let burst_mode <- burst_mode_gen.next;

            descriptor.command <- command_gen.next;

            let log_size <- log_size_gen.next;

            descriptor.burst_size = ((1 << log_size) >> 1);

            // align address to burst_size
            let addr = descriptor.addr;
            addr = addr >> log_size;
            addr = addr << log_size;
            descriptor.addr = addr;

            if (burst_mode == WRAP)
               begin
                  let shift <- log_wrap_gen.next;
                  let burst_length = 2 << shift; // wrap legal lengths are 2, 4, 8, 16
                  descriptor.burst_length = burst_length;
                  descriptor.addr = addr;
               end
            else
               begin
                  let burst_length <- burst_length_gen.next;
                  descriptor.burst_length = burst_length;
               end

            descriptor.command = case (m_command) matches
                                    tagged Just .x: x;
                                    default       : descriptor.command;
                                 endcase;

            descriptor.mode = REGULAR;
            descriptor.byte_enable = getTLMByteEn(descriptor);
            descriptor.burst_mode = burst_mode;

            descriptor.thread_id = 0;
            descriptor.transaction_id = id;
            descriptor.export_id = 0;

            if (descriptor.command == READ)
               begin
                  descriptor.data = 0;
                  descriptor.byte_enable = '1;
               end
	    a r = fromTLMRequest(tagged Descriptor descriptor);
            let request = toTLMRequest(r);
            let remaining = getTLMCycleCount(descriptor) - 1;
            count <= remaining;
            id <= (remaining == 0) ? id + 1 : id;
            return fromTLMRequest(request);
         end
      else
         begin
            let data <- data_gen.next();
            data.transaction_id = unpack({0, id});
	    TLMRequest#(`TLM_PRM) request = tagged Data data;
            let remaining = count - 1;
            count <= remaining;
            id <= (remaining == 0) ? id + 1 : id;
            return fromTLMRequest(request);
         end

      endmethod

endmodule

instance Randomizable#(TLMRequest#(`TLM_PRM))
   provisos(Bits#(RequestDescriptor#(`TLM_PRM), s0),
            Bounded#(RequestDescriptor#(`TLM_PRM)),
            Bits#(RequestData#(`TLM_PRM), s1),
            Bounded#(RequestData#(`TLM_PRM))
            );

   module mkRandomizer (Randomize#(TLMRequest#(`TLM_PRM)));
      let ifc <- mkTLMRandomizer(Invalid);
      return ifc;
   endmodule

endinstance


module mkTLMSource#(Maybe#(TLMCommand) m_command, Bool verbose) (TLMSendIFC#(`TLM_RR))
   provisos(TLMRequestTC#(req_t, `TLM_PRM),
	    TLMResponseTC#(resp_t, `TLM_PRM),
	    Bits#(resp_t, s0),
	    Bits#(cstm_type, s1),
	    Bounded#(cstm_type));

   Reg#(Bool)                initialized   <- mkReg(False);

   FIFO#(resp_t)             response_fifo <- mkFIFO;
   Randomize#(req_t)         gen           <- mkTLMRandomizer(m_command);

   rule start (!initialized);
      gen.cntrl.init;
      initialized <= True;
   endrule

   rule grab_responses;
      let value = toTLMResponse(response_fifo.first);
      response_fifo.deq;
      if (verbose) $display("(%0d) Response is: ", $time, fshow(value));
   endrule

   interface Get tx;
      method ActionValue#(req_t) get;
         let value <- gen.next;
         if (toTLMRequest(value) matches tagged Descriptor .d)
            if (verbose) $display("(%0d) Request is: ", $time, fshow(d));
         return value;
      endmethod
   endinterface

   interface Put rx = toPut(response_fifo);

endmodule



module mkTLMSourceStd#(Maybe#(TLMCommand) m_command, Bool verbose) (TLMSendIFC#(TLMRequestStd, TLMResponseStd));

   Reg#(Bool)                initialized   <- mkReg(False);
   FIFO#(TLMResponseStd)     response_fifo <- mkFIFO;
   Randomize#(TLMRequestStd) gen           <- mkTLMRandomizer(m_command);

   rule start (!initialized);
      gen.cntrl.init;
      initialized <= True;
   endrule

   rule grab_responses;
      let value = response_fifo.first;
      response_fifo.deq;
      if (verbose) $display("(%0d) Response is: ", $time, fshow(value));
   endrule

   interface Get tx;
      method ActionValue#(TLMRequestStd) get;
         let value <- gen.next;
         if (value matches tagged Descriptor .d)
            if (verbose) $display("(%0d) Request is: ", $time, fshow(d));
         return value;
      endmethod
   endinterface

   interface Put rx = toPut(response_fifo);

endmodule

(* synthesize *)
module mkTLM2Source#(Maybe#(TLMCommand) m_command, Bool verbose) (TLMSendIFC#(TLMRequestStd, TLMResponseStd));

   Reg#(Bool)                initialized   <- mkReg(False);
   FIFO#(TLMResponseStd)     response_fifo <- mkFIFO;
   Randomize#(TLMRequestStd) gen           <- mkTLMRandomizer(m_command);

   rule start (!initialized);
      gen.cntrl.init;
      initialized <= True;
   endrule

   rule grab_responses;
      let value = response_fifo.first;
      response_fifo.deq;
      if (verbose) $display("(%0d) Response is: ", $time, fshow(value));
   endrule

   interface Get tx;
      method ActionValue#(TLMRequestStd) get;
         let value <- gen.next;
         if (value matches tagged Descriptor .d)
            if (verbose) $display("(%0d) Request is: ", $time, fshow(d));
         return value;
      endmethod
   endinterface

   interface Put rx = toPut(response_fifo);

endmodule

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

function TLMUInt#(`TLM_PRM) getTLMCycleCount (RequestDescriptor#(`TLM_PRM) desc);
   if (desc.command == READ)
      return 1;
   else
      return desc.burst_length;
endfunction

function Bit#(n) getTLMBurstSize (RequestDescriptor#(`TLM_PRM) desc)
   provisos(Add#(SizeOf#(TLMBurstSize#(`TLM_PRM)), 1, n));
   return zExtend(desc.burst_size) + 1;
endfunction

function Bit#(n) getTLMIncr (RequestDescriptor#(`TLM_PRM) desc)
   provisos(Add#(SizeOf#(TLMBurstSize#(`TLM_PRM)), 1, n));
   if (desc.burst_mode == CNST)
      return 0;
   else
      return zExtend(desc.burst_size) + 1;
endfunction

function TLMByteEn#(`TLM_PRM) getTLMByteEn (RequestDescriptor#(`TLM_PRM) tlm_descriptor);
   Bit#(TLog#(SizeOf#(TLMByteEn#(`TLM_PRM)))) addr = zExtend(tlm_descriptor.addr);
   TLMByteEn#(`TLM_PRM) all_ones = unpack('1);
   let mask = ~(all_ones << (tlm_descriptor.burst_size + 1));

   return (mask << addr);
endfunction

function RequestDescriptor#(`TLM_PRM) incrTLMAddr(RequestDescriptor#(`TLM_PRM) desc);
   let incr = getTLMIncr(desc);
   let addr = desc.addr + cExtend(incr);
   if (desc.burst_mode == WRAP)
      begin
         TLMAddr#(`TLM_PRM) size     = zExtend(pack(desc.burst_size)) + 1;
         TLMAddr#(`TLM_PRM) length   = zExtend(pack(desc.burst_length));
         let log_size   = countLSBZeros(size);
         let log_length = countLSBZeros(length);
         let total = log_size + log_length;
         TLMAddr#(`TLM_PRM) mask = (1 << total) - 1;
         addr = (addr & mask) | (desc.addr & ~mask);
      end
   desc.addr = addr;
   return desc;
endfunction

function Bit#(TLog#(TAdd#(n,1))) countLSBZeros (Bit#(n) value);
   Vector#(n, Bool) vector_value = unpack(value);
   let pos = findIndex(id, vector_value);
   case (pos) matches
      tagged Valid .p: return zExtend(pack(p));
      tagged  Invalid: return fromInteger(valueOf(n));
   endcase

endfunction


function TLMData#(`TLM_PRM) getTLMData(TLMRequest#(`TLM_PRM) request);
   case (request) matches
      (tagged Descriptor .d): return d.data;
      (tagged Data .d)      : return d.data;
   endcase
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance FShow#(TLMCommand);
   function Fmt fshow (TLMCommand label);
      case (label)
         READ:    return fshow("READ ");
         WRITE:   return fshow("WRITE");
         UNKNOWN: return fshow("UNKNOWN");
      endcase
   endfunction
endinstance

instance FShow#(TLMMode);
   function Fmt fshow (TLMMode label);
      case (label)
         REGULAR: return fshow("REG");
         DEBUG:   return fshow("DBG");
         CONTROL: return fshow("CTL");
	 UNKNOWN: return fshow("UNK");
      endcase
   endfunction
endinstance

instance FShow#(TLMBurstMode);
   function Fmt fshow (TLMBurstMode label);
      case (label)
         INCR: return fshow("INCR");
         CNST: return fshow("CNST");
         WRAP: return fshow("WRAP");
      endcase
   endfunction
endinstance

function Fmt fshowBurstMode (RequestDescriptor#(`TLM_PRM) op);
   case (op.burst_mode)
         INCR: return $format("INCR %0d", getTLMBurstSize(op));
         CNST: return $format("CNST %0d", getTLMBurstSize(op));
         WRAP: return $format("WRAP %0d", getTLMBurstSize(op));
      endcase
endfunction

instance FShow#(TLMStatus);
   function Fmt fshow (TLMStatus label);
      case (label)
         SUCCESS:     return fshow("SUCCESS");
         ERROR:       return fshow("ERROR  ");
         NO_RESPONSE: return fshow("NO_RESP");
	 UNKNOWN:     return fshow("UNKNOWN");
      endcase
   endfunction
endinstance

instance FShow#(RequestData#(`TLM_PRM))
   provisos(Add#(ignore0, uint_size, 32));

   function Fmt fshow (RequestData#(`TLM_PRM) data);
      return ($format("<TDATA [%0d]", data.transaction_id)
              +
              $format(" %h>", data.data));
   endfunction
endinstance

instance FShow#(RequestDescriptor#(`TLM_PRM));

   function Fmt fshow (RequestDescriptor#(`TLM_PRM) op);
      return ($format("<TDESC [%0d] ", op.transaction_id)
              +
              fshow(op.command)
              +
              fshow(" ")
              +
              fshowBurstMode(op)
              +
              $format(" (%0d)", op.burst_length)
              +
              $format(" A:%h", op.addr)
              +
              $format(" D:%h>", op.data));
   endfunction
endinstance

instance FShow#(TLMRequest#(`TLM_PRM))
   provisos(FShow#(RequestData#(`TLM_PRM)),
            FShow#(RequestDescriptor#(`TLM_PRM)));

   function Fmt fshow (TLMRequest#(`TLM_PRM) request);
      case (request) matches
         tagged Descriptor .a:
            return fshow(a);
         tagged Data .a:
            return fshow(a);
      endcase
   endfunction
endinstance

instance FShow#(TLMResponse#(`TLM_PRM));
   function Fmt fshow (TLMResponse#(`TLM_PRM) op);
      return ($format("<TRESP [%0d] ", op.transaction_id)
              +
              fshow(op.command)
              +
              fshow(" ")
              +
              fshow(op.status)
              +
              $format(" %h>", op.data));
   endfunction
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface TLMSendIFC#(type req, type resp);
   interface Get#(req)  tx;
   interface Put#(resp) rx;
endinterface

interface TLMRecvIFC#(type req, type resp);
   interface Get#(resp) tx;
   interface Put#(req)  rx;
endinterface

interface TLMReadWriteSendIFC#(type req, type resp);
   interface TLMSendIFC#(req, resp) read;
   interface TLMSendIFC#(req, resp) write;
endinterface

interface TLMReadWriteRecvIFC#(type req, type resp);
   interface TLMRecvIFC#(req, resp) read;
   interface TLMRecvIFC#(req, resp) write;
endinterface

interface TLMTransformIFC#(type req, type resp);
   interface TLMRecvIFC#(req, resp) in;
   interface TLMSendIFC#(req, resp) out;
endinterface

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance Connectable#(TLMSendIFC#(req, resp), TLMRecvIFC#(req, resp));
   module mkConnection#(TLMSendIFC#(req, resp) request, TLMRecvIFC#(req, resp) response) (Empty);
      mkConnection(request.tx, response.rx);
      mkConnection(request.rx, response.tx);
   endmodule
endinstance

instance Connectable#(TLMRecvIFC#(req, resp), TLMSendIFC#(req, resp));
   module mkConnection#(TLMRecvIFC#(req, resp) response, TLMSendIFC#(req, resp) request) (Empty);
      mkConnection(request.tx, response.rx);
      mkConnection(request.rx, response.tx);
   endmodule
endinstance

instance Connectable#(TLMReadWriteSendIFC#(req, resp), TLMReadWriteRecvIFC#(req, resp));
   module mkConnection#(TLMReadWriteSendIFC#(req, resp) request, TLMReadWriteRecvIFC#(req, resp) response) (Empty);
      let read_con  <- mkConnection(request.read,  response.read);
      let write_con <- mkConnection(request.write, response.write);
   endmodule
endinstance

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typeclass AddrMatch#(type addr_t, type ifc_t);
   function ifc_t addAddrMatch(function Bool addrMatch(addr_t value), ifc_t value);
endtypeclass

function Bool alwaysAddrMatch(a value);
   return True;
endfunction

function RequestDescriptor#(`TLM_PRM) addByteEnable (RequestDescriptor#(`TLM_PRM) request)
   provisos(Div#(data_size, 8, byte_size));
      let                    be_size     = valueOf(SizeOf#(TLMByteEn#(`TLM_PRM)));
      let                    size        = request.burst_size;
      let                    be          = '1;
                             be          = be >> (fromInteger(be_size - 1) - size);
      Bit#(TLog#(byte_size)) offset      = zExtend(request.addr);
      let                    request_new = request;
                             request_new.byte_enable = be << offset;
      return request_new;
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

instance TLMRequestTC#(BRAMRequest#(Bit#(addr_size), Bit#(data_size)), `TLM_PRM)
   provisos (DefaultValue #(BRAMRequest#(Bit#(addr_size), Bit#(data_size)))
             ,DefaultValue #( RequestDescriptor#(`TLM_PRM) ));

   function TLMRequest#(`TLM_PRM) toTLMRequest(BRAMRequest#(Bit#(addr_size), Bit#(data_size)) value);
      RequestDescriptor#(`TLM_PRM) request = defaultValue;
      request.command  = value.write ? WRITE : READ;
      request.data     = value.datain;
      request.addr     = value.address;
      // responseOnWrite must be true as TLM always generates a response
      return tagged Descriptor request;
   endfunction

   function BRAMRequest#(Bit#(addr_size), Bit#(data_size)) fromTLMRequest(TLMRequest#(`TLM_PRM) value);
      BRAMRequest#(Bit#(addr_size), Bit#(data_size)) brequest = defaultValue ;
      case (value) matches
         tagged Descriptor .desc:
            begin
               brequest.write     = desc.command == WRITE ;
               brequest.datain    = desc.data;
               brequest.address   = desc.addr;
               return brequest;
            end
         tagged Data .data:
            begin
               // XXXX should never occur
               return brequest;
            end
      endcase
   endfunction
endinstance

instance TLMResponseTC#(Bit#(data_size), `TLM_PRM)
   provisos (DefaultValue# (TLMResponse#(`TLM_PRM))
             );
   function TLMResponse#(`TLM_PRM)  toTLMResponse (Bit#(data_size) value );
      TLMResponse#(`TLM_PRM) response = defaultValue ;
      response.data = value ;
      return response ;
   endfunction
   function Bit#(data_size) fromTLMResponse (TLMResponse#(`TLM_PRM) value);
      return value.data;
   endfunction
endinstance

instance TLMRequestTC#(BRAMRequestBE#(Bit#(addr_size), Bit#(data_size), n), `TLM_PRM)
   provisos (DefaultValue #(BRAMRequest#(Bit#(addr_size), Bit#(data_size)))
             ,DefaultValue #( RequestDescriptor#(`TLM_PRM) )
             ,Div#(data_size,8,n)
             ,Div#(data_size,8,TDiv#(data_size,8))
             );

   function TLMRequest#(`TLM_PRM) toTLMRequest(BRAMRequestBE#(Bit#(addr_size), Bit#(data_size), n) value);
      RequestDescriptor#(`TLM_PRM) request = defaultValue;
      request.command  = value.writeen != 0 ? WRITE : READ;
      request.data     = value.datain;
      request.addr     = value.address;
      request.byte_enable = value.writeen != 0 ? value.writeen : '1 ;
      // responseOnWrite must be true as TLM always generates a response
      return tagged Descriptor request;
   endfunction

   function BRAMRequestBE#(Bit#(addr_size), Bit#(data_size), n) fromTLMRequest(TLMRequest#(`TLM_PRM) value);
      BRAMRequestBE#(Bit#(addr_size), Bit#(data_size),n) brequest = defaultValue ;
      case (value) matches
         tagged Descriptor .desc:
            begin
//               brequest.writeen   = desc.command == WRITE ?  desc.byte_enable : 0 ;
               brequest.datain    = desc.data;
               brequest.address   = desc.addr;
               return brequest;
            end
         tagged Data .data:
            begin
               // XXXX should never occur
               return brequest;
            end
      endcase
   endfunction
endinstance

endpackage

