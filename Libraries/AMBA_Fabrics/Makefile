# Enumerate all sub-dirs for recursive traversal
BUILD_ORDER = \
	Utils \
	AXI4 \
	AXI4_Lite \
	AXI4_Stream \
	Adapters \

.PHONY: all
all: install

.PHONY: install clean full_clean
install clean full_clean:
	$(foreach dir, $(BUILD_ORDER), $(MAKE) -C $(dir) $@ &&) true
