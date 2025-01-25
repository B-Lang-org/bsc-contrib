import FIFOF ::*;
import VectorFIFOF ::*;

(* synthesize *)
module mkVectorFIFOF_4_Bool(VectorFIFOF#(4,Bool));
  (* hide *)
  VectorFIFOF#(4,Bool) __i <- mkVectorFIFOF;
  return __i;
endmodule
