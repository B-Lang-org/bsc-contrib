Copyright (c) 2017-2024 Bluespec, Inc.  All Rights Reserved

SPDX-License-Identifier: BSD-3-Clause

This directory contains B-Lang libraries for various AMBA resources
(AXI4, AXI4-Lite, AXI4_Stream) including type definitions, cross-bar
switches, connectors, clock-crossers, transactors to convert from
BSV-internal connection idioms (FIFOs) to AMBA connection signalling,
etc.

The source code is written in Bluespec BSV.  The `bsc` compiler tool
can be used to generate synthesizable Verilog.

Some of these components have been used in numerous RISC-V CPUs and
SoC designs at Bluespec, Inc.

CAUTION: When using resources from this library, please examine the
         source code and check that it is fit for your purpose.

         The components here were added piecemeal, in an _ad hoc_ way,
         over a number of years, each component serving some specific
         immediate, narrow need.  The whole library could do with a
         ground-up rewrite, including filling in many obvious missing
         components.

CAUTION: In these resources, where bursts are supported, it generally
         assumes INCR (incrementing) bursts, not FIXED or WRAP.

// ================================================================
Terminology:

Since 2021 ARM has replaced the terms "Master" and "Slave" by
"Manager" and "Subordinate", respectively; in this library we adopt
this convention.  Identifiers and file names use the abbreviated `M`
and `S`.

In this library, identifiers use `AXI4` for AXI4 itsef and `AXI4L` for
AXI4-Lite.

// ================================================================
The source tree for this library is:

    bsc-contrib_RSN/
    ├── Libraries
    │   ├── AMBA_Fabrics
    │   │   ├── AXI4
    │   │   ├── AXI4_Lite
    │   │   ├── AXI4_Stream
    │   │   ├── Adapters
    │   │   └── Utils
    ...
    └── testing
        └── bsc.contrib
            ├── AMBA_Fabrics_AXI4
            ├── AMBA_Fabrics_AXI4_Lite
            ...

What follows is a quick tour.

// ----------------
AXI4_Lite/

    All these have a 'user' field which is not standard in AXI4-Lite
    (same as 'user' in AXI4), which can be left unused, and/or set to
    width 0.

    AXI4_Lite_Types.bsv

        Definitions for AXI4_Lite bus types, M and S interfaces,
        connections between Ms and Ss, dummy M and S tie-offs, and
        transactors to provide higher-level FIFO-like interfaces to
        drive Ms and Ss.

        Everything is parameterizd on width of address, data and user buses.

        Note: some aspects of these definitions may seem a bit verbose
        and messy; that is not typical of BSV code, but is true here
        because it is meant to interface to hand-written Verilog, so
        we need to provide precise control on interface signal names
        and protocols that are required by the Verilog side.  Pure BSV
        code can be an order of magnitude more compact.

        Everything is parameterized on wd_addr, wd_data, wd_user.

AXI4_Lite_Fabric.bsv

        Definition for interface and module for an num_M x num_S
        crossbar switch with AXI4-Lite interfaces.

        This is also an example of how, within BSV code, we don't
        worry about the details of AXI4-Lite signalling. We just
        instantiate the transactors defined in AXI4_Lite_Types.bsv,
        and then work only with simple, FIFO-like interfaces.

        Everything is parameterized on num_M, num_S, wd_addr, wd_data,
        wd_user.

... clock-crossers, other transactors ...

// ----------------
AXI4/

AXI4_Types.bsv

Definitions for AXI4 bus types, M and S interfaces, connections
between Ms and Ss, dummy M and S tie-offs, and transactors to provide
higher-level FIFO-like interfaces to drive Ms and Ss.

Everything is parameterized on wd_id, wd_addr, wd_data, wd_user.

Note: some aspects of these definitions may seem a bit verbose and
messy; that is not typical of BSV code, but is true here because it is
meant to interface to hand-written Verilog, so we need to provide
precise control on interface signal names and protocols that are
required by the Verilog side.  Pure BSV code can be an order of
magnitude more compact.

AXI4_Fabric.bsv

Definition for interface and module for an num_M x num_S crossbar
switch with AXI4 interfaces.

This is also an example of how, within BSV code, we don't worry about
the details of AXI4-Lite signalling. We just instantiate the
transactors defined in AXI4_Lite_Types.bsv, and then work only with
simple, FIFO-like interfaces.

Everything is parameterized on num_M, num_S, wd_id, wd_addr, wd_data,
wd_user.

AXI4_Deburster.bsv

A module that converts a slave that does not support AXI4 bursts into
a slave that does support bursts.

... clock-crossers, other transactors

// ----------------
Adapters/

AXI4L_S_to_AXI4_M_Adapter.bsv

A module to bridge from an AXI4L S to an AXI4 M.

AXI4_AXI4_Lite_Adapters.bsv

// ================================================================
Dependencies

Some of these source codes import BSV resources in a sibling directory

    bsc-contrib/Libraries/Misc/

// ================================================================
Build-and-install

Compiling, Building and Testing

These are libraries, so you will normally be compiling selected files
from here within some other project that uses these libraries.

In `AXI4/Unit_Test/` and `AXI4_Lite/Unit_Test/` the source codes and
Makefiles show examples of instantiating fabrics in testbenches and
executing them.

The Makefiles are set up to build both Bluesim and Verilator
executables.  In each case, the Makefile specifies two steps:
compiling BSV source, and then linking into an executable.

In the Verilator case, the compile step generates Verilog from BSV
source.  This Verilog can be used as Verilog AMBA IP in other Verilog
or SystemVerilog projects.

// ================================================================
