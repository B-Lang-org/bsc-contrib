////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : PCIE.bsv
//  Description   : PCI-Express Types and Info
////////////////////////////////////////////////////////////////////////////////
package PCIE;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import Clocks            ::*;
import Vector            ::*;
import Connectable       ::*;
import GetPut            ::*;
import Reserved          ::*;
import TieOff            ::*;
import DefaultValue      ::*;
import DReg              ::*;
import Gearbox           ::*;
import FIFO              ::*;

////////////////////////////////////////////////////////////////////////////////
/// Types
////////////////////////////////////////////////////////////////////////////////
typedef Bit#(30)         DWAddress;
typedef Bit#(62)         DWAddress64;
typedef Bit#(7)          Offset;
typedef Bit#(8)          BusNumber;
typedef Bit#(5)          DevNumber;
typedef Bit#(3)          FuncNumber;

typedef Bit#(10)         TLPLength;
typedef Bit#(4)          TLPFirstDWBE;
typedef Bit#(4)          TLPLastDWBE;
typedef Bit#(8)          TLPTag;
typedef Bit#(7)          TLPLowerAddr;
typedef Bit#(12)         TLPByteCount;
typedef Bit#(10)         TLPRegNum;

typedef Bit#(11)         DWCount;
typedef Bit#(13)         ByteCount;

typedef struct {
   Bool                  sof;
   Bool                  eof;
   Bit#(7)               hit;
   Bit#(bytes)           be;
   Bit#(TMul#(bytes, 8)) data;
} TLPData#(type bytes) deriving (Bits, Eq);

instance DefaultValue#(TLPData#(n));
   defaultValue =
   TLPData {
      sof:  False,
      eof:  False,
      hit:  0,
      be:   0,
      data: 0
      };
endinstance

typedef enum {
   DEFAULT_ORDERING  = 0,
   ID_BASED_ORDERING = 1
   } TLPAttrIDBasedOrdering deriving (Bits, Eq);

typedef enum {
   STRICT_ORDERING   = 0,
   RELAXED_ORDERING  = 1
   } TLPAttrRelaxedOrdering deriving (Bits, Eq);

typedef enum {
   SNOOPING_REQD     = 0,
   NO_SNOOPING_REQD  = 1
   } TLPAttrNoSnoop deriving (Bits, Eq);

typedef enum {
   NOT_POISONED      = 0,
   POISONED          = 1
   } TLPPoison deriving (Bits, Eq);

typedef enum {
   NO_DIGEST_PRESENT = 0,
   DIGEST_PRESENT    = 1
   } TLPDigest deriving (Bits, Eq);

typedef enum {
   TRAFFIC_CLASS_0 = 0,
   TRAFFIC_CLASS_1 = 1,
   TRAFFIC_CLASS_2 = 2,
   TRAFFIC_CLASS_3 = 3,
   TRAFFIC_CLASS_4 = 4,
   TRAFFIC_CLASS_5 = 5,
   TRAFFIC_CLASS_6 = 6,
   TRAFFIC_CLASS_7 = 7
   } TLPTrafficClass deriving (Bits, Eq);

typedef enum {
   MEMORY_READ_WRITE   = 0,
   MEMORY_READ_LOCKED  = 1,
   IO_REQUEST          = 2,
   UNKNOWN_TYPE_3      = 3,
   CONFIG_0_READ_WRITE = 4,
   CONFIG_1_READ_WRITE = 5,
   UNKNOWN_TYPE_6      = 6,
   UNKNOWN_TYPE_7      = 7,
   UNKNOWN_TYPE_8      = 8,
   UNKNOWN_TYPE_9      = 9,
   COMPLETION          = 10,
   COMPLETION_LOCKED   = 11,
   UNKNOWN_TYPE_12     = 12,
   UNKNOWN_TYPE_13     = 13,
   UNKNOWN_TYPE_14     = 14,
   UNKNOWN_TYPE_15     = 15,
   MSG_ROUTED_TO_ROOT  = 16,
   MSG_ROUTED_BY_ADDR  = 17,
   MSG_ROUTED_BY_ID    = 18,
   MSG_ROOT_BROADCAST  = 19,
   MSG_LOCAL           = 20,
   MSG_GATHER          = 21,
   UNKNOWN_TYPE_22     = 22,
   UNKNOWN_TYPE_23     = 23,
   UNKNOWN_TYPE_24     = 24,
   UNKNOWN_TYPE_25     = 25,
   UNKNOWN_TYPE_26     = 26,
   UNKNOWN_TYPE_27     = 27,
   UNKNOWN_TYPE_28     = 28,
   UNKNOWN_TYPE_29     = 29,
   UNKNOWN_TYPE_30     = 30,
   UNKNOWN_TYPE_31     = 31
   } TLPPacketType deriving (Bits, Eq);

