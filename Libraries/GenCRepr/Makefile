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
	$(BSC) -u $(BSCFLAGS) $(notdir GenCMsg).bs

.PHONY: clean full_clean
clean full_clean:

clean:
	rm -rf model_*.* mk*.* *.o *.out *.so test.* test calculator.* calculator

.PHONY: test
test: build
	rm -rf $(BUILDDIR)/mkTest.ba
	$(BSC) -u $(BSCFLAGS) -sim TestFn.bsv
	$(BSC) -u $(BSCFLAGS) -sim Test.bs
	$(CC) test.c -c -g
	$(CC) test_fn.c -c -g
	$(BSC) -u $(BSCFLAGS) -sim -e mkTest -o test.out test.o test_fn.o
	./test.out

.PHONY: demo
demo: build
	rm -rf $(BUILDDIR)/mkCalculator.ba
	$(BSC) -u $(BSCFLAGS) -sim CalculatorIface.bsv
	$(BSC) -u $(BSCFLAGS) -sim Calculator.bs
	$(CC) calculator.c -c -g
	$(CC) calculator_driver.c -c -g
	$(BSC) -u $(BSCFLAGS) -sim -e mkCalculator -o calculator.out calculator.o calculator_driver.o
	./calculator.out
