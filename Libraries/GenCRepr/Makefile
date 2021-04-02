PWD:=$(shell pwd)
TOP:=$(PWD)/../..

LIBNAME=GenCRepr

# Requires that TOP and LIBNAME be set
# Sets BUILDDIR, and BSC and BSCFLAGS if not set
# and defines the install target
include ../common.mk

.PHONY: build
build:
	$(BSC) -u $(BSCFLAGS) $(notdir $(LIBNAME)).bs

.PHONY: clean full_clean
clean full_clean:

clean:
	rm -rf test.c test.h

.PHONY: test
test: build
	rm -rf $(BUILDDIR)/mkTest.ba
	$(BSC) -u $(BSCFLAGS) -sim TestFn.bsv
	$(BSC) -u $(BSCFLAGS) -sim Test.bs
	$(CC) test.c -c -g
	$(CC) test_fn.c -c -g
	$(BSC) -u $(BSCFLAGS) -sim -e mkTest -o test test.o test_fn.o
	./test