typedef enum {
   MEM_READ_3DW_NO_DATA = 0,
   MEM_READ_4DW_NO_DATA = 1,
   MEM_WRITE_3DW_DATA   = 2,
   MEM_WRITE_4DW_DATA   = 3
   } TLPPacketFormat deriving (Bits, Eq);

typedef enum {
   SUCCESSFUL_COMPLETION   = 0,
   UNSUPPORTED_REQUEST     = 1,
   CONFIG_REQ_RETRY_STATUS = 2,
   UNKNOWN_STATUS_3        = 3,
   COMPLETER_ABORT         = 4,
   UNKNOWN_STATUS_5        = 5,
   UNKNOWN_STATUS_6        = 6,
   UNKNOWN_STATUS_7        = 7
   } TLPCompletionStatus deriving (Bits, Eq);

typedef enum {
   BYTE_COUNT_ORIGINAL     = 0,
   BYTE_COUNT_MODIFIED     = 1
   } TLPByteCountModified deriving (Bits, Eq);

typedef enum {
   DEFAULT_UNTRANSLATED    = 0,
   TRANSLATION_REQUEST     = 1,
   TRANSLATED              = 2,
   RESERVED                = 3
   } TLPAddressType deriving (Bits, Eq);

typedef enum {
   ASSERT_INTA           = 0,
   ASSERT_INTB           = 1,
   ASSERT_INTC           = 2,
   ASSERT_INTD           = 3,
   DEASSERT_INTA         = 4,
   DEASSERT_INTB         = 5,
   DEASSERT_INTC         = 6,
   DEASSERT_INTD         = 7
   } MSIInterruptCode deriving (Bits, Eq);

typedef enum {
   UNKNOWN_CODE_0        = 0,
   UNKNOWN_CODE_1        = 1,
   UNKNOWN_CODE_2        = 2,
   UNKNOWN_CODE_3        = 3,
   PM_ACTIVE_STATE_NAK   = 4,
   UNKNOWN_CODE_5        = 5,
   UNKNOWN_CODE_6        = 6,
   UNKNOWN_CODE_7        = 7,
   PM_PME                = 8,
   PM_TURN_OFF           = 9,
   UNKNOWN_CODE_10       = 10,
   PME_TO_ACK            = 11,
   UNKNOWN_CODE_12       = 12,
   UNKNOWN_CODE_13       = 13,
   UNKNOWN_CODE_14       = 14,
   UNKNOWN_CODE_15       = 15
   } MSIPowerMgtCode deriving (Bits, Eq);

typedef enum {
   ERR_COR               = 0,
   ERR_NONFATAL          = 1,
   UNKNOWN_ERR_2         = 2,
   ERR_FATAL             = 3
   } MSIErrorCode deriving (Bits, Eq);

