// Copyright (c) 2020 Bluespec, Inc. All rights reserved.
//
// SPDX-License-Identifier: BSD-3-Clause

package AxiPC;

import AxiDefines::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

interface AxiPC_Ifc#(`TLM_PRM_DCL);
   method Action   aw_id     (AxiId#(`TLM_PRM) value);
   method Action   aw_len    (AxiLen aw_len);
   method Action   aw_size   (AxiSize value);
   method Action   aw_burst  (AxiBurst value);
   method Action   aw_lock   (AxiLock value);
   method Action   aw_cache  (AxiCache value);
   method Action   aw_prot   (AxiProt value);
   method Action   aw_addr   (AxiAddr#(`TLM_PRM) value);
   method Action   aw_valid  (Bool value);
   method Action   aw_ready  (Bool value);

   method Action   w_id      (AxiId#(`TLM_PRM) value);
   method Action   w_data    (AxiData#(`TLM_PRM) value);
   method Action   w_strb    (AxiByteEn#(`TLM_PRM) value);
   method Action   w_last    (Bool value);
   method Action   w_valid   (Bool value);
   method Action   w_ready   (Bool value);

   method Action   b_id      (AxiId#(`TLM_PRM) value);
   method Action   b_resp    (AxiResp value);
   method Action   b_valid   (Bool value);
   method Action   b_ready   (Bool value);

   method Action   ar_id     (AxiId#(`TLM_PRM) value);
   method Action   ar_len    (AxiLen value);
   method Action   ar_size   (AxiSize value);
   method Action   ar_burst  (AxiBurst value);
   method Action   ar_lock   (AxiLock value);
   method Action   ar_cache  (AxiCache value);
   method Action   ar_prot   (AxiProt value);
   method Action   ar_addr   (AxiAddr#(`TLM_PRM) value);
   method Action   ar_valid  (Bool value);
   method Action   ar_ready  (Bool value);

   method Action   r_id      (AxiId#(`TLM_PRM) value);
   method Action   r_data    (AxiData#(`TLM_PRM) value);
   method Action   r_resp    (AxiResp value);
   method Action   r_last    (Bool value);
   method Action   r_valid   (Bool value);
   method Action   r_ready   (Bool value);
endinterface


////////////////////////////////////////////////////////////////////////////////
///
////////////////////////////////////////////////////////////////////////////////

import "BVI" AxiPC =
module mkAxiPC (AxiPC_Ifc#(`TLM_PRM));

   parameter ID_WIDTH   = valueOf(id_size);
   parameter DATA_WIDTH = valueOf(data_size);

   default_clock clk( ACLK);
   default_reset rst(ARESETn);
   method    aw_id     (AWID   )enable((*inhigh*)IGNORE00);
   method    aw_len    (AWLEN  )enable((*inhigh*)IGNORE01);
   method    aw_size   (AWSIZE )enable((*inhigh*)IGNORE02);
   method    aw_burst  (AWBURST)enable((*inhigh*)IGNORE03);
   method    aw_lock   (AWLOCK )enable((*inhigh*)IGNORE04);
   method    aw_cache  (AWCACHE)enable((*inhigh*)IGNORE05);
   method    aw_prot   (AWPROT )enable((*inhigh*)IGNORE06);
   method    aw_addr   (AWADDR )enable((*inhigh*)IGNORE07);
   method    aw_valid  (AWVALID)enable((*inhigh*)IGNORE08);
   method    aw_ready  (AWREADY)enable((*inhigh*)IGNORE09);
   method    w_id      (WID    )enable((*inhigh*)IGNORE10);
   method    w_data    (WDATA  )enable((*inhigh*)IGNORE11);
   method    w_strb    (WSTRB  )enable((*inhigh*)IGNORE12);
   method    w_last    (WLAST  )enable((*inhigh*)IGNORE13);
   method    w_valid   (WVALID )enable((*inhigh*)IGNORE14);
   method    w_ready   (WREADY )enable((*inhigh*)IGNORE15);

   method    b_id      (BID    )enable((*inhigh*)IGNORE16);
   method    b_resp    (BRESP  )enable((*inhigh*)IGNORE17);
   method    b_valid   (BVALID )enable((*inhigh*)IGNORE18);
   method    b_ready   (BREADY )enable((*inhigh*)IGNORE19);

   method    ar_id     (ARID   )enable((*inhigh*)IGNORE20);
   method    ar_len    (ARLEN  )enable((*inhigh*)IGNORE21);
   method    ar_size   (ARSIZE )enable((*inhigh*)IGNORE22);
   method    ar_burst  (ARBURST)enable((*inhigh*)IGNORE24);
   method    ar_lock   (ARLOCK )enable((*inhigh*)IGNORE25);
   method    ar_cache  (ARCACHE)enable((*inhigh*)IGNORE26);
   method    ar_prot   (ARPROT )enable((*inhigh*)IGNORE27);
   method    ar_addr   (ARADDR )enable((*inhigh*)IGNORE28);
   method    ar_valid  (ARVALID)enable((*inhigh*)IGNORE29);
   method    ar_ready  (ARREADY)enable((*inhigh*)IGNORE30);

   method    r_id      (RID    )enable((*inhigh*)IGNORE31);
   method    r_data    (RDATA  )enable((*inhigh*)IGNORE32);
   method    r_resp    (RRESP  )enable((*inhigh*)IGNORE33);
   method    r_last    (RLAST  )enable((*inhigh*)IGNORE34);
   method    r_valid   (RVALID )enable((*inhigh*)IGNORE35);
   method    r_ready   (RREADY )enable((*inhigh*)IGNORE36);

   schedule (aw_len,aw_id,aw_size,aw_burst,aw_lock,aw_cache,aw_prot,aw_addr,aw_valid , aw_ready, w_id , w_data , w_strb, w_last , w_valid , w_ready, b_id , b_resp, b_valid, b_ready, ar_id , ar_len , ar_size , ar_burst, ar_lock, ar_cache, ar_prot, ar_addr , ar_valid, ar_ready , r_id  , r_data, r_resp, r_last, r_valid , r_ready) CF  (aw_len,aw_id,aw_size,aw_burst,aw_lock,aw_cache,aw_prot,aw_addr,aw_valid , aw_ready, w_id , w_data , w_strb, w_last , w_valid , w_ready, b_id , b_resp, b_valid, b_ready, ar_id , ar_len , ar_size , ar_burst, ar_lock, ar_cache, ar_prot, ar_addr , ar_valid, ar_ready , r_id  , r_data, r_resp, r_last, r_valid , r_ready);

endmodule

endpackage



