// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AhbAddressRangeMatch;
import Ahb::*;

`include "TLM.defines"

//This is the same function as AhbDefinesSupport::addAddrMatch
//but isolated from the rest of the file, which currently does
//not compile

//This also avoids the name collision with APB/APBDefines.bsv::addAddrMatch
function AhbXtorSlaveWM#(`TLM_PRM) ahbAddAddrMatch(function Bool addr_match(AhbAddr#(`TLM_PRM) addr),
                                                AhbXtorSlave#(`TLM_PRM) ifc);
   let ifc_wm = (interface AhbXtorSlaveWM;
                    interface AhbSlave         bus      = ifc.bus;
                    interface AhbSlaveSelector selector = ifc.selector;
                    method addrMatch = addr_match;
                 endinterface);

   return ifc_wm;
endfunction

endpackage
