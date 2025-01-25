import Cur_Cycle ::*;
import FIFOF ::*;
import VectorFIFOF ::*;

(* synthesize *)
module sysTest_VectorFIFOF();
  VectorFIFOF#(3,Bit#(4)) vf <- mkVectorFIFOF;

  Reg#(Bit#(4)) rg_send <- mkReg(0);

  rule do_enq (rg_send < 8);
    vf.fifo.enq(rg_send);
    rg_send <= rg_send + 1;
    $display("[%d] Contents: ", cur_cycle, fshow(vf.vector));
    $display("[%d] Enq %d", cur_cycle, rg_send);
  endrule

  Reg#(Bit#(4)) rg_recv <- mkReg(0);

  rule do_deq;
    vf.fifo.deq();
    $display("[%d] Deq %d", cur_cycle, vf.fifo.first);
    rg_recv <= rg_recv + 1;
    if (rg_recv == 7)
      $finish(0);
  endrule

endmodule
