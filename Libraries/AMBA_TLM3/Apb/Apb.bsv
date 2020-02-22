////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : APB.bsv
//  Description   : APB4 Bus Defintion
////////////////////////////////////////////////////////////////////////////////
package Apb;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import ApbDefines        ::*;
//import ApbMasterAxi      ::*;
import ApbMaster         ::*;
import ApbSlave          ::*;
import ApbBus            ::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////
export ApbDefines        ::*;
//export ApbMasterAxi      ::*;
export ApbMaster         ::*;
export ApbSlave          ::*;
export ApbBus            ::*;

endpackage: Apb