typedef enum {
   ATTN_INDICATOR_OFF    = 0,
   ATTN_INDICATOR_ON     = 1,
   UNKNOWN_CODE_2        = 2,
   ATTN_INDICATOR_BLINK  = 3,
   POWER_INDICATOR_OFF   = 4,
   POWER_INDICATOR_ON    = 5,
   UNKNOWN_CODE_6        = 6,
   POWER_INDICATOR_BLINK = 7,
   ATTN_BUTTON_PRESSED   = 8,
   UNKNOWN_CODE_9        = 9,
   UNKNOWN_CODE_10       = 10,
   UNKNOWN_CODE_11       = 11,
   UNKNOWN_CODE_12       = 12,
   UNKNOWN_CODE_13       = 13,
   UNKNOWN_CODE_14       = 14,
   UNKNOWN_CODE_15       = 15
   } MSIHotPlugCode deriving (Bits, Eq);

typedef union tagged {
   void                 Unlock;
   MSIPowerMgtCode      PowerManagement;
   MSIInterruptCode     Interrupt;
   MSIErrorCode         Error;
   MSIHotPlugCode       HotPlug;
   void                 SlotPower;
   void                 VendorType0; // the doc says this is two bits, but code=1 conflicts with vendor type 1.
   void                 VendorType1;
   } TLPMessageCode deriving (Eq);

