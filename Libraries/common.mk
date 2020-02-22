#  Requires that TOP and LIBNAME be set

PREFIX?=$(TOP)/inst

# Where files are ultimately installed
INSTALLDIR=$(PREFIX)/lib/Libraries/$(LIBNAME)

# Where files are built
BUILDDIR=$(abspath $(TOP)/build/bsvlib/$(LIBNAME))

# Put the generated object files in BUILDDIR
BSCFLAGS_EXT += -bdir $(BUILDDIR)
# Increase the RTS stack
#BSCFLAGS_EXT += +RTS -K32M -RTS

BSCFLAGS ?= $(BSCFLAGS_EXT)

BSC ?= bsc

.PHONY: all
all: install

.PHONY: install
install: build
	install -d $(INSTALLDIR)
	install -m644 $(BUILDDIR)/* $(INSTALLDIR)

.PHONY: build
build: $(BUILDDIR)

$(BUILDDIR):
	mkdir -p $@

.PHONY: full_clean
full_clean:
	rm -rf $(BUILDDIR)

