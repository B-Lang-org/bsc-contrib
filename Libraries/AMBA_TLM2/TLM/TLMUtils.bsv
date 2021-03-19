// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package TLMUtils;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import TLMDefines::*;
import Vector::*;
import BUtils::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

function RequestDescriptor#(`TLM_TYPES) createBasicRequestDescriptor()
   provisos(Bits#(RequestDescriptor#(`TLM_TYPES), s0));
   RequestDescriptor#(`TLM_TYPES) request = unpack(0);
   request.command = READ;
   request.transaction_id = 0;
   request.burst_length = 1;
   request.burst_size = 3; // assume 32 bits for now.
   request.burst_mode = INCR;
   request.byte_enable = '1;
   return request;
endfunction

/* -----\/----- EXCLUDED -----\/-----
function TLMResponse#(`TLM_TYPES) createTLMResponse(TLMId#(`TLM_TYPES) id, TLMStatus status)
   provisos(Bits#(TLMResponse#(`TLM_TYPES), s0));
   TLMResponse#(`TLM_TYPES) response = unpack(0);
   response.status = status;
   response.transaction_id = id;
   return response;
endfunction
 -----/\----- EXCLUDED -----/\----- */

function TLMResponse#(`TLM_TYPES) createBasicTLMResponse()
   provisos(Bits#(TLMResponse#(`TLM_TYPES), s0));
   TLMResponse#(`TLM_TYPES) response = unpack(0);
   return response;
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////


function TLMData#(`TLM_TYPES) createTLMBitMask (TLMByteEn#(`TLM_TYPES) enable_bits);


   Vector#(TDiv#(data_size, 8),Bit#(1)) enable = unpack(enable_bits);
   Vector#(TDiv#(data_size, 8),Bit#(8)) mask   = map(signExtend, enable);

   return cExtend(mask);

endfunction

function TLMData#(`TLM_TYPES) maskTLMData(TLMByteEn#(`TLM_TYPES) byte_enable, TLMData#(`TLM_TYPES) data);

   TLMData#(`TLM_TYPES) mask = createTLMBitMask(byte_enable);

   return mask & data;

endfunction

function TLMData#(`TLM_TYPES) overwriteTLMData(TLMByteEn#(`TLM_TYPES) byte_enable, TLMData#(`TLM_TYPES) data_orig, TLMData#(`TLM_TYPES) data);

   TLMData#(`TLM_TYPES) mask = createTLMBitMask(byte_enable);

   return (~mask & data_orig) | (mask & data);

endfunction

endpackage
