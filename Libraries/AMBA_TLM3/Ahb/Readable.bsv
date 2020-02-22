// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package Readable;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import Vector::*;

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

typeclass Readable#(type a, type b);
   function a read(b value);
endtypeclass

instance Readable#(a, Reg#(a));
   function a read(Reg#(a) ifc);
      return ifc._read;
   endfunction
endinstance

instance Readable#(Bool, PulseWire);
   function Bool read(PulseWire ifc);
      return ifc._read;
   endfunction
endinstance

instance Readable#(a, ReadOnly#(a));
   function a read(ReadOnly#(a) ifc);
      return ifc._read;
   endfunction
endinstance

instance Readable#(Vector#(n, a), Vector#(n, b))
   provisos(Readable#(a,b));
   function Vector#(n, a) read(Vector#(n, b) value);
      return map(read,value);
   endfunction
endinstance

typeclass Writable#(type a, type b);
   function Action write(b ifc, a value);
endtypeclass

instance Writable#(a, Reg#(a));
   function Action write(Reg#(a) ifc, a value);
      action
	 ifc <= value;
      endaction
   endfunction
endinstance

instance Writable#(Vector#(n, a), Vector#(n, b))
   provisos(Writable#(a,b));
   function Action write(Vector#(n, b) ifc, Vector#(n, a) value);
      action
	 joinActions(zipWith(write, ifc, value));
      endaction
   endfunction
endinstance

endpackage
