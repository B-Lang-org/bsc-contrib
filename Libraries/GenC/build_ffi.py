#!/usr/bin/env python3

from cffi import FFI
import sys

def buildFFI(module):
    ffibuilder = FFI()
    ffibuilder.cdef("\n".join(line for line in open(module + ".h") if not line.startswith('#')))
    ffibuilder.set_source("_" + module, '#include "{}.h"'.format(module), sources=[module + ".c"])
    ffibuilder.compile(verbose=True)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Expected module name")
    buildFFI(sys.argv[1])
