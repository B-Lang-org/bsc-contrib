PWD:=$(shell pwd)
TOP:=$(PWD)/../..

LIBNAME=GenCMsg

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
	rm -rf model_*.* mk*.* *.o *.bo *.ba *.out *.so test.* test calculator.* calculator counter.* counter

.PHONY: test
test: build
	rm -rf $(BUILDDIR)/mkTest.ba
	$(BSC) -u $(BSCFLAGS) -sim Test.bs
	$(CC) test.c -c -g
	$(CC) test_fn.c -c -g
	$(BSC) -u $(BSCFLAGS) -sim -e mkTest -o test.out test.o test_fn.o
	./test.out

.PHONY: demo
demo: build
	rm -rf $(BUILDDIR)/mkCalculator.ba
	$(BSC) -u $(BSCFLAGS) -sim Calculator.bs
	$(CC) calculator.c -c -g
	$(CC) calculator_driver.c -c -g
	$(BSC) -u $(BSCFLAGS) -sim -e mkCalculator -o calculator.out calculator.o calculator_driver.o
	./calculator.out

.PHONY: msgdemo
msgdemo: build
	rm -rf $(BUILDDIR)/mkCounter.ba
	$(BSC) -u $(BSCFLAGS) -sim Counter.bs
	$(CC) counter.c -c -g
	$(CC) counter_driver.c -c -g
	$(BSC) -u $(BSCFLAGS) -sim -e mkCounter -o counter.out counter.o counter_driver.o
	./counter.out

.PHONY: msgdemo
b2bmsgdemo: build
	rm -rf $(BUILDDIR)/mkCounterB2B.ba
	$(BSC) -u $(BSCFLAGS) -sim CounterB2B.bs
	$(BSC) -u $(BSCFLAGS) -sim -e mkCounterB2B -o counterb2b.out
	./counterb2b.out

all: build test demo msgdemo
