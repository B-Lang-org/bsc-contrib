////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
// With modifications by Colin Rothwell, University of Cambridge
//
// SPDX-License-Identifier: BSD-3-Clause
//
////////////////////////////////////////////////////////////////////////////////
//  Filename      : NonPipelinedMath.bsv
//  Description   : Non-pipelined versions of modules in the Math library,
//                  which can also be used with the FloatingPoint library.
////////////////////////////////////////////////////////////////////////////////

package NonPipelinedMath;

import ClientServer ::*;
import FIFO ::*;
import FIFOF ::*;
import GetPut ::*;
import StmtFSM ::*;
import Vector ::*;

export mkNonPipelinedDivider;
export mkNonPipelinedSignedDivider;
export mkNonPipelinedSquareRooter;

// non-restoring divider
// n+3 cycle latency
module mkNonPipelinedDivider
        #(Integer s)
        (Server#(Tuple2#(UInt#(m),UInt#(n)),
                 Tuple2#(UInt#(n),UInt#(n))))
   provisos(
      Mul#(2, n, m),
      // per request of bsc
      Add#(b__, n, m),
      Add#(1, m, TAdd#(n, a__))
      );

   FIFO#(Tuple2#(UInt#(m),UInt#(n))) fRequest <- mkLFIFO;
   FIFO#(Tuple2#(UInt#(n),UInt#(n))) fResponse <- mkLFIFO;

   Reg#(Tuple3#(Int#(TAdd#(1,n)),Int#(TAdd#(1,n)),Int#(TAdd#(2,m)))) fReg <- mkRegU;
   Reg#(Bool) busy <- mkReg(False);
   Reg#(UInt#(n)) count <- mkReg(0);

   function zeroExtendLSB(d) =
     unpack(reverseBits(extend(reverseBits(pack(d)))));

   rule start (!busy);
      match {.n_, .d_} <- toGet(fRequest).get();
      Int#(TAdd#(1,n)) d = unpack(extend(pack(d_)));
      Int#(TAdd#(2,m)) r = unpack(extend(pack(n_)));
      Int#(TAdd#(1,n)) q = 0;
      fReg <= (tuple3(d,q,r));
      busy <= True;
   endrule

   let done = (count >= fromInteger(valueOf(n) / s + 1));

   rule work (busy && !done);
     Int#(TAdd#(1,n)) d = tpl_1(fReg);
     Int#(TAdd#(1,n)) q = tpl_2(fReg);
     Int#(TAdd#(2,m)) r = tpl_3(fReg);
     Int#(TAdd#(2,m)) bigd = zeroExtendLSB(d);

     for (Integer j = 0; j < s; j = j + 1) begin
         // XXX: Possible overflow?
        if ((count + fromInteger(j)) <= fromInteger(valueOf(n))) begin
           if (r >= 0) begin
               q = (q << 1) | 1;
               r = (r << 1) - bigd;
           end
           else begin
               q = (q << 1);
               r = (r << 1) + bigd;
           end
        end
     end

     fReg <= tuple3(d,q,r);

     count <= count + 1;
   endrule

   rule finish (busy && done);
      match {.d, .q, .r} = fReg;

      q = q + (-(~q));
      if (r < 0) begin
          q = q - 1;
          r = r + zeroExtendLSB(d);
      end
      UInt#(TAdd#(1,n)) qq = unpack(pack(q));
      UInt#(TAdd#(1,n)) rr = unpack(truncateLSB(pack(r)));
      fResponse.enq(tuple2(truncate(qq),truncate(rr)));
      busy <= False;
      count <= 0;
   endrule

   interface request = toPut(fRequest);
   interface response = toGet(fResponse);

endmodule

module mkNonPipelinedSignedDivider#(Integer s)(Server#(Tuple2#(Int#(m),Int#(n)),Tuple2#(Int#(n),Int#(n))))
   provisos(
      Mul#(2, n, m),
      // per request of bsc
      Add#(a__, n, m),
      Add#(1, m, TAdd#(n, b__))
      );

   FIFO#(Tuple2#(Int#(m),Int#(n))) fRequest <- mkLFIFO;
   FIFO#(Tuple2#(Int#(n),Int#(n))) fResponse <- mkLFIFO;

   Server#(Tuple2#(UInt#(m),UInt#(n)),Tuple2#(UInt#(n),UInt#(n))) div <- mkNonPipelinedDivider(s);
   FIFO#(Tuple2#(Bool,Bool)) fSign <- mkLFIFO;

   rule start;
      match {.a, .b} <- toGet(fRequest).get;

      UInt#(m) au = unpack(pack(abs(a)));
      UInt#(n) bu = unpack(pack(abs(b)));
      Bool asign = (signum(a) != extend(signum(b)));
      Bool bsign = (signum(a) == -1);

      div.request.put(tuple2(au,bu));
      fSign.enq(tuple2(asign,bsign));
   endrule

   rule finish;
      match {.au, .bu} <- div.response.get;
      match {.asign, .bsign} <- toGet(fSign).get;

      Int#(n) a = unpack(pack(au));
      Int#(n) b = unpack(pack(bu));

      a = asign ? -a : a;
      b = bsign ? -b : b;

      fResponse.enq(tuple2(a,b));
   endrule

   interface request = toPut(fRequest);
   interface response = toGet(fResponse);

endmodule

module mkNonPipelinedSquareRooter#(Integer n)(Server#(UInt#(m),Tuple2#(UInt#(m),Bool)))
   provisos(
      // per request of bsc
      Add#(a__, 2, m),
      Log#(TAdd#(1, m), TLog#(TAdd#(m, 1)))
      );

   FIFO#(UInt#(m)) fRequest <- mkLFIFO;
   FIFO#(Tuple2#(UInt#(m),Bool)) fResponse <- mkLFIFO;

   FIFO#(Tuple4#(Maybe#(Bit#(m)),Bit#(m),Bit#(m),Bit#(m))) fFirst <- mkLFIFO;

   Reg#(Bool) busy <- mkReg(False);
   // This is an overestimate of size: can't divide by n
   Reg#(UInt#(TLog#(TAdd#(TDiv#(m, 2), 1)))) count <- mkReg(?);
   Reg#(Tuple4#(Maybe#(Bit#(m)),Bit#(m),Bit#(m),Bit#(m))) workspace <- mkReg(?);

   rule start (!busy);
      let op <- toGet(fRequest).get;
      let s = pack(op);
      Bit#(m) r = 0;
      Bit#(m) b = reverseBits(extend(2'b10));

      let s0 = countZerosMSB(s);
      let b0 = countZerosMSB(b);
      if (s0 > 0) begin
         let shift = (s0 - b0);
         if ((shift & 1) == 1)
            shift = shift + 1;
         b = b >> shift;
      end

      workspace <= tuple4(tagged Invalid,s,r,b);
      busy <= True;
      count <= 0;
   endrule

   let running = (count < fromInteger((valueOf(m) / 2) / n + 1));

   rule work (busy && running);
     count <= count + 1;
     Maybe#(Bit#(m)) res = tpl_1(workspace);
     Bit#(m) s = tpl_2(workspace);
     Bit#(m) r = tpl_3(workspace);
     Bit#(m) b = tpl_4(workspace);

     for (Integer j = 0; j < n; j = j + 1) begin
        if ((count + fromInteger(j)) <= (fromInteger(valueOf(m)/2))) begin
           if (res matches tagged Invalid) begin
              if (b == 0) begin
                 res = tagged Valid r;
              end
              else begin
                 let sum = r + b;

                 if (s >= sum) begin
                    s = s - sum;
                    r = (r >> 1) + b;
                 end
                 else begin
                    r = r >> 1;
                 end

                 b = b >> 2;
              end
           end
        end
     end

     workspace <= tuple4(res,s,r,b);
  endrule

   rule finish (busy && !running);
      match {.res, .s, .r, .b} = workspace;

      fResponse.enq(tuple2(unpack(fromMaybe(0,res)),(s != 0)));
      busy <= False;
   endrule

   interface request = toPut(fRequest);
   interface response = toGet(fResponse);

endmodule

endpackage
