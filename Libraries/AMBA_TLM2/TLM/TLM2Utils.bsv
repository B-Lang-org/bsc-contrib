// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package TLM2Utils;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import BUtils::*;
import DefaultValue::*;
import TLM2Defines::*;
import Vector::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

function RequestDescriptor#(`TLM_PRM) createBasicRequestDescriptor()
   provisos(DefaultValue#(RequestDescriptor#(`TLM_PRM)));
   return defaultValue;
endfunction

/* -----\/----- EXCLUDED -----\/-----
function TLMResponse#(`TLM_PRM) createTLMResponse(TLMId#(`TLM_PRM) id, TLMStatus status)
   provisos(Bits#(TLMResponse#(`TLM_PRM), s0));
   TLMResponse#(`TLM_PRM) response = unpack(0);
   response.status = status;
   response.transaction_id = id;
   return response;
endfunction
 -----/\----- EXCLUDED -----/\----- */

function TLMResponse#(`TLM_PRM) createBasicTLMResponse ()
   provisos(DefaultValue#(TLMResponse#(`TLM_PRM)));
   return defaultValue;
endfunction

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////


function TLMData#(`TLM_PRM) createTLMBitMask (TLMByteEn#(`TLM_PRM) enable_bits);


   Vector#(TDiv#(data_size, 8),Bit#(1)) enable = unpack(enable_bits);
   Vector#(TDiv#(data_size, 8),Bit#(8)) mask   = map(signExtend, enable);

   return cExtend(mask);

endfunction

function TLMData#(`TLM_PRM) maskTLMData(TLMByteEn#(`TLM_PRM) byte_enable, TLMData#(`TLM_PRM) data);

   TLMData#(`TLM_PRM) mask = createTLMBitMask(byte_enable);

   return mask & data;

endfunction

function TLMData#(`TLM_PRM) overwriteTLMData(TLMByteEn#(`TLM_PRM) byte_enable, TLMData#(`TLM_PRM) data_orig, TLMData#(`TLM_PRM) data);

   TLMData#(`TLM_PRM) mask = createTLMBitMask(byte_enable);

   return (~mask & data_orig) | (mask & data);

endfunction

endpackage