instance Bits#(TLPMessageCode, 8);
   function Bit#(8) pack(TLPMessageCode x);
      let result = ?;
      case(x) matches
         tagged Unlock               : result = 8'b0000_0000;
         tagged PowerManagement .code: result = { 4'b0001, pack(code) };
         tagged Interrupt       .code: result = { 5'b0010_0, pack(code) };
         tagged Error           .code: result = { 6'b0011_00, pack(code) };
         tagged HotPlug         .code: result = { 4'b0100, pack(code) };
         tagged SlotPower            : result = 8'b0101_0000;
         tagged VendorType0          : result = 8'b0111_1110;
         tagged VendorType1          : result = 8'b0111_1111;
      endcase
      return result;
   endfunction
   function TLPMessageCode unpack(Bit#(8) x);
      let result = ?;
      case(x[7:4])
         4'b0000: result = tagged Unlock;
         4'b0001: result = tagged PowerManagement(unpack(x[3:0]));
         4'b0010: result = tagged Interrupt(unpack(x[2:0]));
         4'b0011: result = tagged Error(unpack(x[1:0]));
         4'b0100: result = tagged HotPlug(unpack(x[3:0]));
         4'b0101: result = tagged SlotPower;
         4'b0111: result = (x[0] == 1) ? tagged VendorType1 : tagged VendorType0;
      endcase
      return result;
   endfunction
endinstance

typedef struct {
   BusNumber  bus;
   DevNumber  dev;
   FuncNumber func;
   } PciId deriving (Eq, Bits);

instance DefaultValue#(PciId);
   defaultValue =
   PciId {
      bus:  0,
      dev:  0,
      func: 0
      };
endinstance

typedef enum {
   RECEIVE_BUFFER_AVAILABLE_SPACE = 0,
   RECEIVE_CREDITS_GRANTED        = 1,
   RECEIVE_CREDITS_CONSUMED       = 2,
   UNKNOWN_3                      = 3,
   TRANSMIT_USER_CREDITS_AVAIALBE = 4,
   TRANSMIT_CREDIT_LIMIT          = 5,
   TRANSMIT_CREDITS_CONSUMED      = 6,
   UNKNOWN_7                      = 7
   } FlowControlInfoSelect deriving (Bits, Eq);

typedef struct {
   Bool        fast_train_sim_only;
   Real        clock_period;
   } PCIEParams deriving (Bits, Eq);

instance DefaultValue#(PCIEParams);
   defaultValue =
   PCIEParams {
      fast_train_sim_only: False,
      clock_period:        10.000
      };
endinstance

typedef enum {
   APERTURE_128B     = 7,
   APERTURE_256B     = 8,
   APERTURE_512B     = 9,
   APERTURE_1K       = 10,
   APERTURE_2K       = 11,
   APERTURE_4K       = 12,
   APERTURE_8K	     = 13,
   APERTURE_16K	     = 14,
   APERTURE_32K	     = 15,
   APERTURE_64K	     = 16,
   APERTURE_128K     = 17,
   APERTURE_256K     = 18,
   APERTURE_512K     = 19,
   APERTURE_1M	     = 20,
   APERTURE_2M       = 21,
   APERTURE_4M       = 22,
   APERTURE_8M	     = 23,
   APERTURE_16M	     = 24,
   APERTURE_32M	     = 25,
   APERTURE_64M	     = 26,
   APERTURE_128M     = 27,
   APERTURE_256M     = 28,
   APERTURE_512M     = 29,
   APERTURE_1G	     = 30,
   APERTURE_2G       = 31,
   APERTURE_4G       = 32,
   APERTURE_8G	     = 33,
   APERTURE_16G	     = 34,
   APERTURE_32G	     = 35,
   APERTURE_64G	     = 36,
   APERTURE_128G     = 37,
   APERTURE_256G     = 38,
   APERTURE_512G     = 39,
   APERTURE_1E	     = 40,
   APERTURE_2E       = 41
} BARAperture deriving (Bits, Eq);

typedef enum {
   BAR0     = 0,
   BAR1     = 1,
   BAR2     = 2,
   BAR3     = 3,
   BAR4     = 4,
   BAR5     = 5,
   EXPANSION_ROM = 6
   } BARID deriving (Bits, Eq);

typedef enum {
   PF0      = 0,
   PF1      = 1,
   VF0      = 64,
   VF1      = 65,
   VF2      = 66,
   VF3      = 67,
   VF4      = 68,
   VF5      = 69,
   LAST     = 255
   } TargetFunction deriving (Bits, Eq);

typedef enum {
   MEMORY_READ             = 0,
   MEMORY_WRITE            = 1,
   IO_READ                 = 2,
   IO_WRITE                = 3,
   MEMORY_FETCH_ADD        = 4,
   MEMORY_UNCOND_SWAP      = 5,
   MEMORY_COMP_SWAP        = 6,
   LOCKED_READ             = 7,
   TYPE0_CFG_READ          = 8,
   TYPE1_CFG_READ          = 9,
   TYPE0_CFG_WRITE         = 10,
   TYPE1_CFG_WRITE         = 11,
   NOT_VEND_ATS_MESSAGE    = 12,
   VENDOR_MESSAGE          = 13,
   ATS_MESSAGE             = 14,
   RESERVED                = 15
   } RequestType deriving (Bits, Eq);

typedef enum {
   NORMAL_TERMINATION      = 0,
   COMPLETION_POISONED     = 1,
   TERMINATED_UR_CA_CRS    = 2,
   NO_DATA_OR_HIGH_BYTECNT = 3,
   SAME_TAG                = 4,
   START_ADDRESS           = 5,
   INVALID_TAG             = 6,
   FUNCTION_LEVEL_RESET    = 8,
   TIMEOUT                 = 9
} ErrorCode deriving (Bits, Eq);

////////////////////////////////////////////////////////////////////////////////
/// Packet Types
////////////////////////////////////////////////////////////////////////////////
typedef struct {
   ReservedZero#(1)        r1;
   TLPPacketFormat         format;
   TLPPacketType           pkttype;
   ReservedZero#(1)        r2;
   TLPTrafficClass         tclass;
   ReservedZero#(4)        r3;
   TLPDigest               digest;
   TLPPoison               poison;
   TLPAttrRelaxedOrdering  relaxed;
   TLPAttrNoSnoop          nosnoop;
   ReservedZero#(2)        r4;
   TLPLength               length;
   PciId                   reqid;
   TLPTag                  tag;
   TLPLastDWBE             lastbe;
   TLPFirstDWBE            firstbe;
   DWAddress               addr;
   ReservedZero#(2)        r7;
   Bit#(32)                data;
   } TLPMemoryIO3DWHeader deriving (Bits, Eq);

instance DefaultValue#(TLPMemoryIO3DWHeader);
   defaultValue =
   TLPMemoryIO3DWHeader {
      r1:      unpack(0),
      format:  MEM_WRITE_3DW_DATA,
      pkttype: MEMORY_READ_WRITE,
      r2:      unpack(0),
      tclass:  TRAFFIC_CLASS_0,
      r3:      unpack(0),
      digest:  NO_DIGEST_PRESENT,
      poison:  NOT_POISONED,
      relaxed: STRICT_ORDERING,
      nosnoop: NO_SNOOPING_REQD,
      r4:      unpack(0),
      length:  0,
      reqid:   defaultValue,
      tag:     0,
      lastbe:  0,
      firstbe: 0,
      addr:    0,
      r7:      unpack(0),
      data:    0
      };
endinstance

typedef struct {
   ReservedZero#(1)        r1;
   TLPPacketFormat         format;
   TLPPacketType           pkttype;
   ReservedZero#(1)        r2;
   TLPTrafficClass         tclass;
   ReservedZero#(4)        r3;
   TLPDigest               digest;
   TLPPoison               poison;
   TLPAttrRelaxedOrdering  relaxed;
   TLPAttrNoSnoop          nosnoop;
   ReservedZero#(2)        r4;
   TLPLength               length;
   PciId                   reqid;
   TLPTag                  tag;
   TLPLastDWBE             lastbe;
   TLPFirstDWBE            firstbe;
   DWAddress64             addr;
   ReservedZero#(2)        r7;
   } TLPMemory4DWHeader deriving (Bits, Eq);

instance DefaultValue#(TLPMemory4DWHeader);
   defaultValue =
   TLPMemory4DWHeader {
      r1:      unpack(0),
      format:  MEM_WRITE_4DW_DATA,
      pkttype: MEMORY_READ_WRITE,
      r2:      unpack(0),
      tclass:  TRAFFIC_CLASS_0,
      r3:      unpack(0),
      digest:  NO_DIGEST_PRESENT,
      poison:  NOT_POISONED,
      relaxed: STRICT_ORDERING,
      nosnoop: NO_SNOOPING_REQD,
      r4:      unpack(0),
      length:  0,
      reqid:   defaultValue,
      tag:     0,
      lastbe:  0,
      firstbe: 0,
      addr:    0,
      r7:      unpack(0)
      };
endinstance


typedef struct {
   ReservedZero#(1)        r1;
   TLPPacketFormat         format;
   TLPPacketType           pkttype;
   ReservedZero#(1)        r2;
   TLPTrafficClass         tclass;
   ReservedZero#(4)        r3;
   TLPDigest               digest;
   TLPPoison               poison;
   TLPAttrRelaxedOrdering  relaxed;
   TLPAttrNoSnoop          nosnoop;
   ReservedZero#(2)        r4;
   TLPLength               length;
   PciId                   cmplid;
   TLPCompletionStatus     cstatus;
   TLPByteCountModified    bcm;
   TLPByteCount            bytecount;
   PciId                   reqid;
   TLPTag                  tag;
   ReservedZero#(1)        r5;
   TLPLowerAddr            loweraddr;
   Bit#(32)                data;
   } TLPCompletionHeader deriving (Bits, Eq);

instance DefaultValue#(TLPCompletionHeader);
   defaultValue =
   TLPCompletionHeader {
      r1:        unpack(0),
      format:    MEM_WRITE_3DW_DATA,
      pkttype:   COMPLETION,
      r2:        unpack(0),
      tclass:    TRAFFIC_CLASS_0,
      r3:        unpack(0),
      digest:    NO_DIGEST_PRESENT,
      poison:    NOT_POISONED,
      relaxed:   STRICT_ORDERING,
      nosnoop:   NO_SNOOPING_REQD,
      r4:        unpack(0),
      length:    0,
      cmplid:    defaultValue,
      cstatus:   SUCCESSFUL_COMPLETION,
      bcm:       BYTE_COUNT_ORIGINAL,
      bytecount: 0,
      reqid:     defaultValue,
      tag:       0,
      r5:        unpack(0),
      loweraddr: 0,
      data:      0
      };
endinstance

typedef struct {
   ReservedZero#(1)        r1;
   TLPPacketFormat         format;
   TLPPacketType           pkttype;
   ReservedZero#(1)        r2;
   TLPTrafficClass         tclass;
   ReservedZero#(4)        r3;
   TLPDigest               digest;
   TLPPoison               poison;
   TLPAttrRelaxedOrdering  relaxed;
   TLPAttrNoSnoop          nosnoop;
   ReservedZero#(2)        r4;
   TLPLength               length;
   PciId                   reqid;
   TLPTag                  tag;
   TLPMessageCode          msgcode;
   DWAddress64             address;
   } TLPMSIHeader deriving (Bits, Eq);

instance DefaultValue#(TLPMSIHeader);
   defaultValue =
   TLPMSIHeader {
      r1:      unpack(0),
      format:  MEM_READ_4DW_NO_DATA,
      pkttype: MSG_ROUTED_TO_ROOT,
      r2:      unpack(0),
      tclass:  TRAFFIC_CLASS_0,
      r3:      unpack(0),
      digest:  NO_DIGEST_PRESENT,
      poison:  NOT_POISONED,
      relaxed: STRICT_ORDERING,
      nosnoop: SNOOPING_REQD,
      r4:      unpack(0),
      length:  0,
      reqid:   defaultValue,
      tag:     0,
      msgcode: tagged Unlock,
      address: 0
      };
endinstance

////////////////////////////////////////////////////////////////////////////////
/// Functions
////////////////////////////////////////////////////////////////////////////////
function PciId getReqID(BusNumber b, DevNumber d, FuncNumber f);
   return PciId { bus: b, dev: d, func: f };
endfunction

function TLPLowerAddr getLowerAddr(DWAddress addr, TLPFirstDWBE first);
   case(first)
      4'b1110: return { addr[4:0], 2'b01 };
      4'b1100: return { addr[4:0], 2'b10 };
      4'b1000: return { addr[4:0], 2'b11 };
      default: return { addr[4:0], 2'b00 };
   endcase
endfunction

// For read-request completions
function Bit#(12) computeByteCount(Bit#(10) length,
                                   Bit#(4) firstBE, Bit#(4) lastBE);
   function Bit#(2) missingBytesFirst(Bit#(4) be);
      case (be)
         4'b1111: return 2'b00;
         4'b1110: return 2'b01;
         4'b1100: return 2'b10;
         default: return 2'b11;
      endcase
   endfunction

   function Bit#(2) missingBytesLast(Bit#(4) be);
      case (be)
         4'b1111: return 2'b00;
         4'b0111: return 2'b01;
         4'b0011: return 2'b10;
         default: return 2'b11;
      endcase
   endfunction

   return ( {length, 2'b00}
            - zeroExtend(missingBytesFirst(firstBE))
            - ( length == 1 ? 0 : zeroExtend(missingBytesLast(lastBE)) ) );
endfunction

function Bit#(32) byteSwap(Bit#(32) w);
   Vector#(4, Bit#(8)) bytes = unpack(w);
   return pack(reverse(bytes));
endfunction

function Bit#(128) dwordSwap128(Bit#(128) w);
   Vector#(4, Bit#(32)) dwords = unpack(w);
   return pack(reverse(dwords));
endfunction

function Bit#(16) dwordSwap128BE(Bit#(16) w);
   Vector#(4, Bit#(4)) dwords = unpack(w);
   return pack(reverse(dwords));
endfunction

function Bit#(64) dwordSwap64(Bit#(64) w);
   Vector#(2, Bit#(32)) dwords = unpack(w);
   return pack(reverse(dwords));
endfunction

function Bit#(8) dwordSwap64BE(Bit#(8) w);
   Vector#(2, Bit#(4)) dwords = unpack(w);
   return pack(reverse(dwords));
endfunction

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
(* always_ready, always_enabled *)
interface PCIE_EXP#(numeric type lanes);
   method    Action      rxp(Bit#(lanes) i);
   method    Action      rxn(Bit#(lanes) i);
   method    Bit#(lanes) txp;
   method    Bit#(lanes) txn;
endinterface: PCIE_EXP

////////////////////////////////////////////////////////////////////////////////
/// Connection Instances
////////////////////////////////////////////////////////////////////////////////

// Conversions between TLPData#(8) and TLPData#(16)

instance Connectable#(Put#(TLPData#(16)), Get#(TLPData#(8)));
   module mkConnection#(Put#(TLPData#(16)) p, Get#(TLPData#(8)) g)(Empty);
      Reg#(Maybe#(TLPData#(8))) rg <- mkReg(Invalid);
      rule upconv_connect1 (rg matches tagged Invalid);
         let w1 <- g.get;
         if (!w1.eof)
            rg <= Valid(w1);
         else begin
            let wOut = TLPData {
                          sof  : w1.sof,
                          eof  : w1.eof,  // True
                          hit  : w1.hit,
                          be   : {w1.be, 0},
                          data : {w1.data, ?}
                       };
            p.put(wOut);
         end
      endrule
      rule upconv_connect2 (rg matches tagged Valid .w1);
         let w2 <- g.get;
         let wOut = TLPData {
                       sof  : w1.sof,
                       eof  : w2.eof,
                       hit  : w1.hit,
                       be   : {w1.be, w2.be},
                       data : {w1.data, w2.data}
                    };
         p.put(wOut);
         rg <= Invalid;
      endrule
   endmodule
endinstance

instance Connectable#(Get#(TLPData#(8)), Put#(TLPData#(16)));
   module mkConnection#(Get#(TLPData#(8)) g, Put#(TLPData#(16)) p)(Empty);
      mkConnection(p, g);
   endmodule
endinstance

instance Connectable#(Get#(TLPData#(16)), Put#(TLPData#(8)));
   module mkConnection#(Get#(TLPData#(16)) g, Put#(TLPData#(8)) p)(Empty);
      // We need this state because the Get interface does not allow us to
      // look at the data without also popping it from the queue.
      // If we need to save these bits, then consider using a different ifc.
      Reg#(Maybe#(TLPData#(8))) rg <- mkReg(Invalid);
      rule downconv_connect1 (rg matches tagged Invalid);
         let wIn <- g.get;
         // the 16-byte packet will fit in 8-bytes
         if (wIn.be[7:0] == 0) begin  // XXX "&& wIn.eof" ?
            TLPData#(8) w1 =
               TLPData {
                  sof  : wIn.sof,
                  eof  : wIn.eof, // True
                  hit  : wIn.hit,
                  be   : wIn.be[15:8],
                  data : wIn.data[127:64]
               };
            p.put(w1);
         end
         // we need to send two 8-byte packets
         else begin
            TLPData#(8) w1 =
               TLPData {
                  sof  : wIn.sof,
                  eof  : False,
                  hit  : wIn.hit,
                  be   : wIn.be[15:8],
                  data : wIn.data[127:64]
               };
            TLPData#(8) w2 =
               TLPData {
                  sof  : False,
                  eof  : wIn.eof,
                  hit  : wIn.hit,
                  be   : wIn.be[7:0],
                  data : wIn.data[63:0]
               };
            rg <= Valid(w2);
            p.put(w1);
         end
      endrule
      rule downconv_connect2 (rg matches tagged Valid .w2);
         rg <= Invalid;
         p.put(w2);
      endrule
   endmodule
endinstance

instance Connectable#(Put#(TLPData#(8)), Get#(TLPData#(16)));
   module mkConnection#(Put#(TLPData#(8)) p, Get#(TLPData#(16)) g)(Empty);
      mkConnection(g, p);
   endmodule
endinstance

////////////////////////////////////////////////////////////////////////////////
/// Typeclass Definition
////////////////////////////////////////////////////////////////////////////////
typeclass ConnectableWithClocks#(type a, type b);
   module mkConnectionWithClocks#(a x1, b x2, Clock fastClock, Reset fastReset, Clock slowClock, Reset slowReset)(Empty);
endtypeclass

endpackage: PCIE

